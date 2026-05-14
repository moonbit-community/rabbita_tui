///|
using @tui {
  cell,
  delay,
  fit_line,
  hstack,
  render_plain,
  repeat_to_width,
  sized,
  text,
  type Cell,
  type Cmd,
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
using @widgets {
  keymap,
  progress,
  status_line,
  type List,
  type ListMsg,
  table,
  type TextInput,
  type TextInputMsg,
}

///|
using @vector {type Vector}

///|
enum InitStep {
  Name
  Template
  Package
  Features
  Author
  License
  Confirm
  Generating
  Done
} derive(Eq, Debug)

///|
struct TemplateInfo {
  name : String
  description : String
  files : String
} derive(Eq, Debug)

///|
struct InitModel {
  step : InitStep
  project_name : TextInput
  author : TextInput
  template : List
  package_manager : List
  feature_cursor : Int
  features : Vector[Bool]
  license : List
  progress : Int
  spinner : Int
  width : Int
  height : Int
  status : String
} derive(Eq, Debug)

///|
enum InitMsg {
  KeyPressed(Key)
  Pasted(String)
  GenerateTick
  Resize(Size)
} derive(Eq, Debug)

///|
fn initial_model() -> InitModel {
  {
    step: Name,
    project_name: TextInput(placeholder="moonbit-awesome"),
    author: TextInput(placeholder="Your Name"),
    template: List(items=template_names()),
    package_manager: List(items=package_names()),
    feature_cursor: 0,
    features: Vector::from_array([true, true, false, true, false, false]),
    license: List(items=license_names()),
    progress: 0,
    spinner: 0,
    width: 80,
    height: 24,
    status: "answer questions",
  }
}

///|
fn update(
  emit : Emit[InitMsg],
  msg : InitMsg,
  model : InitModel,
) -> (Cmd, InitModel) {
  match msg {
    KeyPressed(Ctrl("c")) => (Cmd::quit(), model)
    KeyPressed(Escape) => (Cmd::none(), previous_step(model))
    KeyPressed(Tab) => (Cmd::none(), next_focus(model))
    KeyPressed(Enter) =>
      match model.step {
        Name =>
          if project_name(model) == "" {
            (Cmd::none(), { ..model, status: "project name is required" })
          } else {
            (Cmd::none(), step_to(model, Template))
          }
        Template => (Cmd::none(), step_to(model, Package))
        Package => (Cmd::none(), step_to(model, Features))
        Features => (Cmd::none(), step_to(model, Author))
        Author => (Cmd::none(), step_to(model, License))
        License => (Cmd::none(), step_to(model, Confirm))
        Confirm =>
          (delay(emit(GenerateTick), 120), start_generating_model(model))
        Generating => (Cmd::none(), model)
        Done => (Cmd::none(), reset_model(model))
      }
    KeyPressed(Up) => (Cmd::none(), move_current(model, -1))
    KeyPressed(Down) => (Cmd::none(), move_current(model, 1))
    KeyPressed(PageUp) => (Cmd::none(), move_current(model, -5))
    KeyPressed(PageDown) => (Cmd::none(), move_current(model, 5))
    KeyPressed(Char(" ")) if model.step == Features =>
      (Cmd::none(), toggle_feature(model))
    Pasted(value) => (Cmd::none(), paste_current(value, model))
    KeyPressed(key) => (Cmd::none(), edit_current(key, model))
    GenerateTick =>
      if model.step != Generating {
        (Cmd::none(), model)
      } else {
        let next = model.progress + 1
        if next >= generation_tasks().length() {
          (
            Cmd::none(),
            {
              ..model,
              step: Done,
              progress: generation_tasks().length(),
              status: "ready",
            },
          )
        } else {
          (
            delay(emit(GenerateTick), 140),
            { ..model, progress: next, spinner: model.spinner + 1 },
          )
        }
      }
    Resize(size) =>
      (Cmd::none(), { ..model, width: size.width, height: size.height })
  }
}

///|
fn edit_current(key : Key, model : InitModel) -> InitModel {
  match model.step {
    Name => {
      let msg : TextInputMsg = TextInputKey(key)
      { ..model, project_name: model.project_name.update(msg) }
    }
    Author => {
      let msg : TextInputMsg = TextInputKey(key)
      { ..model, author: model.author.update(msg) }
    }
    _ => model
  }
}

///|
fn paste_current(value : String, model : InitModel) -> InitModel {
  match model.step {
    Name => {
      let msg : TextInputMsg = TextInputKey(Char(value))
      { ..model, project_name: model.project_name.update(msg) }
    }
    Author => {
      let msg : TextInputMsg = TextInputKey(Char(value))
      { ..model, author: model.author.update(msg) }
    }
    _ => model
  }
}

///|
fn move_current(model : InitModel, delta : Int) -> InitModel {
  match model.step {
    Template => {
      let msg : ListMsg = ListMove(delta, list_height(model))
      { ..model, template: model.template.update(msg) }
    }
    Package => {
      let msg : ListMsg = ListMove(delta, list_height(model))
      { ..model, package_manager: model.package_manager.update(msg) }
    }
    Features => {
      let count = feature_names().length()
      {
        ..model,
        feature_cursor: Int::max(
          0,
          Int::min(count - 1, model.feature_cursor + delta),
        ),
      }
    }
    License => {
      let msg : ListMsg = ListMove(delta, list_height(model))
      { ..model, license: model.license.update(msg) }
    }
    _ => model
  }
}

///|
fn toggle_feature(model : InitModel) -> InitModel {
  if model.feature_cursor < 0 || model.feature_cursor >= model.features.length() {
    return model
  }
  {
    ..model,
    features: model.features.set(
      model.feature_cursor,
      !model.features[model.feature_cursor],
    ),
  }
}

///|
fn next_focus(model : InitModel) -> InitModel {
  if model.step == Done {
    initial_model()
  } else if model.step == Generating {
    model
  } else {
    step_to(model, next_step(model.step))
  }
}

///|
fn previous_step(model : InitModel) -> InitModel {
  if model.step == Name || model.step == Generating {
    model
  } else if model.step == Done {
    step_to(model, Confirm)
  } else {
    step_to(model, previous_step_of(model.step))
  }
}

///|
fn reset_model(model : InitModel) -> InitModel {
  let fresh = initial_model()
  { ..fresh, width: model.width, height: model.height }
}

///|
fn step_to(model : InitModel, step : InitStep) -> InitModel {
  { ..model, step, status: step_status(step) }
}

///|
fn start_generating_model(model : InitModel) -> InitModel {
  { ..model, step: Generating, progress: 0, spinner: 0, status: "scaffolding" }
}

///|
fn view(model : InitModel) -> Node {
  let width = Int::max(1, model.width - 1)
  let body_height = Int::max(1, model.height - 3)
  vstack <| [
    top_bar(model, width),
    step_bar(model, width),
    sized(
      width~,
      height=body_height,
      body_view(model, { width, height: body_height }),
    ),
    help_view(model, width),
  ]
}

///|
fn top_bar(model : InitModel, width : Int) -> Node {
  text(
    style=Style::default().fg(Ansi(16)).bg(Ansi(250)).bold(),
    line_text(
      status_line(
        left="  create-moon  \{project_label(model)}",
        right="\{model.status}  \{model.width}x\{model.height}",
        width~,
      ),
      width,
    ),
  )
}

///|
fn step_bar(model : InitModel, width : Int) -> Node {
  let step_number = step_index(model.step) + 1
  let left = "  \{step_number}/\{visible_step_count()}  \{step_title(model.step)}"
  let right = if model.step == Generating {
    generation_label(model.progress)
  } else if model.step == Done {
    "next: cd \{project_name(model)}"
  } else {
    "enter next"
  }
  text(
    style=Style::default().fg(Ansi(16)).bg(Ansi(153)),
    line_text(status_line(left~, right~, width~), width),
  )
}

///|
fn body_view(model : InitModel, size : Size) -> Node {
  if model.step == Generating || model.step == Done {
    question_view(model, size)
  } else if size.width >= 86 {
    hstack(gap=1) <| [
      sized(
        width=size.width / 2,
        height=size.height,
        question_view(model, { width: size.width / 2, height: size.height }),
      ),
      sized(
        width=size.width / 2,
        height=size.height,
        preview_view(model, { width: size.width / 2, height: size.height }),
      ),
    ]
  } else if size.height >= 14 {
    let preview_height = clamp(6, 9, size.height / 3 + 2)
    let question_height = Int::max(1, size.height - preview_height - 1)
    vstack(gap=1) <| [
      question_view(model, { width: size.width, height: question_height }),
      preview_view(model, { width: size.width, height: preview_height }),
    ]
  } else {
    question_view(model, size)
  }
}

///|
fn question_view(model : InitModel, size : Size) -> Node {
  match model.step {
    Name => name_view(model, size)
    Template => template_view(model, size)
    Package => package_view(model, size)
    Features => features_view(model, size)
    Author => author_view(model, size)
    License => license_view(model, size)
    Confirm => confirm_view(model, size)
    Generating => generating_view(model, size)
    Done => done_view(model, size)
  }
}

///|
fn name_view(model : InitModel, size : Size) -> Node {
  panel(title="Project name", size~) <| [
    text(style=muted_style(), "Choose a directory and package name."),
    model.project_name.view(
      width=Int::max(1, size.width - 4),
      style=accent_style()
        .border()
        .size(width=Int::max(1, size.width - 2), height=3),
    ),
    text(
      "Example: moonbit-awesome, agent-tools, docs-site",
      style=muted_style(),
    ),
  ]
}

///|
fn template_view(model : InitModel, size : Size) -> Node {
  panel(title="Template", size~) <| selectable_template_rows(model, size)
}

///|
fn package_view(model : InitModel, size : Size) -> Node {
  panel(title="Tooling", size~) <| selectable_package_rows(model, size)
}

///|
fn features_view(model : InitModel, size : Size) -> Node {
  panel(title="Features", size~) <| feature_rows(model, size)
}

///|
fn author_view(model : InitModel, size : Size) -> Node {
  panel(title="Author", size~) <| [
    text(style=muted_style(), "Used in README metadata and package manifest."),
    model.author.view(
      width=Int::max(1, size.width - 4),
      style=accent_style()
        .border()
        .size(width=Int::max(1, size.width - 2), height=3),
    ),
    text(style=muted_style(), "Leave empty to skip author metadata."),
  ]
}

///|
fn license_view(model : InitModel, size : Size) -> Node {
  panel(title="License", size~) <| selectable_license_rows(model, size)
}

///|
fn confirm_view(model : InitModel, size : Size) -> Node {
  panel(title="Review", size~) <| [
    text(style=muted_style(), "The initializer will create:"),
    summary_table(model, Int::max(1, size.width - 4)),
    command_box("moon run examples/init-cli", Int::max(1, size.width - 4)),
  ]
}

///|
fn generating_view(model : InitModel, size : Size) -> Node {
  let task_rows = generation_tasks().mapi((index, task) => {
    let marker = if index < model.progress {
      "done"
    } else if index == model.progress {
      spinner_text(model.spinner)
    } else {
      "wait"
    }
    let style = if index < model.progress {
      success_style()
    } else if index == model.progress {
      accent_style().bold()
    } else {
      muted_style()
    }
    text(style~, fit_line("  \{marker}  \{task}", size.width))
  })
  panel(title="Generating \{project_name(model)}", size~) <| [
    progress(
      current=model.progress,
      total=generation_tasks().length(),
      width=Int::max(1, size.width - 4),
    ),
    vstack <| task_rows,
  ]
}

///|
fn done_view(model : InitModel, size : Size) -> Node {
  panel(title="Project ready", size~) <| [
    text(
      style=success_style().bold(),
      "Created \{project_name(model)} from \{selected_template(model).name}.",
    ),
    file_tree(model, Int::max(1, size.width - 4)),
    command_box(
      "cd \{project_name(model)} && moon test",
      Int::max(1, size.width - 4),
    ),
  ]
}

///|
fn preview_view(model : InitModel, size : Size) -> Node {
  panel(title="Live preview", size~) <| [
    text("name       \{project_label(model)}"),
    text("template   \{selected_template(model).name}"),
    text("tooling    \{selected_package(model)}"),
    text("license    \{selected_license(model)}"),
    text("features   \{selected_features_label(model)}"),
    text(style=muted_style(), "files      \{selected_template(model).files}"),
  ]
}

///|
fn panel(title~ : String, size~ : Size, nodes : Array[Node]) -> Node {
  vstack(
    gap=1,
    style=panel_border_style()
      .border(kind=Rounded)
      .size(width=Int::max(1, size.width), height=Int::max(1, size.height)),
  ) <| [
    text(
      style=Style::default().bold(),
      fit_line(title, Int::max(1, size.width - 2)),
    ),
    ..nodes,
  ]
}

///|
fn selectable_template_rows(model : InitModel, size : Size) -> Array[Node] {
  templates().mapi((index, template) => {
    let selected = model.template.selected == index
    selectable_line(selected, template.name, template.description, size.width)
  })
}

///|
fn selectable_package_rows(model : InitModel, size : Size) -> Array[Node] {
  package_names().mapi((index, item) => {
    selectable_line(
      model.package_manager.selected == index,
      item,
      package_description(index),
      size.width,
    )
  })
}

///|
fn selectable_license_rows(model : InitModel, size : Size) -> Array[Node] {
  license_names().mapi((index, item) => {
    selectable_line(
      model.license.selected == index,
      item,
      license_description(index),
      size.width,
    )
  })
}

///|
fn feature_rows(model : InitModel, size : Size) -> Array[Node] {
  feature_names().mapi((index, name) => {
    let selected = model.feature_cursor == index
    let checked = if model.features[index] { "[x] " } else { "[ ] " }
    selectable_line(
      selected,
      "\{checked}\{name}",
      feature_description(index),
      size.width,
    )
  })
}

///|
fn selectable_line(
  selected : Bool,
  label : String,
  description : String,
  width : Int,
) -> Node {
  let marker = if selected { "> " } else { "  " }
  text(
    style=if selected { accent_style().bold() } else { Style::default() },
    fit_line("\{marker}\{label}  \{description}", Int::max(1, width - 4)),
  )
}

///|
fn summary_table(model : InitModel, width : Int) -> Node {
  table(
    columns=[
      { title: "Field", width: 12 },
      { title: "Value", width: Int::max(16, width - 18) },
    ],
    rows=[
      ["Name", project_name(model)],
      ["Template", selected_template(model).name],
      ["Tooling", selected_package(model)],
      ["Author", author_name(model)],
      ["License", selected_license(model)],
      ["Features", selected_features_label(model)],
    ],
    size={ width, height: 8 },
  )
}

///|
fn command_box(command : String, width : Int) -> Node {
  text(
    style=Style::default().fg(Ansi(16)).bg(Ansi(254)),
    fit_line("$ \{command}", width),
  )
}

///|
fn file_tree(model : InitModel, width : Int) -> Node {
  let lines = [
    "\{project_name(model)}/",
    "  moon.mod.json",
    "  src/main.mbt",
    "  README.md",
    "  test/basic_test.mbt",
    "  .github/workflows/stable_check.yml",
  ]
  vstack <| lines.map(line => text(fit_line(line, width)))
}

///|
fn help_view(model : InitModel, width : Int) -> Node {
  let help = if model.step == Features {
    keymap(
      bindings=[
        { keys: [Up, Down], help: "move" },
        { keys: [Char(" ")], help: "toggle" },
        { keys: [Enter], help: "next" },
        { keys: [Escape], help: "back" },
        { keys: [Ctrl("c")], help: "quit" },
      ],
      width~,
    )
  } else if model.step == Done {
    keymap(
      bindings=[
        { keys: [Enter], help: "restart" },
        { keys: [Escape], help: "review" },
        { keys: [Ctrl("c")], help: "quit" },
      ],
      width~,
    )
  } else {
    keymap(
      bindings=[
        { keys: [Enter], help: "next" },
        { keys: [Up, Down], help: "select" },
        { keys: [Tab], help: "skip" },
        { keys: [Escape], help: "back" },
        { keys: [Ctrl("c")], help: "quit" },
      ],
      width~,
    )
  }
  text(style=muted_style(), line_text(help, width))
}

///|
fn project_name(model : InitModel) -> String {
  model.project_name.value
}

///|
fn project_label(model : InitModel) -> String {
  if project_name(model) == "" {
    "<unnamed>"
  } else {
    project_name(model)
  }
}

///|
fn author_name(model : InitModel) -> String {
  if model.author.value == "" {
    "not set"
  } else {
    model.author.value
  }
}

///|
fn selected_template(model : InitModel) -> TemplateInfo {
  templates()[model.template.selected]
}

///|
fn selected_package(model : InitModel) -> String {
  package_names()[model.package_manager.selected]
}

///|
fn selected_license(model : InitModel) -> String {
  license_names()[model.license.selected]
}

///|
fn selected_features_label(model : InitModel) -> String {
  let selected = feature_names()
    .mapi((index, name) => if model.features[index] { Some(name) } else { None })
    .filter_map(value => value)
  if selected.is_empty() {
    "none"
  } else {
    join(selected, ", ")
  }
}

///|
fn list_height(model : InitModel) -> Int {
  Int::max(3, model.height - 9)
}

///|
fn visible_step_count() -> Int {
  7
}

///|
fn step_index(step : InitStep) -> Int {
  match step {
    Name => 0
    Template => 1
    Package => 2
    Features => 3
    Author => 4
    License => 5
    Confirm | Generating | Done => 6
  }
}

///|
fn next_step(step : InitStep) -> InitStep {
  match step {
    Name => Template
    Template => Package
    Package => Features
    Features => Author
    Author => License
    License => Confirm
    Confirm => Generating
    Generating => Generating
    Done => Name
  }
}

///|
fn previous_step_of(step : InitStep) -> InitStep {
  match step {
    Name => Name
    Template => Name
    Package => Template
    Features => Package
    Author => Features
    License => Author
    Confirm | Generating | Done => License
  }
}

///|
fn step_title(step : InitStep) -> String {
  match step {
    Name => "Name your project"
    Template => "Choose a template"
    Package => "Choose tooling"
    Features => "Select features"
    Author => "Set author"
    License => "Pick license"
    Confirm => "Review configuration"
    Generating => "Generating files"
    Done => "Ready"
  }
}

///|
fn step_status(step : InitStep) -> String {
  match step {
    Name => "name"
    Template => "template"
    Package => "tooling"
    Features => "features"
    Author => "metadata"
    License => "license"
    Confirm => "review"
    Generating => "scaffolding"
    Done => "ready"
  }
}

///|
fn generation_label(progress : Int) -> String {
  let tasks = generation_tasks()
  if progress >= tasks.length() {
    "complete"
  } else {
    tasks[progress]
  }
}

///|
fn templates() -> Array[TemplateInfo] {
  [
    {
      name: "cli",
      description: "argument parser, commands, tests",
      files: "src/main.mbt, test/basic_test.mbt",
    },
    {
      name: "library",
      description: "public API package with examples",
      files: "lib.mbt, README.md, examples/basic",
    },
    {
      name: "tui-app",
      description: "TEA runtime with native terminal UI",
      files: "src/app.mbt, src/main.mbt",
    },
    {
      name: "service",
      description: "HTTP-ready structure and config",
      files: "src/server.mbt, config/dev.json",
    },
    {
      name: "workspace",
      description: "multi-package moon workspace",
      files: "moon.work, packages/*",
    },
  ]
}

///|
fn template_names() -> Array[String] {
  templates().map(item => item.name)
}

///|
fn package_names() -> Array[String] {
  ["moon", "moon + GitHub Actions", "moon + justfile", "moon + npm bridge"]
}

///|
fn package_description(index : Int) -> String {
  match index {
    0 => "minimal MoonBit workflow"
    1 => "CI based on stable_check.yml"
    2 => "task shortcuts for local development"
    _ => "JS package wrapper for distribution"
  }
}

///|
fn feature_names() -> Array[String] {
  ["git", "tests", "examples", "docs", "docker", "editorconfig"]
}

///|
fn feature_description(index : Int) -> String {
  match index {
    0 => "initialize repository"
    1 => "add snapshot and behavior tests"
    2 => "include runnable examples"
    3 => "write README and API notes"
    4 => "add container build file"
    _ => "consistent editor settings"
  }
}

///|
fn license_names() -> Array[String] {
  ["Apache-2.0", "MIT", "MPL-2.0", "Unlicense", "Proprietary"]
}

///|
fn license_description(index : Int) -> String {
  match index {
    0 => "permissive, patent grant"
    1 => "short permissive license"
    2 => "file-level copyleft"
    3 => "public domain style"
    _ => "no public license file"
  }
}

///|
fn generation_tasks() -> Array[String] {
  [
    "Create project directory", "Render moon.mod.json", "Write source package", "Add selected features",
    "Generate tests and examples", "Format and validate manifest",
  ]
}

///|
fn spinner_text(frame : Int) -> String {
  ["-", "\\", "|", "/"][frame % 4]
}

///|
fn line_text(node : Node, width : Int) -> String {
  let lines = render_plain(node, { width, height: 1 })
  if lines.is_empty() {
    repeat_to_width(" ", width)
  } else {
    lines[0]
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
fn accent_style() -> Style {
  Style::default().fg(Ansi(33))
}

///|
fn muted_style() -> Style {
  Style::default().fg(Ansi(244))
}

///|
fn success_style() -> Style {
  Style::default().fg(Ansi(34))
}

///|
fn panel_border_style() -> Style {
  Style::default().fg(Ansi(109))
}

///|
fn demo_app() -> Cell[InitModel, InitMsg] {
  cell(model=initial_model(), update~, view~, subscriptions~)
}

///|
fn subscriptions(_model : InitModel) -> Sub[InitMsg] {
  Sub::batch([
    Sub::keys(key => KeyPressed(key)),
    Sub::resize(size => Resize(size)),
    Sub::paste(value => Pasted(value)),
  ])
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
