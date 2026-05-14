///|
using @tui {
  cell,
  display_width,
  fit_line,
  render_plain,
  repeat_to_width,
  take_width,
  text,
  type Cell,
  type Cmd,
  type Emit,
  type Frame,
  type Key,
  type Mouse,
  type Node,
  type ProgramOptions,
  type Size,
  type Style,
  type Sub,
  vstack,
  wrap_text,
}

///|
using @widgets {keymap, status_line, type Textarea, type TextareaMsg}

///|
using @vector {type Vector}

///|
enum Role {
  User
  Assistant
  Tool
} derive(Eq, Debug)

///|
struct Entry {
  role : Role
  text : String
} derive(Eq, Debug)

///|
struct RenderLine {
  text : String
  style : Style
} derive(Eq, Debug)

///|
struct CodexModel {
  transcript : Vector[Entry]
  prompt : Textarea
  draft_prompt : String
  history : Vector[String]
  history_index : Int
  active_menu : Int
  scroll_offset : Int
  streaming : Bool
  stream_index : Int
  width : Int
  height : Int
  status : String
} derive(Eq, Debug)

///|
enum CodexMsg {
  KeyPressed(Key)
  MouseSeen(Mouse)
  Pasted(String)
  FocusChanged(Bool)
  StreamChunk
  Resize(Size)
} derive(Eq, Debug)

///|
fn initial_model() -> CodexModel {
  {
    transcript: Vector::from_array([
      {
        role: Tool,
        text: "workspace /repo · native backend · paste, focus, resize",
      },
      {
        role: Assistant,
        text: "Ready. Describe a code change, ask for a review, or switch tabs to inspect the current run.\n\nPatch preview:\n```diff\ndiff --git a/src/agent.mbt b/src/agent.mbt\n@@ -7,7 +7,8 @@ fn render_status(task : Task) -> String {\n-  task.status\n+  let state = if task.done { \"done\" } else { \"running\" }\n+  task.with_status(state)\n }\n```",
      },
    ]),
    prompt: Textarea(placeholder="Ask Codex to change the code..."),
    draft_prompt: "",
    history: Vector::new(),
    history_index: -1,
    active_menu: 0,
    scroll_offset: 0,
    streaming: false,
    stream_index: 0,
    width: 80,
    height: 24,
    status: "idle",
  }
}

///|
fn update(
  emit : Emit[CodexMsg],
  msg : CodexMsg,
  model : CodexModel,
) -> (Cmd, CodexModel) {
  match msg {
    KeyPressed(Enter) => {
      let (submitted, next) = submit_prompt_model(model)
      (if submitted { emit(StreamChunk) } else { Cmd::none() }, next)
    }
    KeyPressed(Ctrl("c")) | KeyPressed(Escape) =>
      (Cmd::none(), { ..model, streaming: false, status: "cancelled" })
    KeyPressed(PageUp) =>
      (Cmd::none(), scroll_by(model, page_scroll_delta(model)))
    KeyPressed(PageDown) =>
      (Cmd::none(), scroll_by(model, 0 - page_scroll_delta(model)))
    KeyPressed(Up) if model.prompt.row == 0 =>
      (Cmd::none(), history_prev(model))
    KeyPressed(Down) if model.history_index >= 0 ||
      model.prompt.row + 1 == model.prompt.lines.length() =>
      (Cmd::none(), history_next(model))
    KeyPressed(Tab) =>
      (
        Cmd::none(),
        { ..model, active_menu: (model.active_menu + 1) % 3, scroll_offset: 0 },
      )
    KeyPressed(key) => {
      let prompt_msg : TextareaMsg = TextareaKey(key)
      let prompt = model.prompt.update(prompt_msg)
      (
        Cmd::none(),
        if prompt_edit_key(key) {
          { ..model, prompt, draft_prompt: prompt.value(), history_index: -1 }
        } else {
          { ..model, prompt, }
        },
      )
    }
    MouseSeen(mouse) =>
      match mouse.button {
        WheelUp => (Cmd::none(), scroll_by(model, 2))
        WheelDown => (Cmd::none(), scroll_by(model, -2))
        _ => (Cmd::none(), model)
      }
    Pasted(value) => {
      let prompt_msg : TextareaMsg = TextareaKey(Char(value))
      let prompt = model.prompt.update(prompt_msg)
      (
        Cmd::none(),
        { ..model, prompt, draft_prompt: prompt.value(), history_index: -1 },
      )
    }
    FocusChanged(true) => (Cmd::none(), { ..model, status: "focused" })
    FocusChanged(false) => (Cmd::none(), { ..model, status: "background" })
    StreamChunk => {
      let (more, next) = stream_chunk_model(model)
      (if more { emit(StreamChunk) } else { Cmd::none() }, next)
    }
    Resize(size) => (Cmd::none(), resize_model(size, model))
  }
}

///|
fn resize_model(size : Size, model : CodexModel) -> CodexModel {
  clamp_scroll({ ..model, width: size.width, height: size.height })
}

///|
fn submit_prompt_model(model : CodexModel) -> (Bool, CodexModel) {
  let prompt = model.prompt.value()
  if prompt == "" || model.streaming {
    return (false, model)
  }
  let transcript = model.transcript
    .push({ role: User, text: prompt })
    .push({ role: Assistant, text: "" })
  let history = model.history.push(prompt)
  (
    true,
    {
      ..model,
      transcript,
      history,
      history_index: -1,
      prompt: Textarea(placeholder="Ask Codex to change the code..."),
      draft_prompt: "",
      streaming: true,
      stream_index: 0,
      scroll_offset: 0,
      status: "thinking",
    },
  )
}

///|
fn history_prev(model : CodexModel) -> CodexModel {
  if model.history.is_empty() {
    return model
  }
  let saved_draft = if model.history_index < 0 {
    model.prompt.value()
  } else {
    model.draft_prompt
  }
  let index = if model.history_index < 0 {
    model.history.length() - 1
  } else {
    Int::max(0, model.history_index - 1)
  }
  {
    ..model,
    draft_prompt: saved_draft,
    history_index: index,
    prompt: set_prompt_value(model.prompt, model.history[index]),
  }
}

///|
fn history_next(model : CodexModel) -> CodexModel {
  if model.history.is_empty() || model.history_index < 0 {
    return model
  }
  let next_index = model.history_index + 1
  if next_index >= model.history.length() {
    {
      ..model,
      history_index: -1,
      prompt: set_prompt_value(model.prompt, model.draft_prompt),
    }
  } else {
    {
      ..model,
      history_index: next_index,
      prompt: set_prompt_value(model.prompt, model.history[next_index]),
    }
  }
}

///|
fn prompt_edit_key(key : Key) -> Bool {
  match key {
    Char(_) | Backspace | Delete => true
    _ => false
  }
}

///|
fn set_prompt_value(prompt : Textarea, value : String) -> Textarea {
  let msg : TextareaMsg = TextareaSet(value)
  prompt.update(msg)
}

///|
fn stream_chunk_model(model : CodexModel) -> (Bool, CodexModel) {
  let chunks = [
    "I will inspect the relevant files, ", "apply a focused patch, ", "run tests, ",
    "and report the result.",
  ]
  if !model.streaming || model.stream_index >= chunks.length() {
    return (false, { ..model, streaming: false, status: "done" })
  }
  let last = model.transcript.length() - 1
  let entry = model.transcript[last]
  let old_max_scroll = max_scroll_offset(model)
  let transcript = model.transcript.set(last, {
    ..entry,
    text: "\{entry.text}\{chunks[model.stream_index]}",
  })
  let next_index = model.stream_index + 1
  let next = {
    ..model,
    transcript,
    stream_index: next_index,
    streaming: next_index < chunks.length(),
    status: if next_index < chunks.length() {
      "streaming"
    } else {
      "done"
    },
  }
  let scroll_offset = if model.scroll_offset == 0 {
    0
  } else {
    model.scroll_offset + Int::max(0, max_scroll_offset(next) - old_max_scroll)
  }
  (next_index < chunks.length(), clamp_scroll({ ..next, scroll_offset, }))
}

///|
fn view(model : CodexModel) -> Node {
  let transcript_height = transcript_pane_height(model)
  let width = content_width(model.width)
  vstack <| [
    top_bar(model, width),
    transcript_view(model, { width, height: transcript_height }),
    activity_view(model, width),
    composer_view(model, width),
    help_view(width),
  ]
}

///|
fn content_width(width : Int) -> Int {
  Int::max(1, width - 1)
}

///|
fn transcript_view(model : CodexModel, size : Size) -> Node {
  let lines = pane_lines(model, size.width)
  let start = Int::max(0, lines.length() - size.height - model.scroll_offset)
  let end = Int::min(lines.length(), start + size.height)
  let visible = Array::makei(end - start, relative_index => {
    let index = start + relative_index
    text(style=lines[index].style, fit_line(lines[index].text, size.width))
  })
  let blanks = Array::makei(size.height - visible.length(), _ => {
    text(repeat_to_width(" ", size.width))
  })
  vstack <| [..visible, ..blanks]
}

///|
fn transcript_pane_height(model : CodexModel) -> Int {
  Int::max(1, live_height(model) - 7)
}

///|
fn live_height(model : CodexModel) -> Int {
  Int::max(8, model.height)
}

///|
fn max_scroll_offset(model : CodexModel) -> Int {
  Int::max(
    0,
    pane_lines(model, content_width(model.width)).length() -
    transcript_pane_height(model),
  )
}

///|
fn clamp_scroll(model : CodexModel) -> CodexModel {
  {
    ..model,
    scroll_offset: Int::min(
      Int::max(0, model.scroll_offset),
      max_scroll_offset(model),
    ),
  }
}

///|
fn scroll_by(model : CodexModel, delta : Int) -> CodexModel {
  clamp_scroll({ ..model, scroll_offset: model.scroll_offset + delta })
}

///|
fn page_scroll_delta(model : CodexModel) -> Int {
  Int::max(1, transcript_pane_height(model) - 2)
}

///|
fn pane_lines(model : CodexModel, width : Int) -> Array[RenderLine] {
  match model.active_menu {
    1 => plan_lines(model, width)
    2 => log_lines(model, width)
    _ => transcript_lines(model, width)
  }
}

///|
fn transcript_lines(model : CodexModel, width : Int) -> Array[RenderLine] {
  let lines = model.transcript
    .map(entry => {
      [..entry_lines(entry, width), { text: "", style: Style::default() }]
    })
    .to_array()
    .flatten()
  if model.streaming {
    [
      ..lines,
      {
        text: fit_line(
          "codex  \{spinner_text(model.stream_index)} \{progress_label(model.stream_index)}",
          width,
        ),
        style: Style::default().fg(Ansi(11)).bold(),
      },
    ]
  } else {
    lines
  }
}

///|
fn entry_lines(entry : Entry, width : Int) -> Array[RenderLine] {
  let prefix = role_prefix(entry.role)
  let body = if entry.text == "" { "..." } else { entry.text }
  let mut in_diff = false
  let parts = split_entry_lines(body)
    .map(raw => {
      if raw == "```diff" {
        in_diff = true
        []
      } else if in_diff && raw == "```" {
        in_diff = false
        []
      } else {
        let style = if in_diff {
          diff_line_style(raw)
        } else {
          role_style(entry.role)
        }
        let line_parts = if in_diff {
          clip_code_line(raw, Int::max(1, width - display_width(prefix)))
        } else {
          wrap_text(raw, Int::max(1, width - display_width(prefix)))
        }
        line_parts.map(part => (part, style))
      }
    })
    .flatten()
  parts.mapi((index, part) => {
    let (text_part, style) = part
    let line_prefix = if index == 0 {
      prefix
    } else {
      repeat_to_width(" ", display_width(prefix))
    }
    { text: fit_line("\{line_prefix}\{text_part}", width), style }
  })
}

///|
fn split_entry_lines(value : String) -> Array[String] {
  let lines : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < value.length() {
    if value[index] == '\n' {
      lines.push(value[start:index].to_owned())
      start = index + 1
    }
    index += 1
  }
  lines.push(value[start:].to_owned())
  lines
}

///|
fn clip_code_line(value : String, width : Int) -> Array[String] {
  [take_width(value, width)]
}

///|
fn diff_line_style(line : String) -> Style {
  if line.has_prefix("+") && !line.has_prefix("+++") {
    Style::default().fg(Ansi(10)).bold()
  } else if line.has_prefix("-") && !line.has_prefix("---") {
    Style::default().fg(Ansi(9)).bold()
  } else if line.has_prefix("@@") {
    Style::default().fg(Ansi(14)).bold()
  } else if line.has_prefix("diff ") ||
    line.has_prefix("index ") ||
    line.has_prefix("---") ||
    line.has_prefix("+++") {
    Style::default().bold()
  } else {
    Style::default()
  }
}

///|
fn plan_lines(model : CodexModel, width : Int) -> Array[RenderLine] {
  let rows = [
    ("Inspect project context", model.stream_index > 0),
    ("Apply focused patch", model.stream_index > 1),
    ("Run native checks", model.stream_index > 2),
    ("Summarize result", !model.streaming && model.status == "done"),
  ]
  [
    {
      text: fit_line("Plan · current run", width),
      style: Style::default().bold(),
    },
    {
      text: fit_line(
        "──────────────────", width,
      ),
      style: Style::default().fg(Ansi(238)),
    },
    ..rows.mapi((index, row) => {
      let (name, done) = row
      let running = model.streaming && index == model.stream_index
      let marker = if done {
        "✓"
      } else if running {
        spinner_text(model.stream_index)
      } else {
        "·"
      }
      let state = if done {
        "done"
      } else if running {
        "running"
      } else {
        "waiting"
      }
      {
        text: fit_line("  \{marker}  \{name}  \{state}", width),
        style: if done {
          Style::default().fg(Ansi(10)).bold()
        } else if running {
          Style::default().fg(Ansi(11)).bold()
        } else {
          Style::default()
        },
      }
    }),
  ]
}

///|
fn log_lines(model : CodexModel, width : Int) -> Array[RenderLine] {
  [
    { text: fit_line("Logs · runtime", width), style: Style::default().bold() },
    {
      text: fit_line("────────────────", width),
      style: Style::default().fg(Ansi(238)),
    },
    {
      text: fit_line("  terminal: native backend", width),
      style: Style::default(),
    },
    {
      text: fit_line("  input: buffered keyboard, paste, focus, resize", width),
      style: Style::default(),
    },
    {
      text: fit_line("  layout: adaptive \{model.width}x\{model.height}", width),
      style: Style::default(),
    },
    {
      text: fit_line("  status: \{model.status}", width),
      style: Style::default().fg(
        if model.streaming {
          Ansi(11)
        } else {
          Ansi(10)
        },
      ),
    },
  ]
}

///|
fn activity_view(model : CodexModel, width : Int) -> Node {
  if model.streaming {
    let right = "Esc cancel"
    text(
      style=Style::default().fg(Ansi(16)).bg(Ansi(153)).bold(),
      plain_line(
        status_line(
          left="  ● \{progress_label(model.stream_index)}",
          right~,
          width~,
        ),
        width,
      ),
    )
  } else {
    let right = if model.scroll_offset > 0 {
      "scroll ↑ \{model.scroll_offset}"
    } else {
      "\{model.transcript.length()} messages"
    }
    text(
      style=Style::default().fg(Ansi(16)).bg(Ansi(250)),
      plain_line(status_line(left="  \{model.status}", right~, width~), width),
    )
  }
}

///|
fn progress_label(index : Int) -> String {
  match index {
    0 => "thinking"
    1 => "inspecting files"
    2 => "applying patch"
    3 => "running tests"
    _ => "summarizing"
  }
}

///|
fn composer_view(model : CodexModel, width : Int) -> Node {
  let inner = Int::max(1, width - 2)
  vstack(
    style=Style::default()
      .fg(if model.streaming { Ansi(11) } else { Ansi(109) })
      .border(kind=Rounded)
      .clip({ width, height: 4 }),
  ) <| prompt_lines(model.prompt, Int::max(1, inner - 2))
}

///|
fn prompt_lines(prompt : Textarea, width : Int) -> Array[Node] {
  let prefix = "› "
  if prompt.value() == "" {
    return [
      text(fit_line("\{prefix}█Ask Codex to change the code...", width)),
      text(repeat_to_width(" ", width)),
    ]
  }
  let start = Int::max(0, prompt.row - 1)
  let end = Int::min(prompt.lines.length(), start + 2)
  let visible = Array::makei(end - start, relative_index => {
    let index = start + relative_index
    let line = prompt.lines[index]
    let shown = if index == prompt.row {
      "\{line[:prompt.column].to_owned()}█\{line[prompt.column:].to_owned()}"
    } else {
      line
    }
    let line_prefix = if index == start { prefix } else { "  " }
    text(fit_line("\{line_prefix}\{shown}", width))
  })
  let blanks = Array::makei(2 - visible.length(), _ => {
    text(repeat_to_width(" ", width))
  })
  [..visible, ..blanks]
}

///|
fn subscriptions(_model : CodexModel) -> Sub[CodexMsg] {
  Sub::batch([
    Sub::keys(key => KeyPressed(key)),
    Sub::mouse_events(mouse => MouseSeen(mouse)),
    Sub::paste(value => Pasted(value)),
    Sub::focus_changes(focused => FocusChanged(focused)),
    Sub::resize(size => Resize(size)),
  ])
}

///|
fn help_view(width : Int) -> Node {
  let help = if width < 48 {
    "enter submit  tab menu  ctrl+c"
  } else if width < 72 {
    "enter submit  tab menu  esc cancel  ctrl+c quit"
  } else {
    plain_line(
      keymap(
        bindings=[
          { keys: [Enter], help: "submit" },
          { keys: [Tab], help: "menu" },
          { keys: [Escape], help: "cancel" },
          { keys: [Ctrl("c")], help: "quit" },
        ],
        width~,
      ),
      width,
    )
  }
  text(style=Style::default(), fit_line(help, width))
}

///|
fn demo_app() -> Cell[CodexModel, CodexMsg] {
  cell(model=initial_model(), update~, view~, subscriptions~)
}

///|
fn top_bar(model : CodexModel, width : Int) -> Node {
  let labels = ["chat", "plan", "logs"]
  let left = StringBuilder::new()
  left.write_string("  codex  /repo  ")
  for index, label in labels {
    if index > 0 {
      left.write_string(" ")
    }
    if index == model.active_menu {
      left.write_string("[\{label}]")
    } else {
      left.write_string(label)
    }
  }
  let right = if model.streaming {
    "streaming  \{model.width}x\{model.height}"
  } else {
    "\{model.status}  \{model.width}x\{model.height}"
  }
  text(
    style=Style::default().bold(),
    plain_line(status_line(left=left.to_string(), right~, width~), width),
  )
}

///|
fn role_prefix(role : Role) -> String {
  match role {
    User => "you    "
    Assistant => "codex  "
    Tool => "system "
  }
}

///|
fn role_style(role : Role) -> Style {
  match role {
    User => Style::default().bold()
    Assistant => Style::default()
    Tool => Style::default()
  }
}

///|
fn spinner_text(frame : Int) -> String {
  let frames = ["-", "\\", "|", "/"]
  frames[frame % frames.length()]
}

///|
fn plain_line(node : Node, width : Int) -> String {
  let lines = render_plain(node, { width, height: 1 })
  if lines.is_empty() {
    repeat_to_width(" ", width)
  } else {
    lines[0]
  }
}

///|
fn fallback_snapshot() -> String {
  Frame::from_node(demo_app().view(), { width: 80, height: 24 }).to_string()
}

///|
#coverage.skip
async fn main {
  let app = demo_app()
  app.run_with_options(
    ProgramOptions::inline()
    .hide_cursor(true)
    .mouse(MouseButtonMotion)
    .bracketed_paste(true)
    .focus_events(true),
  ) catch {
    NotATty(_) => println(fallback_snapshot())
    NativeError(message) =>
      println("Terminal error: \{message}\n\{fallback_snapshot()}")
    UnsupportedPlatform =>
      println("This example requires a POSIX native terminal.")
  }
}
