///|
using @tui {
  cell,
  fit_line,
  text,
  type Cell,
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
using @widgets {keymap, progress, status_line}

///|
struct CounterModel {
  count : Int
  step : Int
  width : Int
  height : Int
  status : String
} derive(Eq, Debug)

///|
enum CounterMsg {
  KeyPressed(Key)
  Resize(Size)
} derive(Eq, Debug)

///|
fn initial_model() -> CounterModel {
  { count: 0, step: 1, width: 72, height: 18, status: "ready" }
}

///|
fn update(
  _emit : Emit[CounterMsg],
  msg : CounterMsg,
  model : CounterModel,
) -> (Cmd, CounterModel) {
  match msg {
    KeyPressed(key) =>
      match key {
        Ctrl("c") | Char("q") | Escape => (Cmd::quit(), model)
        Up | Right | Char("+") | Char("=") =>
          (
            Cmd::none(),
            {
              ..model,
              count: model.count + model.step,
              status: "incremented by \{model.step}",
            },
          )
        Down | Left | Char("-") =>
          (
            Cmd::none(),
            {
              ..model,
              count: model.count - model.step,
              status: "decremented by \{model.step}",
            },
          )
        Char("]") =>
          (
            Cmd::none(),
            {
              ..model,
              step: clamp(1, 100, model.step + 1),
              status: "step increased",
            },
          )
        Char("[") =>
          (
            Cmd::none(),
            {
              ..model,
              step: clamp(1, 100, model.step - 1),
              status: "step decreased",
            },
          )
        Char("r") =>
          (Cmd::none(), { ..model, count: 0, step: 1, status: "reset" })
        _ => (Cmd::none(), model)
      }
    Resize(size) =>
      (Cmd::none(), { ..model, width: size.width, height: size.height })
  }
}

///|
fn view(model : CounterModel) -> Node {
  vstack(style=Style::default().fg(Ansi(16)).bg(Ansi(255))) <| [
    status_line(
      left="counter",
      right="\{Int::max(32, model.width)}x\{Int::max(12, model.height)}",
      width=Int::max(1, model.width - 1),
      style=Style::default().fg(Ansi(16)).bg(Ansi(153)).bold(),
    ),
    vstack(
      gap=1,
      style=Style::default()
        .fg(Ansi(250))
        .padding(Edge::all(1))
        .border()
        .size(
          width=Int::max(1, model.width - 1),
          height=Int::max(11, Int::max(12, model.height) - 1),
        ),
    ) <| [
      text(
        style=Style::default().fg(Ansi(25)).bold(),
        fit_line(
          "Counter",
          clamp(24, 72, Int::max(32, model.width - 1) - 4) - 4,
        ),
      ),
      text(style=Style::default().fg(Ansi(28)).bold(), model.count.to_string()),
      text("step \{model.step}  \{model.status}"),
      progress(
        current=clamp(0, 100, model.count + 50),
        total=100,
        width=Int::max(12, clamp(24, 72, Int::max(32, model.width - 1) - 4) - 8),
        style=Style::default().fg(Ansi(28)),
      ),
      keymap(
        bindings=[
          { keys: [Up, Char("+")], help: "inc" },
          { keys: [Down, Char("-")], help: "dec" },
          { keys: [Char("["), Char("]")], help: "step" },
          { keys: [Char("r")], help: "reset" },
          { keys: [Char("q")], help: "quit" },
        ],
        width=clamp(24, 72, Int::max(32, model.width - 1) - 4) - 4,
        style=Style::default().fg(Ansi(244)),
      ),
    ],
  ]
}

///|
fn clamp(lbound : Int, ubound : Int, value : Int) -> Int {
  if value < lbound {
    lbound
  } else if value > ubound {
    ubound
  } else {
    value
  }
}

///|
fn subscriptions(_model : CounterModel) -> Sub[CounterMsg] {
  Sub::batch([
    Sub::keys(key => KeyPressed(key)),
    Sub::resize(size => Resize(size)),
  ])
}

///|
fn app() -> Cell[CounterModel, CounterMsg] {
  cell(model=initial_model(), update~, view~, subscriptions~)
}

///|
fn fallback_snapshot() -> String {
  Frame::from_node(app().view(), { width: 72, height: 18 }).to_string()
}

///|
#coverage.skip
async fn main {
  app().run_with_options(ProgramOptions::inline().hide_cursor(true)) catch {
    NotATty(_) => println(fallback_snapshot())
    NativeError(message) =>
      println("Terminal error: \{message}\n\{fallback_snapshot()}")
    UnsupportedPlatform =>
      println("This example requires a POSIX native terminal.")
  }
}
