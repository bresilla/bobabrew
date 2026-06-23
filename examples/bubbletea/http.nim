## Port of bubbletea/examples/http — make an HTTP request in a command and show
## the result. The request runs on a worker thread (a Cmd), keeping the UI
## responsive. Uses plain http:// to avoid an SSL dependency.

import std/httpclient
import ../../src/boba

const url = "http://example.com"

type
  ResultMsg = ref object of Msg
    status: string
    err: string
  App = ref object of Model
    status: string
    loading: bool

proc fetch(): Cmd =
  (proc (): Msg {.gcsafe.} =
    try:
      let client = newHttpClient(timeout = 5000)
      let resp = client.request(url)
      client.close()
      ResultMsg(status: resp.status)
    except CatchableError as e:
      ResultMsg(err: e.msg))

method init(m: App): Cmd = fetch()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("r"): (m.loading = true; m.status = ""; return (Model(m), fetch()))
  if msg of ResultMsg:
    m.loading = false
    let r = ResultMsg(msg)
    m.status = if r.err.len > 0: "error: " & r.err else: "status: " & r.status
  (Model(m), nil)

method view(m: App): View =
  let body = if m.loading or m.status.len == 0: "Requesting " & url & "..." else: m.status
  newView(body & "\n\nr: retry · q: quit")

when isMainModule:
  discard newProgram(Model(App(loading: true))).run()
