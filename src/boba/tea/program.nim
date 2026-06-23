## The Program runtime — port of tea.go's `Program`/`Run` and the central event
## loop.
##
## Concurrency mirrors Go's goroutines with native threads + the lock-based
## `Mailbox` (see docs/PLAN.md §8):
##   - an input thread reads the TTY, decodes bytes to messages
##   - a small worker pool runs `Cmd`s and feeds their results back
##   - the main thread owns the event loop, the model, and rendering
## Window resize is detected by polling the terminal size on the loop's idle
## tick (SIGWINCH wiring is an M8 deepening task); ^C arrives as a key in raw
## mode, exactly as in Go.

import std/[atomics, options, tables, os, osproc, times, monotimes]
import ./msg
import ./cmd
import ./view
import ./renderer
import ./input
import ../mailbox
import ../term/raw
import ../colorprofile
import ../uv/key
import ../ansi/sequences as seqs

when defined(posix):
  import std/posix

# ---- Model -----------------------------------------------------------------

type
  Model* = ref object of RootObj
    ## Base model. Subclass and override init/update/view.

method init*(m: Model): Cmd {.base, gcsafe.} = nil
method update*(m: Model, msg: Msg): (Model, Cmd) {.base, gcsafe.} = (m, nil)
method view*(m: Model): View {.base, gcsafe.} = newView("")

# ---- Program ---------------------------------------------------------------

type
  ProgramObj = object
    model: Model
    input: File
    output: File
    inputFd: cint
    outputFd: cint
    msgs: Mailbox[Msg]
    cmds: Mailbox[Cmd]
    done: Atomic[bool]
    pauseInput: Atomic[bool]
    interrupted: bool
    renderer: Renderer
    width, height: int
    rawState: TermState
    useRaw: bool
    disableRenderer: bool
    disableInput: bool
    runInput: bool
    profile: Profile
    fps: int
    environ: Table[string, string]
    filter: proc (m: Model, msg: Msg): Msg {.gcsafe.}
    inputThread: Thread[ptr ProgramObj]
    workers: array[4, Thread[ptr ProgramObj]]
    workerCount: int

  Program* = ref ProgramObj

  ProgramOption* = proc (p: Program) {.gcsafe.}

proc newProgram*(model: Model, opts: varargs[ProgramOption]): Program =
  result = Program()
  result.model = model
  result.input = stdin
  result.output = stdout
  result.workerCount = 4
  result.fps = 60
  result.environ = initTable[string, string]()
  for k, v in envPairs():
    result.environ[k] = v
  initMailbox(result.msgs)
  initMailbox(result.cmds)
  result.done.store(false)
  for o in opts:
    if o != nil: o(result)

# ---- options ---------------------------------------------------------------

proc withOutput*(f: File): ProgramOption =
  (proc (p: Program) = p.output = f)
proc withInput*(f: File): ProgramOption =
  (proc (p: Program) = p.input = f)
proc withoutRenderer*(): ProgramOption =
  (proc (p: Program) = p.disableRenderer = true)
proc withoutInput*(): ProgramOption =
  (proc (p: Program) = p.disableInput = true)
proc withColorProfile*(profile: Profile): ProgramOption =
  (proc (p: Program) = p.profile = profile)
proc withFPS*(fps: int): ProgramOption =
  (proc (p: Program) = p.fps = fps)
proc withEnvironment*(env: Table[string, string]): ProgramOption =
  (proc (p: Program) = p.environ = env)
proc withFilter*(f: proc (m: Model, msg: Msg): Msg {.gcsafe.}): ProgramOption =
  ## Intercept every message before the model sees it. Return a (possibly
  ## different) message, or nil to drop it.
  (proc (p: Program) = p.filter = f)

# ---- low-level input read --------------------------------------------------

when defined(posix):
  proc readChunk(fd: cint, timeoutMs: int): tuple[bytes: seq[byte], eof: bool] =
    var fds: TFdSet
    FD_ZERO(fds)
    FD_SET(fd, fds)
    var tv: Timeval
    tv.tv_sec = posix.Time(timeoutMs div 1000)
    tv.tv_usec = clong((timeoutMs mod 1000) * 1000)
    let r = select(cint(fd + 1), addr fds, nil, nil, addr tv)
    if r <= 0: return (@[], false)   # timeout
    var buf: array[2048, byte]
    let n = read(fd, addr buf[0], 2048)
    if n == 0: return (@[], true)    # EOF
    if n < 0: return (@[], false)
    result.bytes = newSeq[byte](n)
    copyMem(addr result.bytes[0], addr buf[0], n)
elif defined(windows):
  type WHANDLE = int
  const STD_INPUT_HANDLE = uint32(0xFFFFFFF6'u32)
  proc getStdHandle(n: uint32): WHANDLE
    {.importc: "GetStdHandle", dynlib: "kernel32", stdcall.}
  proc waitForSingleObject(h: WHANDLE, ms: uint32): uint32
    {.importc: "WaitForSingleObject", dynlib: "kernel32", stdcall.}
  proc readFile(h: WHANDLE, buffer: pointer, n: uint32, read: var uint32,
                overlapped: pointer): int32
    {.importc: "ReadFile", dynlib: "kernel32", stdcall.}

  proc readChunk(fd: cint, timeoutMs: int): tuple[bytes: seq[byte], eof: bool] =
    ## Windows: wait on the console input handle, then ReadFile. With
    ## ENABLE_VIRTUAL_TERMINAL_INPUT the console delivers ANSI sequences that the
    ## shared decoder parses, same as POSIX.
    let h = getStdHandle(STD_INPUT_HANDLE)
    if waitForSingleObject(h, uint32(timeoutMs)) != 0'u32:  # not WAIT_OBJECT_0
      return (@[], false)
    var buf: array[2048, byte]
    var nread: uint32
    if readFile(h, addr buf[0], 2048'u32, nread, nil) == 0:
      return (@[], false)
    if nread == 0'u32:
      return (@[], true)
    result.bytes = newSeq[byte](int(nread))
    copyMem(addr result.bytes[0], addr buf[0], int(nread))
else:
  proc readChunk(fd: cint, timeoutMs: int): tuple[bytes: seq[byte], eof: bool] =
    (@[], true)

# ---- OS signals ------------------------------------------------------------
# Handlers may run on any thread, so they only flip an atomic flag the event
# loop polls (port of handleSignals/listenForResize). One program at a time.

when defined(posix):
  var SIGWINCH {.importc, header: "<signal.h>".}: cint
  var gResizePending: Atomic[bool]
  var gQuitPending: Atomic[bool]

  proc onWinch(sig: cint) {.noconv.} = gResizePending.store(true)
  proc onTerm(sig: cint) {.noconv.} = gQuitPending.store(true)

  proc installSignals() =
    signal(SIGWINCH, onWinch)
    signal(SIGTERM, onTerm)

# ---- threads ---------------------------------------------------------------

proc inputLoop(p: ptr ProgramObj) {.thread, gcsafe.} =
  var buf: seq[byte] = @[]
  while not p.done.load:
    if p.pauseInput.load:
      # An Exec is running and owns the terminal; stop reading until it returns.
      buf.setLen(0)
      sleep(20)
      continue
    let (chunk, eof) = readChunk(p.inputFd, 50)
    if chunk.len > 0:
      for b in chunk: buf.add b
    var expired = chunk.len == 0 and buf.len > 0
    while buf.len > 0:
      let (n, m) = decode(buf, expired)
      if n == 0: break
      buf = buf[n .. ^1]
      if m != nil: p.msgs.send(m)
      expired = false
    if eof:
      # Input stream closed: flush any trailing partial as text, then stop.
      while buf.len > 0:
        let (n, m) = decode(buf, true)
        if n == 0: break
        buf = buf[n .. ^1]
        if m != nil: p.msgs.send(m)
      break

proc workerLoop(p: ptr ProgramObj) {.thread, gcsafe.} =
  while not p.done.load:
    let (ok, c) = p.cmds.recvTimeout(50)
    if not ok: continue
    if c == nil: continue
    let m = c()
    if m != nil: p.msgs.send(m)

# ---- helpers ---------------------------------------------------------------

proc send*(p: Program, m: Msg) =
  ## Inject a message into the program from outside.
  if not p.done.load: p.msgs.send(m)

proc quit*(p: Program) = p.send(QuitMsg())

proc kill*(p: Program) =
  ## Stop the program immediately (no final render). The external-cancellation
  ## equivalent of Go's WithContext cancel.
  p.done.store(true)

proc enqueue(p: ptr ProgramObj, c: Cmd) =
  if c != nil: p.cmds.send(c)

proc checkResize(p: ptr ProgramObj) =
  if not p.useRaw: return
  let (w, h) = getSize(int(p.outputFd))
  if w > 0 and h > 0 and (w != p.width or h != p.height):
    p.width = w
    p.height = h
    p.renderer.width = w
    p.renderer.height = h
    p.msgs.send(newWindowSize(w, h))

proc renderModel(p: ptr ProgramObj) =
  if not p.disableRenderer:
    p.renderer.render(p.model.view())

proc doExec(p: ptr ProgramObj, em: ExecMsg) =
  ## Suspend rendering + input, run the child with the terminal, then resume.
  p.pauseInput.store(true)
  sleep(60)  # give the input thread a moment to stop reading
  if not p.disableRenderer: p.renderer.release()
  if p.useRaw: restore(int(p.inputFd), p.rawState)

  var code = -1
  try:
    let process = startProcess(em.command, args = em.args,
                               options = {poParentStreams, poUsePath})
    code = process.waitForExit()
    process.close()
  except OSError, Exception:
    code = -1

  if p.useRaw:
    p.rawState = makeRaw(int(p.inputFd))
    p.useRaw = p.rawState.valid
  if not p.disableRenderer: p.renderer.forceRepaint()
  p.pauseInput.store(false)
  renderModel(p)

  if em.callback != nil:
    let m = em.callback(code)
    if m != nil: p.msgs.send(m)

proc suspendSelf(p: ptr ProgramObj) =
  ## Port of tea.go's suspend(): release the terminal, stop ourselves with
  ## SIGTSTP, and on resume (SIGCONT) re-acquire the terminal and emit ResumeMsg.
  when defined(posix):
    p.pauseInput.store(true)
    sleep(40)
    if not p.disableRenderer: p.renderer.release()
    if p.useRaw: restore(int(p.inputFd), p.rawState)

    discard posix.kill(posix.getpid(), posix.SIGTSTP)  # blocks until SIGCONT

    if p.useRaw:
      p.rawState = makeRaw(int(p.inputFd))
      p.useRaw = p.rawState.valid
    if not p.disableRenderer: p.renderer.forceRepaint()
    p.pauseInput.store(false)
    renderModel(p)
    p.msgs.send(Msg(ResumeMsg()))

# ---- event loop ------------------------------------------------------------

type MsgAction = enum
  maInternal   ## handled fully; no model update / render needed
  maUpdate     ## model was updated; a render is needed
  maQuit
  maInterrupt

proc processMsg(p: ptr ProgramObj, m: Msg): MsgAction =
  ## Handle one message: internal control, side-effects, and the model update.
  ## Returns what the loop should do next.
  if m of ExecMsg:
    doExec(p, ExecMsg(m)); return maInternal
  if m of QuitMsg: return maQuit
  if m of InterruptMsg: return maInterrupt
  if m of SuspendMsg:
    when defined(posix): suspendSelf(p)
    return maInternal
  if m of BatchMsg:
    for c in BatchMsg(m).cmds: enqueue(p, c)
    return maInternal
  if m of SequenceMsg:
    let cmds = SequenceMsg(m).cmds
    let pp = p
    enqueue(p, proc (): Msg {.gcsafe.} =
      for c in cmds:
        if c == nil: continue
        let r = c()
        if r != nil: pp.msgs.send(r)
      nil)
    return maInternal
  if m of windowSizeReqMsg:
    checkResize(p); return maInternal

  # Messages that have a side-effect AND still reach the model update.
  if m of clearScreenMsg:
    if not p.disableRenderer: p.renderer.clearScreen()
  elif m of WindowSizeMsg:
    let ws = WindowSizeMsg(m)
    p.width = ws.width; p.height = ws.height
    p.renderer.width = ws.width; p.renderer.height = ws.height
  elif m of printLineMessage:
    if not p.disableRenderer: p.renderer.insertAbove(printLineMessage(m).body)
  elif m of rawMsg:
    p.output.write(rawMsg(m).body); p.output.flushFile()
  elif m of reqBackgroundColorMsg:
    p.output.write(seqs.RequestBackgroundColor); p.output.flushFile()
  elif m of reqForegroundColorMsg:
    p.output.write(seqs.RequestForegroundColor); p.output.flushFile()
  elif m of reqCursorColorMsg:
    p.output.write(seqs.RequestCursorColor); p.output.flushFile()
  elif m of setClipboardMsg:
    let sc = setClipboardMsg(m)
    p.output.write(if sc.primary: seqs.setPrimaryClipboard(sc.content)
                   else: seqs.setSystemClipboard(sc.content))
    p.output.flushFile()
  elif m of readClipboardMsg:
    p.output.write(if readClipboardMsg(m).primary: seqs.RequestPrimaryClipboard
                   else: seqs.RequestSystemClipboard)
    p.output.flushFile()

  # Drive the model.
  let (newModel, c) = p.model.update(m)
  p.model = newModel
  enqueue(p, c)
  result = maUpdate

proc eventLoop(p: ptr ProgramObj) =
  ## Renders are coalesced: a burst of messages updates the model repeatedly but
  ## paints at most once per frame (FPS cap), the rest deferred to the next idle.
  let frameMs = max(1000 div max(p.fps, 1), 1)
  let frame = initDuration(milliseconds = frameMs)
  var dirty = false
  var lastRender = getMonoTime()

  template applyFilter(msg: Msg): Msg =
    (if p.filter != nil: p.filter(p.model, msg) else: msg)

  while true:
    if p.done.load:        # external kill
      return
    when defined(posix):
      if gQuitPending.load:
        gQuitPending.store(false)
        if dirty: renderModel(p)
        return
      if gResizePending.load:
        gResizePending.store(false)
        checkResize(p)

    let (ok, m0) = p.msgs.recvTimeout(min(frameMs, 50))
    if not ok:
      checkResize(p)
      if dirty:
        renderModel(p); dirty = false; lastRender = getMonoTime()
      continue

    block dispatch:
      var m = applyFilter(m0)
      if m != nil:
        case processMsg(p, m)
        of maQuit: (if dirty: renderModel(p)); return
        of maInterrupt: p.interrupted = true; return
        of maInternal: discard
        of maUpdate: dirty = true

      # Drain immediately-available messages so a burst coalesces to one paint.
      var drained = 0
      while drained < 512:
        let r = p.msgs.tryRecv()
        if not r.ok: break
        inc drained
        var dm = applyFilter(r.item)
        if dm == nil: continue
        case processMsg(p, dm)
        of maQuit: (if dirty: renderModel(p)); return
        of maInterrupt: p.interrupted = true; return
        of maInternal: discard
        of maUpdate: dirty = true

    # FPS cap: paint now if a frame elapsed, else leave dirty for the next idle.
    if dirty and (getMonoTime() - lastRender) >= frame:
      renderModel(p); dirty = false; lastRender = getMonoTime()

# ---- run -------------------------------------------------------------------

proc initTerminal(p: ptr ProgramObj) =
  p.inputFd = cint(getFileHandle(p.input))
  p.outputFd = cint(getFileHandle(p.output))
  # Read input (decoding bytes to messages) whenever input isn't disabled — this
  # covers both interactive TTYs and piped stdin.
  p.runInput = not p.disableInput
  let isTTY = isTerminal(int(p.outputFd))
  if p.disableRenderer or not isTTY:
    p.disableRenderer = p.disableRenderer or not isTTY
    p.renderer = newRenderer(p.output, 80, 24, disabled = true)
    p.useRaw = false
    return
  let (w, h) = getSize(int(p.outputFd))
  p.width = if w > 0: w else: 80
  p.height = if h > 0: h else: 24
  # Only switch the input TTY to raw mode if input is itself a terminal.
  if isTerminal(int(p.inputFd)):
    p.rawState = makeRaw(int(p.inputFd))
    p.useRaw = p.rawState.valid
  p.renderer = newRenderer(p.output, p.width, p.height)

proc shutdown(p: ptr ProgramObj) =
  p.done.store(true)
  p.cmds.close()
  p.msgs.close()
  if p.useRaw:
    restore(int(p.inputFd), p.rawState)
  if not p.disableRenderer:
    p.renderer.finish()

proc run*(p: Program): Model =
  ## Run the program, blocking until it quits. Returns the final model.
  let pp = cast[ptr ProgramObj](p)
  initTerminal(pp)

  # Install signal handlers (event-driven resize + graceful SIGTERM).
  when defined(posix):
    if pp.useRaw: installSignals()

  # Color profile (detect from environment unless explicitly set).
  if pp.profile == NoTTY and not pp.disableRenderer:
    pp.profile = detect(true, pp.environ)

  # Start workers + input thread.
  for i in 0 ..< pp.workerCount:
    createThread(pp.workers[i], workerLoop, pp)
  if pp.runInput:
    createThread(pp.inputThread, inputLoop, pp)

  # Initial messages the program expects on startup (port of tea.go's startup
  # sends): color profile, environment, then window size.
  pp.msgs.send(Msg(ColorProfileMsg(profile: pp.profile)))
  if pp.environ.len > 0:
    pp.msgs.send(Msg(EnvMsg(env: pp.environ)))
  pp.msgs.send(Msg(newWindowSize(pp.width, pp.height)))
  pp.renderer.start()
  enqueue(pp, pp.model.init())
  renderModel(pp)

  # The event loop is wrapped so a panic in update/view still restores the
  # terminal (port of recoverFromPanic). The error is re-raised after cleanup.
  var panic: ref Exception = nil
  try:
    eventLoop(pp)
  except Exception as e:
    panic = e

  shutdown(pp)
  for i in 0 ..< pp.workerCount:
    joinThread(pp.workers[i])
  if pp.runInput:
    joinThread(pp.inputThread)

  if panic != nil:
    raise panic

  result = pp.model
