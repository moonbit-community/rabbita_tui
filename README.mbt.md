# moonbit-community/rabbita_tui

> Warning: `moonbit-community/rabbita_tui` is experimental. Public APIs, package
> layout, widget names, and runtime behavior may change while it converges with
> Rabbita.

`moonbit-community/rabbita_tui` is a native terminal UI toolkit for MoonBit. It follows
The Elm Architecture:

```text
terminal event / command result
          |
          v
        Msg ------> update(emit, msg, model) -> (Cmd, Model)
          ^                                  |
          |                                  v
        Cmd <----------------------------- view(model)
```

The public API is intentionally close to Rabbita's current shape:

- `Emit[Msg]` turns a message into a monomorphic `Cmd`.
- `Cmd` is not parameterized by `Msg`.
- `cell` owns `Model`, `update`, `view`, and `subscriptions`.
- `Dispatch` is kept only as a deprecated alias for `Emit`.

The first backend targets POSIX terminals on MoonBit's native backend. Windows
keeps the API surface but returns `UnsupportedPlatform` for interactive terminal
startup.

## Install

Add the module and native async runtime dependency:

```json
{
  "deps": {
    "moonbit-community/rabbita_tui": "0.1.0",
    "moonbitlang/async": "0.17.0"
  },
  "preferred-target": "native"
}
```

In the package that uses the TUI:

```moonbit nocheck
import {
  "moonbit-community/rabbita_tui" @tui,
  "moonbit-community/rabbita_tui/widgets" @widgets,
  "moonbitlang/async",
}

supported_targets = "+native"

options(
  "is-main": true,
)
```

Run with:

```bash
moon run --target native path/to/your/package
```

## A Complete Small App

This is the smallest useful shape for an interactive program.

```moonbit nocheck
///|
using @tui {
  border,
  cell,
  pad,
  text,
  type Cmd,
  type Edge,
  type Emit,
  type Frame,
  type Key,
  type Node,
  type ProgramOptions,
  type Size,
  type Style,
  type Sub,
  vstack,
}

///|
using @widgets {status_line}

///|
enum Msg {
  KeyPressed(Key)
  Resize(Size)
  Quit
} derive(Eq, Debug)

///|
struct Model {
  count : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
fn initial_model() -> Model {
  { count: 0, width: 80, height: 24 }
}

///|
fn update(_emit : Emit[Msg], msg : Msg, model : Model) -> (Cmd, Model) {
  match msg {
    KeyPressed(key) =>
      match key {
        Up => (Cmd::none(), { ..model, count: model.count + 1 })
        Down => (Cmd::none(), { ..model, count: model.count - 1 })
        Char("q") | Ctrl("c") => (Cmd::quit(), model)
        _ => (Cmd::none(), model)
      }
    Resize(size) =>
      (Cmd::none(), { ..model, width: size.width, height: size.height })
    Quit => (Cmd::quit(), model)
  }
}

///|
fn view(model : Model) -> Node {
  let title = text(style=Style::default().bold().fg(Ansi(39)), "Counter")
  let body = text("count = \{model.count}")
  let help = text("up/down change  q quit")
  let card = vstack(gap=1) <| [
      title, body, help,
    ]
  vstack <| [
    status_line(
      left="counter",
      right="\{model.width}x\{model.height}",
      width=model.width,
    ),
    vstack(style=Style::default().padding(Edge::all(1)).border()) <| [
      card,
    ],
  ]
}

///|
fn subscriptions(_model : Model) -> Sub[Msg] {
  Sub::batch([
    Sub::keys(key => KeyPressed(key)),
    Sub::resize(size => Resize(size)),
  ])
}

///|
async fn main {
  cell(model=initial_model(), update~, view~, subscriptions~).run_with_options(
    ProgramOptions::inline(),
  ) catch {
    NotATty(_) =>
      println(
        Frame::from_node(view(initial_model()), { width: 80, height: 24 }).to_string(),
      )
    NativeError(message) => println("terminal error: \{message}")
    UnsupportedPlatform => println("native POSIX terminal required")
  }
}
```

## Core Concepts

### Model

Keep all application state in a plain struct. Store terminal size in the model
when layout depends on it.

```moonbit nocheck
///|
using @vector {type Vector}

///|
using @widgets {type TextInput}

///|
struct Model {
  input : TextInput
  items : Vector[String]
  selected : Int
  width : Int
  height : Int
}
```

### Msg

Messages describe what happened. Prefer semantic messages over raw terminal
events in the rest of your app.

```moonbit nocheck
///|
enum Msg {
  Typed(Key)
  Submitted
  Resized(Size)
  Loaded(Result[String, IOError])
  Quit
}
```

### Update

`update` is the state transition function. It receives:

- `emit : Emit[Msg]`, used to create commands that send messages later.
- `msg : Msg`, the event to handle.
- `model : Model`, the current state.

It returns `(Cmd, Model)`.

```moonbit nocheck
///|
fn update(emit : Emit[Msg], msg : Msg, model : Model) -> (Cmd, Model) {
  match msg {
    Submitted =>
      (delay(emit(Loaded(Ok("done"))), 300), { ..model, status: "loading" })
    Loaded(result) =>
      match result {
        Ok(value) => (Cmd::none(), { ..model, status: value })
        Err(_) => (Cmd::none(), { ..model, status: "failed" })
      }
    Quit => (Cmd::quit(), model)
    _ => (Cmd::none(), model)
  }
}
```

For large apps, keep `update` as the top-level message router and split by
domain:

```moonbit nocheck
///|
fn update(emit : Emit[Msg], msg : Msg, model : Model) -> (Cmd, Model) {
  match msg {
    KeyPressed(key) => update_key(emit, key, model)
    JobFinished(id) => update_job_finished(id, model)
    Resize(size) => (Cmd::none(), resize_model(size, model))
  }
}
```

### View

`view(model)` returns a `Node`. Rendering is declarative: you describe the frame,
and the runtime diffs frames at repaint time.

```moonbit nocheck
///|
fn view(model : Model) -> Node {
  vstack <| [
    text(style=Style::default().bold(), "Tasks"),
    border(model.input.view(width=model.width - 4)),
    status_line(left="enter submit", right="q quit", width=model.width),
  ]
}
```

### Subscriptions

Subscriptions translate terminal input into your `Msg` type.

```moonbit nocheck
///|
fn subscriptions(_model : Model) -> Sub[Msg] {
  Sub::batch([
    Sub::keys(key => KeyPressed(key)),
    Sub::mouse_events(mouse => MouseSeen(mouse)),
    Sub::paste(value => Pasted(value)),
    Sub::focus_changes(focused => FocusChanged(focused)),
    Sub::resize(size => Resized(size)),
    Sub::tick(100, Tick),
  ])
}
```

Subscriptions should produce messages directly. Ignore irrelevant input in
`update` instead of putting filtering logic inside subscription callbacks.

## Commands

Commands describe work the runtime should perform after `update`.

| Command | Use it for |
| --- | --- |
| `Cmd::none()` | no side effect |
| `emit(msg)` | queue a message immediately |
| `Cmd::batch([...])` | run commands concurrently |
| `Cmd::sequence([...])` | run commands in order |
| `delay(cmd, ms)` / `Cmd::delay(ms, cmd)` | run a command later |
| `Cmd::log` / `Cmd::err_log` | log safely above the live TUI |
| `Cmd::exec_process` | temporarily restore terminal mode, run an executable, resume |
| `Cmd::exec_process_with_args` | run an executable with argv-style arguments |
| `Cmd::suspend` | release the terminal around async work |
| `Cmd::quit` | stop the program |
| `Cmd::repaint` | mark the frame dirty |

Example: delayed follow-up message.

```moonbit nocheck
///|
fn update(emit : Emit[Msg], msg : Msg, model : Model) -> (Cmd, Model) {
  match msg {
    StartTimer => (delay(emit(TimerDone), 1000), { ..model, status: "waiting" })
    TimerDone => (Cmd::none(), { ..model, status: "done" })
  }
}
```

Example: external command.

```moonbit nocheck
Cmd::exec_process(
  "git",
  code => emit(ProcessExited(code)),
)
Cmd::exec_process_with_args(
  "git",
  ["status", "--short"],
  code => emit(ProcessExited(code)),
)
```

Example: safe output that does not corrupt the current frame.

```moonbit nocheck
Cmd::sequence([
  Cmd::log("saved configuration"),
  Cmd::err_log("warning: using default profile"),
])
```

## Runtime Options

Use `ProgramOptions` to configure terminal behavior.

```moonbit nocheck
ProgramOptions::default()
  .alternate_screen(true)
  .mouse(MouseButtonMotion)
  .bracketed_paste(true)
  .focus_events(true)
  .hide_cursor(true)
  .fps(30)
  .max_messages_per_frame(128)
  .resize_poll_millis(50)
```

Common presets:

- `ProgramOptions::default()` uses the alternate screen.
- `ProgramOptions::inline()` renders in the current terminal scrollback.
- `.without_renderer()` keeps subscriptions and commands running without
  drawing frames.
- `.fps(n)` limits repaint cadence when commands or subscriptions produce many
  messages.

Run helpers:

```moonbit nocheck
app.run()
app.run_with_options(ProgramOptions::inline())
app.run_returning_model()
app.run_with_cancel_token(options, token)
app.run_with_timeout(options, 5000)
let result = app.run_with_timeout_result(options, 5000)
```

`CancelToken` is useful when an outer task owns cancellation:

```moonbit nocheck
let token = CancelToken::new()
// pass token to the running program
token.cancel()
```

Use the `*_result` helpers when the caller needs to distinguish `ProgramQuit`,
`ProgramCancelled`, and `ProgramTimedOut`.

## Layout and Styling

The layout API is intentionally small and composable.

| Function | Purpose |
| --- | --- |
| `text(style?, value)` | text node |
| `vstack(gap?, style?) <| nodes` / `hstack(gap?, style?) <| nodes` | vertical or horizontal layout |
| `fragment(style?) <| nodes` | render a sequence of child nodes |
| `pad(edge=..., style?, node)` | add padding |
| `border(kind?, style?, node)` | add a border |
| `sized(width?, height?, style?, node)` | force a size |
| `clip(size=..., style?, node)` | clip to a size |
| `align(horizontal?, vertical?, style?, node)` | align inside available space |
| `fill(style?, value)` | repeated fill |

Styles support foreground, background, and text attributes:

```moonbit nocheck
let style = Style::default()
  .fg(Ansi(16))
  .bg(Ansi(250))
  .bold()
  .underline()

text(style~, "Ready")
```

For everyday view code, layout can live in `Style` as well, keeping wrappers
flat:

```moonbit nocheck
vstack(
  gap=1,
  style=Style::default()
    .fg(Ansi(250))
    .padding(Edge::all(1))
    .border()
    .size(width=48, height=8),
) <| [
  text(style=Style::default().bold(), "Build status"),
  text("All checks passed"),
]
```

Colors can be `Default`, `Ansi(index)`, or `Rgb(r, g, b)`.

For terminal-safe width handling:

- `display_width(text)` accounts for wide characters.
- `fit_line(text, width)` clips and pads a line.
- `take_width(text, width)` clips without padding.
- `wrap_text(text, width)` wraps by display width.

## Widgets

Widgets live in the `moonbit-community/rabbita_tui/widgets` package. They are TEA
submodels only when they need editing or selection state. Pure display widgets
are plain functions. Widgets do not own callbacks, commands, subscriptions, or
the app loop.

```moonbit nocheck
///|
using @widgets {
  keymap,
  progress,
  status_line,
  type TextInput,
  type TextInputMsg,
}
```

| Widget | Shape |
| --- | --- |
| `TextInput` | stateful: `TextInput`, `TextInputMsg`, `update`, `view` |
| `Textarea` | stateful: `Textarea`, `TextareaMsg`, `value`, `update`, `view` |
| `List` | stateful: `List`, `ListMsg`, `selected_item`, `update`, `view` |
| `Viewport` | stateful: `Viewport`, `ViewportMsg`, `update`, `view` |
| `CommandPalette` | stateful: `CommandPalette`, `CommandPaletteMsg`, `items`, `selected_item`, `update`, `view` |
| `table` / `paginator` / `progress` / `timer` / `keymap` / `tabs` | stateless render functions |
| `status_line` / `spinner` / `modal` | stateless terminal UI helpers |

Stateful constructors are declared as associated constructors, for example
`pub fn TextInput::TextInput(...) -> TextInput`, and called as `TextInput(...)`.

Stateful widget state belongs in your app model. Route widget messages through
your app's single `update` function. Stateless widgets are derived from the
model in `view` and should not be stored in the model:

```moonbit nocheck
///|
fn initial_model() -> Model {
  { input: TextInput(placeholder="Search"), completed: 0, total: 4 }
}
```

```moonbit nocheck
///|
fn view(model : Model) -> Node {
  vstack <| [
    model.input.view(width=model.width),
    progress(current=model.completed, total=model.total, width=model.width),
    keymap(
      bindings=[
        { keys: [Enter], help: "submit" },
        { keys: [Ctrl("c")], help: "quit" },
      ],
      width=model.width,
    ),
  ]
}
```

Example input handling:

```moonbit nocheck
///|
fn update(_emit : Emit[Msg], msg : Msg, model : Model) -> (Cmd, Model) {
  match msg {
    KeyPressed(key) => {
      let input_msg : TextInputMsg = TextInputKey(key)
      (Cmd::none(), { ..model, input: model.input.update(input_msg) })
    }
    Submitted => (Cmd::none(), { ..model, saved: model.input.value })
  }
}
```

## Keyboard and Mouse Input

The parser covers common terminal input:

- Printable characters.
- Control keys such as `Ctrl("c")`.
- Alt keys such as `Alt("x")`.
- Arrow/navigation/function keys.
- Shift/Ctrl/Alt modified arrow and navigation keys.
- Kitty keyboard protocol `CSI ... u`.
- Bracketed paste.
- SGR mouse events.
- Focus gained/lost events.

The key type includes `Modified(Key, KeyModifiers)`, so an app can distinguish
plain `Up` from `Modified(Up, KeyModifiers::none().shift(true))`.

## Testing

Use `run_headless` when you want to test observable behavior without a real
terminal.

```moonbit nocheck
///|
async test "counter increments" {
  let result = app().run_headless(
    events=[Key(Up), Key(Up)],
    options=HeadlessOptions::default().size({ width: 40, height: 10 }),
  )
  @debug.assert_eq(result.model.count, 2)
  @debug.assert_eq(result.frames.length() > 0, true)
}
```

Use `Frame::from_node` for snapshot-like assertions:

```moonbit nocheck
let frame = Frame::from_node(view(model), { width: 80, height: 24 })
assert_true(frame.to_string().contains("Ready"))
```

The runtime lab includes a tmux regression test that drives a real terminal:

```bash
scripts/runtime_lab_tmux_test.sh
```

## Examples

### `examples/counter`

A small counter app that demonstrates the recommended TEA shape without extra
moving parts:

- `Model`, `Msg`, `update`, `view`, and `subscriptions`.
- Direct key and resize subscriptions.
- Responsive layout.
- Basic foreground/background styling.

Run:

```bash
moon run --target native examples/counter
```

### `examples/codex-cli`

A Codex CLI-like conversation UI. It demonstrates:

- Responsive transcript layout.
- Prompt editing with `Textarea`.
- Prompt history.
- Streaming command messages.
- Diff rendering inside a chat pane.
- Scroll behavior with PageUp/PageDown and mouse wheel.
- Foreground/background color styling.

Run:

```bash
moon run --target native examples/codex-cli
moon run --target native examples/codex-cli -- --snapshot
```

### `examples/init-cli`

A project initializer wizard. It demonstrates:

- Multi-step form flow.
- `TextInput`, `List`, checkbox-like toggles, progress, and summary views.
- Delayed command scheduling.
- Responsive split-panel layout.

Run:

```bash
moon run --target native examples/init-cli
moon run --target native examples/init-cli -- --snapshot
```

### `examples/runtime-lab`

A runtime control center for learning lower-level behavior. It demonstrates:

- Safe stdout/stderr output.
- `Cmd::exec_process`.
- `Cmd::suspend`.
- Delayed jobs and timeout races.
- Model-level cancellation patterns.
- FPS-limited rendering.
- Modified keyboard input.

Run:

```bash
moon run --target native examples/runtime-lab
moon run --target native examples/runtime-lab -- --snapshot
scripts/runtime_lab_tmux_test.sh
```

## Design Notes

- Keep app state in `Model`; do not store terminal renderer state there.
- Keep `update` as the top-level message router. For larger examples, split by
  domain using helpers such as `update_key` and `update_scenario`; avoid helpers
  whose only job is to hide command construction.
- Use subscriptions to translate raw terminal events into semantic messages.
- Use `emit(msg)` for message commands. Use `Cmd::log`, `Cmd::suspend`, and
  `Cmd::exec_process` for runtime side effects instead of manually writing to
  stdout or toggling raw mode.
- Build views from `Node` values and widgets. The renderer remains independent
  from higher-level widgets so future Rabbita integration can reuse the app
  model/update layer.

## Current Limitations

- Interactive startup is implemented for POSIX native terminals.
- Windows currently returns `UnsupportedPlatform` for raw interactive mode.
- The widget set is practical but intentionally smaller than Bubble Tea's full
  ecosystem. It covers common CLI workflows, but advanced widgets should be
  built as plain MoonBit structs around the same `Model`/`Msg`/`update` pattern.
