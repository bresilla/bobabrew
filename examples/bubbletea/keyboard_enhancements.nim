## Port of bubbletea/examples/keyboard-enhancements — shows detailed key data
## (code, text, modifiers), which the Kitty-protocol enhancements expose.

import ../../src/boba

type App = ref object of Model
  info: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c"): return (Model(m), Quit)
    var mods: string
    if modCtrl in k.mods: mods.add "ctrl "
    if modAlt in k.mods: mods.add "alt "
    if modShift in k.mods: mods.add "shift "
    if modSuper in k.mods: mods.add "super "
    m.info = "string: " & $k & "\nkeystroke: " & k.keystroke &
             "\ntext: '" & k.text & "'\nmods: " & (if mods.len > 0: mods else: "(none)")
  elif msg of KeyReleaseMsg:
    m.info = "released: " & $KeyReleaseMsg(msg).key
  (Model(m), nil)

method view(m: App): View =
  newView("Press keys (ctrl+c to quit)\n\n" & m.info)

when isMainModule:
  discard newProgram(Model(App(info: "..."))).run()
