///|
/// Message emitter used by a program.
///
/// Calling `emit(msg)` returns a `Cmd` that queues `msg` back into the
/// update loop. This mirrors Rabbita's current TEA API and keeps `Cmd`
/// monomorphic.
#alias(Dispatch, deprecated="Use Emit[Msg] instead.")
pub(all) struct Emit[Msg]((Msg) -> Cmd)

///|
pub fn[Msg] Emit::new(send : (Msg) -> Unit) -> Emit[Msg] {
  msg => CmdMessage(() => send(msg))
}

///|
pub fn[Msg] Emit::send(self : Emit[Msg], msg : Msg) -> Unit {
  match self(msg) {
    CmdMessage(send) => send()
    _ => ()
  }
}

///|
pub fn[A, B] Emit::map(self : Emit[A], map : (B) -> A) -> Emit[B] {
  msg => self(map(msg))
}

///|
enum Cmd {
  NoCmd
  CmdMessage(() -> Unit)
  CmdBatch(Array[Cmd])
  CmdSequence(Array[Cmd])
  CmdDelay(Int, Cmd)
  CmdTask(async () -> Cmd)
  CmdSuspend(async () -> Cmd)
  CmdExecProcess(String, (Int) -> Cmd)
  CmdTerminal(TerminalCommand)
}

///|
pub let none : Cmd = NoCmd

///|
pub fn Cmd::none() -> Cmd {
  NoCmd
}

///|
#deprecated("Use emit(msg) instead.")
pub fn[Msg] Cmd::message(emit : Emit[Msg], msg : Msg) -> Cmd {
  emit(msg)
}

///|
pub fn Cmd::batch(cmds : Array[Cmd]) -> Cmd {
  let flat : Array[Cmd] = []
  for cmd in cmds {
    match cmd {
      NoCmd => ()
      CmdBatch(nested) =>
        for child in nested {
          if !(child is NoCmd) {
            flat.push(child)
          }
        }
      _ => flat.push(cmd)
    }
  }
  if flat.is_empty() {
    NoCmd
  } else {
    CmdBatch(flat)
  }
}

///|
pub fn batch(cmds : Array[Cmd]) -> Cmd {
  Cmd::batch(cmds)
}

///|
pub fn Cmd::sequence(cmds : Array[Cmd]) -> Cmd {
  let flat : Array[Cmd] = []
  for cmd in cmds {
    match cmd {
      NoCmd => ()
      CmdSequence(nested) =>
        for child in nested {
          if !(child is NoCmd) {
            flat.push(child)
          }
        }
      _ => flat.push(cmd)
    }
  }
  if flat.is_empty() {
    NoCmd
  } else {
    CmdSequence(flat)
  }
}

///|
pub fn Cmd::delay(milliseconds : Int, cmd : Cmd) -> Cmd {
  if cmd is NoCmd {
    NoCmd
  } else {
    CmdDelay(milliseconds, cmd)
  }
}

///|
pub fn delay(cmd : Cmd, milliseconds : Int) -> Cmd {
  Cmd::delay(milliseconds, cmd)
}

///|
pub fn Cmd::tick(milliseconds : Int, cmd : Cmd) -> Cmd {
  Cmd::delay(milliseconds, cmd)
}

///|
pub fn Cmd::every(milliseconds : Int, cmd : Cmd) -> Cmd {
  Cmd::delay(milliseconds, cmd)
}

///|
pub fn Cmd::effect(task : async () -> Unit noraise) -> Cmd {
  CmdTask(() => {
    task()
    none
  })
}

///|
pub fn effect(task : async () -> Unit noraise) -> Cmd {
  Cmd::effect(task)
}

///|
pub fn[A] Cmd::perform(
  to_cmd : (A) -> Cmd,
  task : async () -> A noraise,
) -> Cmd {
  CmdTask(() => to_cmd(task()))
}

///|
pub fn[A] perform(to_cmd : (A) -> Cmd, task : async () -> A noraise) -> Cmd {
  Cmd::perform(to_cmd, task)
}

///|
pub fn[A, E : Error] Cmd::attempt(
  to_cmd : (Result[A, E]) -> Cmd,
  task : async () -> A raise E,
) -> Cmd {
  CmdTask(() => {
    let next = try task() catch {
      err => to_cmd(Err(err))
    } noraise {
      value => to_cmd(Ok(value))
    }
    next
  })
}

///|
pub fn[A, E : Error] attempt(
  to_cmd : (Result[A, E]) -> Cmd,
  task : async () -> A raise E,
) -> Cmd {
  Cmd::attempt(to_cmd, task)
}

///|
pub fn[A] Cmd::exec(to_cmd : (A) -> Cmd, task : async () -> A noraise) -> Cmd {
  CmdSuspend(() => to_cmd(task()))
}

///|
pub fn Cmd::suspend(task : async () -> Cmd) -> Cmd {
  CmdSuspend(task)
}

///|
pub fn Cmd::exec_process(command : String, done : (Int) -> Cmd) -> Cmd {
  CmdExecProcess(command, done)
}

///|
pub fn Cmd::terminal(command : TerminalCommand) -> Cmd {
  CmdTerminal(command)
}

///|
pub fn Cmd::write(value : String) -> Cmd {
  CmdTerminal(Print(value))
}

///|
pub fn Cmd::log(value : String) -> Cmd {
  CmdTerminal(PrintLine(value))
}

///|
pub fn Cmd::err_write(value : String) -> Cmd {
  CmdTerminal(PrintErr(value))
}

///|
pub fn Cmd::err_log(value : String) -> Cmd {
  CmdTerminal(PrintErrLine(value))
}

///|
pub fn Cmd::quit() -> Cmd {
  CmdTerminal(QuitProgram)
}

///|
pub fn Cmd::repaint() -> Cmd {
  CmdTerminal(Repaint)
}

///|
pub fn Cmd::clear_screen() -> Cmd {
  CmdTerminal(ClearScreen)
}

///|
pub fn Cmd::enter_alternate_screen() -> Cmd {
  CmdTerminal(EnterAlternateScreen)
}

///|
pub fn Cmd::leave_alternate_screen() -> Cmd {
  CmdTerminal(LeaveAlternateScreen)
}

///|
pub fn Cmd::hide_cursor() -> Cmd {
  CmdTerminal(HideCursor)
}

///|
pub fn Cmd::show_cursor() -> Cmd {
  CmdTerminal(ShowCursor)
}

///|
pub fn Cmd::enable_mouse(mode : MouseMode) -> Cmd {
  CmdTerminal(EnableMouse(mode))
}

///|
pub fn Cmd::disable_mouse() -> Cmd {
  CmdTerminal(DisableMouse)
}

///|
pub fn Cmd::enable_bracketed_paste() -> Cmd {
  CmdTerminal(EnableBracketedPaste)
}

///|
pub fn Cmd::disable_bracketed_paste() -> Cmd {
  CmdTerminal(DisableBracketedPaste)
}

///|
pub fn Cmd::enable_focus_events() -> Cmd {
  CmdTerminal(EnableFocusEvents)
}

///|
pub fn Cmd::disable_focus_events() -> Cmd {
  CmdTerminal(DisableFocusEvents)
}

///|
pub fn Cmd::set_window_title(title : String) -> Cmd {
  CmdTerminal(SetWindowTitle(title))
}

///|
pub async fn Cmd::run(self : Cmd) -> Unit {
  self.run_with_terminal(_ => ())
}

///|
pub async fn Cmd::run_with_terminal(
  self : Cmd,
  terminal : (TerminalCommand) -> Unit,
) -> Unit {
  match self {
    NoCmd => ()
    CmdMessage(send) => send()
    CmdBatch(cmds) =>
      @async.with_task_group(group => {
        for cmd in cmds {
          group.spawn_bg(() => cmd.run_with_terminal(terminal))
        }
      })
    CmdSequence(cmds) =>
      for cmd in cmds {
        cmd.run_with_terminal(terminal)
      }
    CmdDelay(milliseconds, cmd) => {
      @async.sleep(milliseconds)
      cmd.run_with_terminal(terminal)
    }
    CmdTask(task) => task().run_with_terminal(terminal)
    CmdSuspend(task) => task().run_with_terminal(terminal)
    CmdExecProcess(_, done) => done(0).run_with_terminal(terminal)
    CmdTerminal(command) => terminal(command)
  }
}

///|
pub fn Cmd::terminal_commands(self : Cmd) -> Array[TerminalCommand] {
  let out : Array[TerminalCommand] = []
  collect_terminal_commands(self, out)
  out
}

///|
pub fn Cmd::is_none(self : Cmd) -> Bool {
  match self {
    NoCmd => true
    CmdBatch(cmds) | CmdSequence(cmds) => cmds.all(cmd => cmd.is_none())
    _ => false
  }
}

///|
fn collect_terminal_commands(cmd : Cmd, out : Array[TerminalCommand]) -> Unit {
  match cmd {
    NoCmd
    | CmdMessage(_)
    | CmdDelay(_)
    | CmdTask(_)
    | CmdSuspend(_)
    | CmdExecProcess(_) => ()
    CmdTerminal(command) => out.push(command)
    CmdBatch(cmds) | CmdSequence(cmds) =>
      for child in cmds {
        collect_terminal_commands(child, out)
      }
  }
}

///|
enum Sub[Msg] {
  NoSub
  SubBatch(Array[Sub[Msg]])
  EventSub((Event) -> Msg)
  Keyboard((Event) -> Msg)
  KeySub((Key) -> Msg)
  MouseSub((Event) -> Msg)
  MouseEventSub((Mouse) -> Msg)
  ResizeSub((Size) -> Msg)
  PasteSub((String) -> Msg)
  FocusSub((Event) -> Msg)
  FocusChangesSub((Bool) -> Msg)
  TickSub(Int, Msg)
}

///|
pub fn[Msg] Sub::none() -> Sub[Msg] {
  NoSub
}

///|
pub fn[Msg] Sub::batch(subs : Array[Sub[Msg]]) -> Sub[Msg] {
  let flat : Array[Sub[Msg]] = []
  for sub in subs {
    match sub {
      NoSub => ()
      SubBatch(nested) =>
        for child in nested {
          if !(child is NoSub) {
            flat.push(child)
          }
        }
      _ => flat.push(sub)
    }
  }
  if flat.is_empty() {
    NoSub
  } else {
    SubBatch(flat)
  }
}

///|
pub fn[Msg] Sub::event(map : (Event) -> Msg) -> Sub[Msg] {
  EventSub(map)
}

///|
pub fn[Msg] Sub::keyboard(map : (Event) -> Msg) -> Sub[Msg] {
  Keyboard(map)
}

///|
pub fn[Msg] Sub::keys(map : (Key) -> Msg) -> Sub[Msg] {
  KeySub(map)
}

///|
pub fn[Msg] Sub::mouse(map : (Event) -> Msg) -> Sub[Msg] {
  MouseSub(map)
}

///|
pub fn[Msg] Sub::mouse_events(map : (Mouse) -> Msg) -> Sub[Msg] {
  MouseEventSub(map)
}

///|
pub fn[Msg] Sub::resize(map : (Size) -> Msg) -> Sub[Msg] {
  ResizeSub(map)
}

///|
pub fn[Msg] Sub::paste(map : (String) -> Msg) -> Sub[Msg] {
  PasteSub(map)
}

///|
pub fn[Msg] Sub::focus(map : (Event) -> Msg) -> Sub[Msg] {
  FocusSub(map)
}

///|
pub fn[Msg] Sub::focus_changes(map : (Bool) -> Msg) -> Sub[Msg] {
  FocusChangesSub(map)
}

///|
pub fn[Msg] Sub::tick(milliseconds : Int, msg : Msg) -> Sub[Msg] {
  TickSub(milliseconds, msg)
}

///|
pub fn[Msg] Sub::map_event(self : Sub[Msg], event : Event) -> Array[Msg] {
  let out : Array[Msg] = []
  collect_subscription(self, event, out)
  out
}

///|
fn[Msg] collect_subscription(
  sub : Sub[Msg],
  event : Event,
  out : Array[Msg],
) -> Unit {
  match sub {
    NoSub => ()
    SubBatch(subs) =>
      for child in subs {
        collect_subscription(child, event, out)
      }
    EventSub(map) => out.push(map(event))
    Keyboard(map) => if event is Key(_) { out.push(map(event)) }
    KeySub(map) =>
      match event {
        Key(key) => out.push(map(key))
        _ => ()
      }
    MouseSub(map) => if event is Mouse(_) { out.push(map(event)) }
    MouseEventSub(map) =>
      match event {
        Mouse(mouse) => out.push(map(mouse))
        _ => ()
      }
    ResizeSub(map) =>
      match event {
        Resize(size) => out.push(map(size))
        _ => ()
      }
    PasteSub(map) =>
      match event {
        Paste(value) => out.push(map(value))
        _ => ()
      }
    FocusSub(map) =>
      if event is FocusGained || event is FocusLost {
        out.push(map(event))
      }
    FocusChangesSub(map) =>
      match event {
        FocusGained => out.push(map(true))
        FocusLost => out.push(map(false))
        _ => ()
      }
    TickSub(_, msg) => if event is Tick(_) { out.push(msg) }
  }
}

///|
pub(all) struct HeadlessOptions {
  size : Size
  render : Bool
  max_steps : Int
} derive(Eq, Debug)

///|
pub fn HeadlessOptions::default() -> HeadlessOptions {
  { size: { width: 80, height: 24 }, render: true, max_steps: 1000 }
}

///|
pub fn HeadlessOptions::size(
  self : HeadlessOptions,
  size : Size,
) -> HeadlessOptions {
  { ..self, size, }
}

///|
pub fn HeadlessOptions::render(
  self : HeadlessOptions,
  enabled : Bool,
) -> HeadlessOptions {
  { ..self, render: enabled }
}

///|
pub fn HeadlessOptions::max_steps(
  self : HeadlessOptions,
  value : Int,
) -> HeadlessOptions {
  { ..self, max_steps: Int::max(1, value) }
}

///|
pub(all) struct ProgramRunResult[Model] {
  model : Model
  terminal_commands : Array[TerminalCommand]
  frames : Array[Frame]
  quit : Bool
  steps : Int
  limit_reached : Bool
}

///|
pub struct Program[Model, Msg] {
  mut model : Model
  init_fn : (Emit[Msg], Model) -> Cmd
  update_fn : (Emit[Msg], Msg, Model) -> (Cmd, Model)
  view_fn : (Model) -> Node
  subscriptions_fn : (Model) -> Sub[Msg]
  mut dirty : Bool
}

///|
pub type Cell[Model, Msg] = Program[Model, Msg]

///|
pub fn[Model, Msg] cell(
  model~ : Model,
  init? : (Emit[Msg], Model) -> Cmd = (_, _) => none,
  update~ : (Emit[Msg], Msg, Model) -> (Cmd, Model),
  view~ : (Model) -> Node,
  subscriptions? : (Model) -> Sub[Msg] = _ => NoSub,
) -> Cell[Model, Msg] {
  {
    model,
    init_fn: init,
    update_fn: update,
    view_fn: view,
    subscriptions_fn: subscriptions,
    dirty: true,
  }
}

///|
pub fn[Model, Msg] simple_cell(
  model~ : Model,
  init? : (Emit[Msg], Model) -> Cmd = (_, _) => none,
  update~ : (Msg, Model) -> (Cmd, Model),
  view~ : (Model) -> Node,
  subscriptions? : (Model) -> Sub[Msg] = _ => NoSub,
) -> Cell[Model, Msg] {
  cell(
    model~,
    init~,
    update=(emit, msg, model) => {
      ignore(emit)
      update(msg, model)
    },
    view~,
    subscriptions~,
  )
}

///|
pub fn[Model, Msg] cell_with_emit(
  model~ : Model,
  init? : (Emit[Msg], Model) -> Cmd = (_, _) => none,
  update~ : (Emit[Msg], Msg, Model) -> (Cmd, Model),
  view~ : (Model) -> Node,
  subscriptions? : (Model) -> Sub[Msg] = _ => NoSub,
) -> (Emit[Msg], Cell[Model, Msg]) {
  let inbox : Array[Msg] = []
  let emit = Emit::new(msg => inbox.push(msg))
  let program = cell(model~, init~, update~, view~, subscriptions~)
  ignore(inbox)
  (emit, program)
}

///|
#deprecated("Use cell_with_emit instead.")
pub fn[Model, Msg] cell_with_dispatch(
  model~ : Model,
  init? : (Emit[Msg], Model) -> Cmd = (_, _) => none,
  update~ : (Emit[Msg], Msg, Model) -> (Cmd, Model),
  view~ : (Model) -> Node,
  subscriptions? : (Model) -> Sub[Msg] = _ => NoSub,
) -> (Emit[Msg], Cell[Model, Msg]) {
  cell_with_emit(model~, init~, update~, view~, subscriptions~)
}

///|
pub fn[Model, Msg] Program::model(self : Program[Model, Msg]) -> Model {
  self.model
}

///|
pub fn[Model, Msg] Program::is_dirty(self : Program[Model, Msg]) -> Bool {
  self.dirty
}

///|
pub fn[Model, Msg] Program::mark_clean(self : Program[Model, Msg]) -> Unit {
  self.dirty = false
}

///|
pub fn[Model, Msg] Program::mark_dirty(self : Program[Model, Msg]) -> Unit {
  self.dirty = true
}

///|
pub fn[Model, Msg] Program::view(self : Program[Model, Msg]) -> Node {
  (self.view_fn)(self.model)
}

///|
pub fn[Model, Msg] Program::init(
  self : Program[Model, Msg],
  emit : Emit[Msg],
) -> Cmd {
  (self.init_fn)(emit, self.model)
}

///|
pub fn[Model, Msg] Program::subscriptions(
  self : Program[Model, Msg],
) -> Sub[Msg] {
  (self.subscriptions_fn)(self.model)
}

///|
pub fn[Model, Msg] Program::step(
  self : Program[Model, Msg],
  emit : Emit[Msg],
  msg : Msg,
) -> Cmd {
  let (cmd, next) = (self.update_fn)(emit, msg, self.model)
  self.model = next
  self.dirty = true
  cmd
}

///|
pub fn[Model, Msg] Program::handle_event(
  self : Program[Model, Msg],
  emit : Emit[Msg],
  event : Event,
) -> Array[Cmd] {
  let cmds : Array[Cmd] = []
  for msg in self.subscriptions().map_event(event) {
    cmds.push(self.step(emit, msg))
  }
  cmds
}

///|
pub async fn[Model, Msg] Program::run_headless(
  self : Program[Model, Msg],
  events? : Array[Event] = [],
  options? : HeadlessOptions = HeadlessOptions::default(),
) -> ProgramRunResult[Model] {
  let queue = @aqueue.Queue::new(kind=Unbounded)
  let terminal_commands : Array[TerminalCommand] = []
  let frames : Array[Frame] = []
  let emit = Emit::new(msg => ignore(queue.try_put(msg) catch { _ => false }))
  let mut quit = false
  let mut steps = 0
  let mut limit_reached = false
  for cmd in self.handle_event(emit, Resize(options.size)) {
    if run_headless_cmd(cmd, terminal_commands) {
      quit = true
    }
    let drained = drain_headless_messages(
      self, emit, queue, terminal_commands, frames, options, steps,
    )
    if drained.quit {
      quit = true
    }
    steps = drained.steps
    limit_reached = limit_reached || drained.limit_reached
  }
  if !quit {
    if run_headless_cmd(self.init(emit), terminal_commands) {
      quit = true
    }
    let drained = drain_headless_messages(
      self, emit, queue, terminal_commands, frames, options, steps,
    )
    if drained.quit {
      quit = true
    }
    steps = drained.steps
    limit_reached = limit_reached || drained.limit_reached
  }
  if options.render && self.is_dirty() {
    frames.push(Frame::from_node(self.view(), options.size))
    self.mark_clean()
  }
  for event in events {
    if quit || limit_reached {
      break
    }
    for cmd in self.handle_event(emit, event) {
      if run_headless_cmd(cmd, terminal_commands) {
        quit = true
      }
      let drained = drain_headless_messages(
        self, emit, queue, terminal_commands, frames, options, steps,
      )
      if drained.quit {
        quit = true
      }
      steps = drained.steps
      limit_reached = limit_reached || drained.limit_reached
    }
    if options.render && self.is_dirty() {
      frames.push(Frame::from_node(self.view(), options.size))
      self.mark_clean()
    }
  }
  { model: self.model(), terminal_commands, frames, quit, steps, limit_reached }
}

///|
priv struct HeadlessDrain {
  quit : Bool
  steps : Int
  limit_reached : Bool
}

///|
async fn run_headless_cmd(
  cmd : Cmd,
  terminal_commands : Array[TerminalCommand],
) -> Bool {
  let mut quit = false
  cmd.run_with_terminal(command => {
    terminal_commands.push(command)
    if command is QuitProgram {
      quit = true
    }
  })
  quit
}

///|
async fn[Model, Msg] drain_headless_messages(
  program : Program[Model, Msg],
  emit : Emit[Msg],
  queue : @aqueue.Queue[Msg],
  terminal_commands : Array[TerminalCommand],
  frames : Array[Frame],
  options : HeadlessOptions,
  steps : Int,
) -> HeadlessDrain {
  let mut quit = false
  let mut next_steps = steps
  let mut limit_reached = false
  while true {
    if next_steps >= options.max_steps {
      limit_reached = true
      break
    }
    match (queue.try_get() catch { _ => None }) {
      Some(msg) => {
        next_steps += 1
        let cmd = program.step(emit, msg)
        if run_headless_cmd(cmd, terminal_commands) {
          quit = true
        }
        if options.render && program.is_dirty() {
          frames.push(Frame::from_node(program.view(), options.size))
          program.mark_clean()
        }
        if quit {
          break
        }
      }
      None => break
    }
  }
  { quit, steps: next_steps, limit_reached }
}
