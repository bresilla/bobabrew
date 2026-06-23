## Port of bubbletea/examples/query-term — query the terminal for its colors.

import ../../src/boba

type App = ref object of Model
  bg, fg, cur: string

method init(m: App): Cmd =
  let bg: Cmd = RequestBackgroundColor
  let fg: Cmd = RequestForegroundColor
  let cur: Cmd = RequestCursorColor
  Batch(bg, fg, cur)

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of BackgroundColorMsg:
    m.bg = BackgroundColorMsg(msg).color.hex &
           (if BackgroundColorMsg(msg).isDark: " (dark)" else: " (light)")
  elif msg of ForegroundColorMsg:
    m.fg = ForegroundColorMsg(msg).color.hex
  elif msg of CursorColorMsg:
    m.cur = CursorColorMsg(msg).color.hex
  (Model(m), nil)

method view(m: App): View =
  newView("Terminal queries:\n\n  background: " & m.bg &
          "\n  foreground: " & m.fg &
          "\n  cursor:     " & m.cur & "\n\nq to quit.")

when isMainModule:
  discard newProgram(Model(App(bg: "?", fg: "?", cur: "?"))).run()
