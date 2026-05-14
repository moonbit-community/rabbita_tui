///|
using @tui {
  cell,
  delay,
  fit_line,
  hstack,
  render_plain,
  text,
  type Cmd,
  type Edge,
  type Emit,
  type Frame,
  type Key,
  type KeyModifiers,
  type Mouse,
  type MouseButton,
  type Node,
  type Program,
  type ProgramOptions,
  type Size,
  type Style,
  type Sub,
  vstack,
}

///|
using @widgets {spinner, status_line}

///|
using @vector {type Vector}

///|
struct LabModel {
  width : Int
  height : Int
  spinner : Int
  selected : Int
  next_job : Int
  running_job : Int
  timeout_left : Int
  status : String
  last_key : String
  events : Vector[String]
} derive(Eq, Debug)

///|
enum LabMsg {
  Resize(Size)
  KeyPressed(Key)
  Pasted(String)
  FocusChanged(Bool)
  MouseSeen(Mouse)
  Tick
  JobFinished(Int)
  TimeoutFinished(Int)
  SuspendedDone
  ExecDone(Int)
} derive(Eq, Debug)

///|
fn initial_model() -> LabModel {
  {
    width: 80,
    height: 24,
    spinner: 0,
    selected: 0,
    next_job: 1,
    running_job: 0,
    timeout_left: 0,
    status: "choose a scenario",
    last_key: "none",
    events: Vector::from_array(["Runtime control center ready."]),
  }
}

///|
fn update(
  emit : Emit[LabMsg],
  msg : LabMsg,
  model : LabModel,
) -> (Cmd, LabModel) {
  match msg {
    Resize(size) =>
      (Cmd::none(), { ..model, width: size.width, height: size.height })
    Tick => update_tick(emit, model)
    KeyPressed(key) => update_key(emit, key, model)
    Pasted(value) =>
      (
        Cmd::log("paste captured: \{value}"),
        push_event({ ..model, status: "paste" }, "paste \{value}"),
      )
    FocusChanged(focused) => update_focus(focused, model)
    MouseSeen(mouse) => update_mouse(mouse, model)
    JobFinished(id) => update_job_finished(id, model)
    TimeoutFinished(id) => update_timeout_finished(id, model)
    SuspendedDone =>
      (
        Cmd::log("suspended async section returned to the TUI"),
        push_event({ ..model, status: "suspend returned" }, "suspend returned"),
      )
    ExecDone(code) =>
      (
        Cmd::log("external command exited with \{code}"),
        push_event(
          { ..model, status: "exec exited \{code}" },
          "exec process exit \{code}",
        ),
      )
  }
}

///|
fn update_tick(emit : Emit[LabMsg], model : LabModel) -> (Cmd, LabModel) {
  let model = { ..model, spinner: model.spinner + 1 }
  if model.timeout_left <= 0 {
    return (Cmd::none(), model)
  }
  let left = model.timeout_left - 1
  if left == 0 && model.running_job > 0 {
    (emit(TimeoutFinished(model.running_job)), { ..model, timeout_left: 0 })
  } else {
    (Cmd::none(), { ..model, timeout_left: left })
  }
}

///|
fn update_key(
  emit : Emit[LabMsg],
  key : Key,
  model : LabModel,
) -> (Cmd, LabModel) {
  let model = { ..model, last_key: key_label(key) }
  match key {
    Char("q") | Ctrl("c") => (Cmd::quit(), model)
    Up => (Cmd::none(), select_scenario(model, -1))
    Down => (Cmd::none(), select_scenario(model, 1))
    Enter => update_scenario(emit, model.selected, model)
    Char(value) => {
      let index = match value {
        "p" => 0
        "x" => 1
        "s" => 2
        "j" => 3
        "t" => 4
        "c" => 5
        _ => -1
      }
      if index >= 0 {
        update_scenario(emit, index, { ..model, selected: index })
      } else {
        record_key(key, model)
      }
    }
    _ => record_key(key, model)
  }
}

///|
fn update_scenario(
  emit : Emit[LabMsg],
  index : Int,
  model : LabModel,
) -> (Cmd, LabModel) {
  match index {
    0 =>
      (
        Cmd::sequence([
          Cmd::log("safe stdout: this line is emitted above the live TUI"),
          Cmd::err_log("safe stderr: diagnostics can use the same path"),
        ]),
        push_event(
          { ..model, status: "safe output" },
          "safe stdout/stderr emitted",
        ),
      )
    1 => {
      let command = "printf 'external command owns the terminal now\\n'; sleep 1"
      (
        Cmd::exec_process(command, code => emit(ExecDone(code))),
        push_event(
          { ..model, status: "exec process running" },
          "exec process started",
        ),
      )
    }
    2 =>
      (
        Cmd::suspend(() => {
          @async.sleep(700)
          emit(SuspendedDone)
        }),
        push_event(
          { ..model, status: "raw mode suspended" },
          "suspend block started",
        ),
      )
    3 => {
      let id = model.next_job
      (
        delay(emit(JobFinished(id)), 1800),
        push_event(
          {
            ..model,
            next_job: id + 1,
            running_job: id,
            timeout_left: 0,
            status: "delayed job running",
          },
          "async job \{id} started",
        ),
      )
    }
    4 => {
      let id = model.next_job
      (
        Cmd::batch([
          delay(emit(JobFinished(id)), 2500),
          delay(emit(TimeoutFinished(id)), 900),
        ]),
        push_event(
          {
            ..model,
            next_job: id + 1,
            running_job: id,
            timeout_left: 9,
            status: "timeout race running",
          },
          "timeout job \{id} started",
        ),
      )
    }
    5 =>
      if model.running_job > 0 {
        (
          Cmd::log("cancelled job \{model.running_job}"),
          push_event(
            { ..model, running_job: 0, timeout_left: 0, status: "cancelled" },
            "job cancelled by model token",
          ),
        )
      } else {
        (
          Cmd::none(),
          push_event(
            { ..model, status: "nothing to cancel" },
            "no running job to cancel",
          ),
        )
      }
    _ =>
      (
        Cmd::none(),
        push_event(
          { ..model, selected: 6, status: "keyboard input" },
          "keyboard protocol scenario selected",
        ),
      )
  }
}

///|
fn record_key(key : Key, model : LabModel) -> (Cmd, LabModel) {
  (
    Cmd::none(),
    push_event(
      { ..model, selected: 6, status: "keyboard input" },
      "key \{key_label(key)}",
    ),
  )
}

///|
fn update_focus(focused : Bool, model : LabModel) -> (Cmd, LabModel) {
  if focused {
    (
      Cmd::none(),
      push_event({ ..model, status: "focus gained" }, "focus gained"),
    )
  } else {
    (Cmd::none(), push_event({ ..model, status: "focus lost" }, "focus lost"))
  }
}

///|
fn update_mouse(mouse : Mouse, model : LabModel) -> (Cmd, LabModel) {
  (
    Cmd::none(),
    push_event(
      { ..model, status: "mouse" },
      "mouse \{mouse_button(mouse.button)} at \{mouse.x},\{mouse.y}",
    ),
  )
}

///|
fn update_job_finished(id : Int, model : LabModel) -> (Cmd, LabModel) {
  if model.running_job == id {
    (
      Cmd::log("async job \{id} completed safely"),
      push_event(
        { ..model, running_job: 0, status: "job completed" },
        "job \{id} completed",
      ),
    )
  } else {
    (Cmd::none(), push_event(model, "ignored stale job \{id}"))
  }
}

///|
fn update_timeout_finished(id : Int, model : LabModel) -> (Cmd, LabModel) {
  if model.running_job == id {
    (
      Cmd::none(),
      push_event(
        { ..model, running_job: 0, timeout_left: 0, status: "timed out" },
        "job \{id} timed out",
      ),
    )
  } else {
    (Cmd::none(), model)
  }
}

///|
fn view(model : LabModel) -> Node {
  let width = Int::max(48, model.width)
  let height = Int::max(16, model.height)
  let body_height = Int::max(8, height - 5)
  let body = hstack(
      gap=1,
      style=Style::default().size(width~, height=body_height),
    ) <| [
      controls_panel(model, width / 2 - 2, body_height),
      state_panel(model, width - width / 2 - 2, body_height),
    ]
  vstack <| [
    header(model, width),
    body,
    status_line(
      left="up/down select  enter run  p/x/s/j/t/c  q quit",
      right="fps30",
      width~,
    ),
  ]
}

///|
fn header(model : LabModel, width : Int) -> Node {
  let spinner = first_line(
    render_plain(spinner(model.spinner), { width: 1, height: 1 }),
  )
  text(
    style=Style::default().fg(Rgb(235, 245, 255)).bg(Rgb(30, 74, 96)).bold(),
    fit_line(
      "runtime-lab control center  \{spinner}  \{scenario_title(model.selected)}  \{model.status}  \{model.width}x\{model.height}",
      width,
    ),
  )
}

///|
fn controls_panel(model : LabModel, width : Int, height : Int) -> Node {
  let scenario_lines = Array::makei(scenario_count(), index => {
    let marker = if model.selected == index { ">" } else { " " }
    if model.selected == index {
      [
        "\{marker} \{scenario_key(index)}  \{scenario_title(index)}",
        "   \{scenario_summary(index)}",
      ]
    } else {
      ["\{marker} \{scenario_key(index)}  \{scenario_title(index)}"]
    }
  }).flatten()
  let lines = [..scenario_lines, "", "Run with Enter. Shortcuts: p x s j t c."]
  panel(title="Scenario list", lines~, width~, height~)
}

///|
fn state_panel(model : LabModel, width : Int, height : Int) -> Node {
  let job = if model.running_job > 0 {
    "running #\{model.running_job}"
  } else {
    "idle"
  }
  let timeout = if model.timeout_left > 0 {
    "\{model.timeout_left} ticks"
  } else {
    "off"
  }
  let event_lines = model.events.map(entry => "- \{entry}").to_array()
  let lines : Array[String] = [
    "Selected",
    "",
    scenario_title(model.selected),
    scenario_summary(model.selected),
    "",
    "Timeline",
    ..event_lines,
    "",
    "State",
    "job       \{job}",
    "timeout   \{timeout}",
    "renderer  inline, FPS-limited repaint tick",
    "keyboard  \{model.last_key}",
  ]
  panel(title="Current run", lines~, width~, height~)
}

///|
fn panel(
  title~ : String,
  lines~ : Array[String],
  width~ : Int,
  height~ : Int,
) -> Node {
  vstack(
    style=Style::default()
      .fg(Rgb(124, 176, 198))
      .size(width=Int::max(1, width - 2), height=Int::max(1, height - 2))
      .padding(Edge::all(1))
      .border(kind=Rounded),
  ) <| [
    text(style=Style::default().bold(), fit_line(title, Int::max(1, width - 4))),
    text(""),
    ..lines.map(line => text(fit_line(line, Int::max(1, width - 4)))),
  ]
}

///|
fn subscriptions(_model : LabModel) -> Sub[LabMsg] {
  Sub::batch([
    Sub::keys(key => KeyPressed(key)),
    Sub::mouse_events(mouse => MouseSeen(mouse)),
    Sub::paste(value => Pasted(value)),
    Sub::focus_changes(focused => FocusChanged(focused)),
    Sub::resize(size => Resize(size)),
    Sub::tick(100, Tick),
  ])
}

///|
fn app() -> Program[LabModel, LabMsg] {
  cell(model=initial_model(), update~, view~, subscriptions~)
}

///|
fn scenario_count() -> Int {
  7
}

///|
fn select_scenario(model : LabModel, delta : Int) -> LabModel {
  let selected = Int::max(
    0,
    Int::min(scenario_count() - 1, model.selected + delta),
  )
  { ..model, selected, status: "choose a scenario" }
}

///|
fn scenario_key(index : Int) -> String {
  match index {
    0 => "p"
    1 => "x"
    2 => "s"
    3 => "j"
    4 => "t"
    5 => "c"
    _ => "*"
  }
}

///|
fn scenario_title(index : Int) -> String {
  match index {
    0 => "Cmd::log/err_log output"
    1 => "External process"
    2 => "Suspended terminal"
    3 => "Delayed command"
    4 => "Timeout race"
    5 => "Cancel active job"
    _ => "Keyboard protocol"
  }
}

///|
fn scenario_summary(index : Int) -> String {
  match index {
    0 => "Cmd::log/err_log print above the live frame."
    1 =>
      "Cmd::exec_process leaves raw mode, runs a shell command, then resumes."
    2 => "Cmd::suspend releases the terminal around async work."
    3 => "A delayed Cmd sends JobFinished back through Emit."
    4 =>
      "Two delayed commands race; timeout wins and stale completion is ignored."
    5 => "Model-level cancellation clears the active job."
    _ => "Modified arrows and Kitty/xterm sequences decode into Key values."
  }
}

///|
fn push_event(model : LabModel, event : String) -> LabModel {
  let next = model.events.push(event)
  { ..model, events: next.drop(Int::max(0, next.length() - 7)) }
}

///|
fn key_label(key : Key) -> String {
  match key {
    Char(value) => value
    Enter => "enter"
    Escape => "escape"
    Backspace => "backspace"
    Tab => "tab"
    BackTab => "shift+tab"
    Up => "up"
    Down => "down"
    Left => "left"
    Right => "right"
    Home => "home"
    End => "end"
    Delete => "delete"
    PageUp => "page-up"
    PageDown => "page-down"
    Ctrl(value) => "ctrl+\{value}"
    Alt(value) => "alt+\{value}"
    Modified(inner, modifiers) =>
      "\{modifier_label(modifiers)}\{key_label(inner)}"
    Function(index) => "f\{index}"
    Unknown(value) => value
  }
}

///|
fn modifier_label(modifiers : KeyModifiers) -> String {
  let parts = [
    if modifiers.ctrl {
      Some("ctrl")
    } else {
      None
    },
    if modifiers.alt {
      Some("alt")
    } else {
      None
    },
    if modifiers.shift {
      Some("shift")
    } else {
      None
    },
    if modifiers.super_key {
      Some("super")
    } else {
      None
    },
    if modifiers.hyper {
      Some("hyper")
    } else {
      None
    },
    if modifiers.meta {
      Some("meta")
    } else {
      None
    },
  ].filter_map(value => value)
  if parts.is_empty() {
    ""
  } else {
    let label = join(parts, "+")
    "\{label}+"
  }
}

///|
fn mouse_button(button : MouseButton) -> String {
  match button {
    Primary => "primary"
    Middle => "middle"
    Secondary => "secondary"
    WheelUp => "wheel-up"
    WheelDown => "wheel-down"
    Other(index) => "other-\{index}"
  }
}

///|
fn join(items : Array[String], sep : String) -> String {
  let out = StringBuilder::new()
  for index, item in items {
    if index > 0 {
      out.write_string(sep)
    }
    out.write_string(item)
  }
  out.to_string()
}

///|
fn first_line(lines : Array[String]) -> String {
  if lines.is_empty() {
    ""
  } else {
    lines[0]
  }
}

///|
fn fallback_snapshot() -> String {
  Frame::from_node(app().view(), { width: 80, height: 22 }).to_string()
}

///|
#coverage.skip
async fn main {
  app().run_with_options(
    ProgramOptions::inline()
    .hide_cursor(true)
    .mouse(MouseButtonMotion)
    .bracketed_paste(true)
    .focus_events(true)
    .fps(30)
    .max_messages_per_frame(128),
  ) catch {
    NotATty(_) => println(fallback_snapshot())
    NativeError(message) =>
      println("Terminal error: \{message}\n\{fallback_snapshot()}")
    UnsupportedPlatform =>
      println("This example requires a POSIX native terminal.")
  }
}
