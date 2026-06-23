## Bobabrew — a Nim port of Charmbracelet's Bubble Tea (The Elm Architecture for
## terminal UIs). `import boba` gives you the full runtime API plus a
## Lipgloss-style `Style` for declarative styling.
##
## Minimal program:
##
##   import boba
##
##   type App = ref object of Model
##   method view(m: App): View = newView("Hello! (press q to quit)")
##   method update(m: App, msg: Msg): (Model, Cmd) =
##     if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
##       return (Model(m), Quit)
##     (Model(m), nil)
##
##   discard newProgram(App()).run()

import boba/tea/msg
import boba/tea/cmd
import boba/tea/view
import boba/tea/program
import boba/uv/key
import boba/uv/border
import boba/uv/layout
import boba/uv/window
import boba/uv/buffer
import boba/uv/cell
import boba/uv/screen
import boba/uv/tabstop
import boba/style
import boba/ansi/color
import boba/ansi/width
import boba/colorprofile

export msg, cmd, view, program, key
export border, layout, window, buffer, cell, screen, tabstop
export style          # the public, Lipgloss-style `Style`
export color, width   # colors + display-width helpers
export colorprofile
