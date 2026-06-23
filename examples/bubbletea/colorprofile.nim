## Port of bubbletea/examples/colorprofile — shows the detected color profile.

import ../../src/boba

type App = ref object of Model
  profile: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of ColorProfileMsg:
    m.profile = $ColorProfileMsg(msg).profile
  (Model(m), nil)

method view(m: App): View =
  let swatch = newStyle().foreground(trueColor(255, 110, 199)).render("●●●")
  newView("Detected color profile: " & m.profile & "  " & swatch &
          "\n\nq to quit.")

when isMainModule:
  discard newProgram(Model(App(profile: "?"))).run()
