# bobabrew

A Nim port of [Charmbracelet's Bubble Tea](https://github.com/charmbracelet/bubbletea)
— The Elm Architecture for terminal UIs.

> Status: **early but working.** A full vertical slice runs today — the Elm loop,
> threaded concurrency, input decoding, styling, borders, and layout. The full
> port plan (every layer of the Bubble Tea v2 stack) is in
> [`docs/PLAN.md`](docs/PLAN.md), tracked milestone by milestone.

## Hello, world

```nim
import boba

type Hello = ref object of Model

method view(m: Hello): View =
  newView("Hello, World!\n\nPress q to quit.")

method update(m: Hello, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "esc", "ctrl+c"):
    return (Model(m), Quit)
  (Model(m), nil)

when isMainModule:
  discard newProgram(Hello()).run()
```

The three-method `Model` contract mirrors Bubble Tea:

- `init(m): Cmd` — optional startup command
- `update(m, msg): (Model, Cmd)` — handle a message, return the next model + command
- `view(m): View` — render the current state

## What works today

- **Elm runtime** — `Program`/`run`, threaded event loop (input thread + command
  worker pool + main loop over a lock-based mailbox), `Quit`/`Batch`/`Sequence`/
  `Tick`/`Every`, custom messages, window-resize, `withoutRenderer`/`withInput`/
  `withOutput`/`withColorProfile` options.
- **Input** — UTF-8 text, C0 ctrl keys, `alt+` combos, CSI arrows/nav/function
  keys, SS3, and SGR mouse → `KeyPressMsg` / `Mouse*Msg`, matched via
  `key.matchString("ctrl+c", ...)`.
- **Rendering** — inline and alt-screen modes, cursor visibility/position, mouse/
  focus/paste modes, window title.
- **Styling (Lipgloss-style)** — a fluent `Style` (`newStyle().bold.foreground(…)
  .padding(…).withBorder(…).render(text)`) over SGR attrs + 16/256/truecolor,
  display-width/wcwidth, `wrap`/`truncate`, and color-profile degradation.
- **Composition** — box `border`s (normal/rounded/thick/double/ascii/…),
  `layout` (`split` with Length/Percent/Ratio/Fill/Min/Max, `joinHorizontal`,
  `joinVertical`), and `window`/`blit` for compositing.
- **Bubbles components** — `textinput`, `progress`, `spinner`, `viewport`,
  `paginator`, `list`, `table`, `keymap`+help, `stopwatch`, `timer` — embed and
  forward messages (`import boba/bubbles`).
- **Terminal integration** — raw mode, alt-screen, mouse/focus/paste modes,
  `ExecProcess` (run `$EDITOR` and resume), ctrl+z suspend/resume, event-driven
  resize (SIGWINCH), graceful SIGTERM, and background-color query for dark/light
  theme detection.

See [`examples/`](examples/): `helloworld`, `counter`, `panels`, `fullscreen`,
`form` — plus **all 62 upstream Bubble Tea examples ported** under
[`examples/bubbletea/`](examples/bubbletea/) (simple, spinner, progress, table,
list, viewport/pager, chat, tabs, file-picker, http, doom-fire, splash, …). Run
any with `nim c -r examples/bubbletea/<name>.nim`.

## Build & test

```sh
make build              # builds the bobabrew CLI starter
make test               # runs the regression + library tests
nim c -r examples/panels.nim
```

## Roadmap

The remaining work (full input decoder incl. Kitty/win32, the cell-level diff
renderer with scroll optimization, the Cassowary constraint layout, exec/suspend,
Windows, and the Lipgloss/Bubbles companion libraries) is laid out in
[`docs/PLAN.md`](docs/PLAN.md).
