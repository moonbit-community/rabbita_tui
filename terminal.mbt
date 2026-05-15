///|
#cfg(not(platform="windows"))
extern "C" fn tui_is_tty(fd : Int) -> Int = "moonbit_tui_is_tty"

///|
#cfg(not(platform="windows"))
extern "C" fn tui_enable_raw(fd : Int) -> Int = "moonbit_tui_enable_raw"

///|
#cfg(not(platform="windows"))
extern "C" fn tui_restore(fd : Int) -> Int = "moonbit_tui_restore"

///|
#cfg(not(platform="windows"))
extern "C" fn tui_width(fd : Int) -> Int = "moonbit_tui_width"

///|
#cfg(not(platform="windows"))
extern "C" fn tui_height(fd : Int) -> Int = "moonbit_tui_height"

///|
#cfg(not(platform="windows"))
#borrow(bytes)
extern "C" fn tui_write(
  fd : Int,
  bytes : Bytes,
  offset : Int,
  len : Int,
) -> Int = "moonbit_tui_write"

///|
#cfg(not(platform="windows"))
extern "C" fn tui_install_resize_handler() -> Unit = "moonbit_tui_install_resize_handler"

///|
#cfg(not(platform="windows"))
#borrow(command, args)
extern "C" fn tui_exec_process(
  command : Bytes,
  command_offset : Int,
  command_len : Int,
  args : Bytes,
  args_offset : Int,
  args_len : Int,
  argc : Int,
) -> Int = "moonbit_tui_exec_process"

///|
#coverage.skip
#cfg(not(platform="windows"))
pub fn is_tty(fd : Int) -> Bool {
  tui_is_tty(fd) == 1
}

///|
#coverage.skip
#cfg(platform="windows")
pub fn is_tty(fd : Int) -> Bool {
  ignore(fd)
  false
}

///|
#coverage.skip
#cfg(not(platform="windows"))
pub fn terminal_size() -> Size raise TerminalError {
  let width = tui_width(1)
  let height = tui_height(1)
  guard width > 0 && height > 0 else {
    raise NativeError("failed to read terminal size")
  }
  { width, height }
}

///|
#coverage.skip
#cfg(platform="windows")
pub fn terminal_size() -> Size raise TerminalError {
  raise UnsupportedPlatform
}

///|
#coverage.skip
#cfg(not(platform="windows"))
pub fn enter_raw_mode() -> Unit raise TerminalError {
  guard is_tty(0) && is_tty(1) else { raise NotATty("stdin/stdout") }
  guard tui_enable_raw(0) == 0 else {
    raise NativeError("failed to enable raw mode")
  }
  tui_install_resize_handler()
}

///|
#coverage.skip
#cfg(platform="windows")
pub fn enter_raw_mode() -> Unit raise TerminalError {
  raise UnsupportedPlatform
}

///|
#coverage.skip
#cfg(not(platform="windows"))
pub fn restore_terminal() -> Unit {
  ignore(tui_restore(0))
}

///|
#coverage.skip
#cfg(platform="windows")
pub fn restore_terminal() -> Unit {
  ()
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run(
  self : Program[Model, Msg],
) -> Unit raise TerminalError {
  ignore(self.run_with_options_returning_model(ProgramOptions::default()))
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_with_options(
  self : Program[Model, Msg],
  options : ProgramOptions,
) -> Unit raise TerminalError {
  ignore(self.run_with_options_returning_model(options))
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_returning_model(
  self : Program[Model, Msg],
) -> Model raise TerminalError {
  self.run_with_options_returning_model(ProgramOptions::default())
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_with_options_returning_model(
  self : Program[Model, Msg],
  options : ProgramOptions,
) -> Model raise TerminalError {
  self.run_with_runtime_control(options, None, 0).model
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_with_cancel_token(
  self : Program[Model, Msg],
  options : ProgramOptions,
  token : CancelToken,
) -> Model raise TerminalError {
  self.run_with_cancel_token_result(options, token).model
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_with_timeout(
  self : Program[Model, Msg],
  options : ProgramOptions,
  milliseconds : Int,
) -> Model raise TerminalError {
  self.run_with_timeout_result(options, milliseconds).model
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_with_options_result(
  self : Program[Model, Msg],
  options : ProgramOptions,
) -> ProgramRuntimeResult[Model] raise TerminalError {
  self.run_with_runtime_control(options, None, 0)
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_with_cancel_token_result(
  self : Program[Model, Msg],
  options : ProgramOptions,
  token : CancelToken,
) -> ProgramRuntimeResult[Model] raise TerminalError {
  self.run_with_runtime_control(options, Some(token), 0)
}

///|
#coverage.skip
pub async fn[Model, Msg] Program::run_with_timeout_result(
  self : Program[Model, Msg],
  options : ProgramOptions,
  milliseconds : Int,
) -> ProgramRuntimeResult[Model] raise TerminalError {
  self.run_with_runtime_control(options, None, milliseconds)
}

///|
#coverage.skip
priv struct RuntimeState {
  mut previous : StyledFrame?
  mut current_size : Size
  mut exit : ProgramExit
}

///|
#coverage.skip
async fn[Model, Msg] Program::run_with_runtime_control(
  self : Program[Model, Msg],
  options : ProgramOptions,
  cancel_token : CancelToken?,
  timeout_millis : Int,
) -> ProgramRuntimeResult[Model] raise TerminalError {
  enter_raw_mode()
  defer restore_terminal()
  let state : RuntimeState = {
    previous: None,
    current_size: terminal_size(),
    exit: ProgramQuit,
  }
  let queue = @aqueue.Queue::new(kind=Unbounded)
  let emit = Emit::new(msg => {
    ignore(queue.try_put(RuntimeMsg(msg)) catch { _ => false })
  })
  for cmd in self.handle_event(emit, Resize(state.current_size)) {
    cmd.run_with_terminal(command => {
      ignore(queue.try_put(RuntimeTerminal(command)) catch { _ => false })
    }) catch {
      err => raise NativeError(err.to_string())
    }
  }
  self
  .init(emit)
  .run_with_terminal(command => {
    ignore(queue.try_put(RuntimeTerminal(command)) catch { _ => false })
  }) catch {
    err => raise NativeError(err.to_string())
  }
  if options.renderer_enabled {
    let initial_view = self.view()
    let initial_frame = StyledFrame::from_node(initial_view, state.current_size)
    write_terminal(
      start_program_output(
        options,
        initial_view,
        state.current_size,
        initial_frame,
      ),
    )
    state.previous = Some(initial_frame)
  } else {
    write_terminal(start_program_control_output(options))
  }
  self.mark_clean()
  @async.with_task_group(group => {
    self.subscriptions().start(emit, group)
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      read_terminal_input(self, queue, group)
    })
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      watch_terminal_resize(
        queue,
        state.current_size,
        options.resize_poll_millis,
      )
    })
    if options.renderer_enabled && options.renderer_fps > 0 {
      let interval = Int::max(1, 1000 / options.renderer_fps)
      group.spawn_bg(no_wait=true, allow_failure=true, () => {
        while true {
          @async.sleep(interval)
          queue.put(RuntimeRender)
        }
      })
    }
    match cancel_token {
      Some(token) =>
        group.spawn_bg(no_wait=true, allow_failure=true, () => {
          while !token.is_cancelled() {
            @async.sleep(16)
          }
          queue.put(RuntimeCancel)
        })
      None => ()
    }
    if timeout_millis > 0 {
      group.spawn_bg(no_wait=true, allow_failure=true, () => {
        @async.sleep(timeout_millis)
        queue.put(RuntimeTimeout)
      })
    }
    while true {
      let item = queue.get()
      let mut render_due = options.renderer_fps <= 0 ||
        item is RuntimeRender ||
        item is RuntimeResize(_)
      match
        handle_runtime_item(self, emit, queue, group, item, options, state) {
        Some(exit) => {
          state.exit = exit
          group.return_immediately(())
          break
        }
        None => ()
      }
      let mut drained = 0
      while drained < options.max_messages_per_frame {
        match (queue.try_get() catch { _ => None }) {
          Some(item) => {
            if item is RuntimeRender || item is RuntimeResize(_) {
              render_due = true
            }
            match
              handle_runtime_item(
                self, emit, queue, group, item, options, state,
              ) {
              Some(exit) => {
                state.exit = exit
                group.return_immediately(())
                break
              }
              None => ()
            }
            drained += 1
          }
          None => break
        }
      }
      if self.is_dirty() && render_due {
        if options.renderer_enabled {
          let next_size = terminal_size()
          let resized = next_size != state.current_size
          state.current_size = next_size
          let next = StyledFrame::from_node(self.view(), state.current_size)
          let output = if resized {
            repaint_resized_frame(next)
          } else {
            frame_update_output(options, state.previous, next)
          }
          write_terminal(output)
          state.previous = Some(next)
        } else {
          state.current_size = terminal_size() catch { _ => state.current_size }
        }
        self.mark_clean()
      }
    }
  }) catch {
    err if @async.is_cancellation_error(err) => ()
    err => raise NativeError(err.to_string())
  }
  write_terminal(stop_program_output(options))
  { model: self.model(), exit: state.exit }
}

///|
#coverage.skip
priv enum RuntimeItem[Msg] {
  RuntimeMsg(Msg)
  RuntimeTerminal(TerminalCommand)
  RuntimeRender
  RuntimeResize(Size)
  RuntimeCancel
  RuntimeTimeout
}

///|
#coverage.skip
fn start_program_output(
  options : ProgramOptions,
  node : Node,
  size : Size,
  frame : StyledFrame,
) -> String {
  if !options.renderer_enabled {
    return start_program_control_output(options)
  }
  if options.alternate_screen {
    ansi_start_program(options, node, size)
  } else {
    let out = StringBuilder::new()
    out.write_string(ansi_disable_autowrap())
    if options.hide_cursor {
      out.write_string(ansi_hide_cursor())
    }
    if options.mouse_mode != MouseOff {
      out.write_string(ansi_enable_mouse(options.mouse_mode))
    }
    if options.bracketed_paste {
      out.write_string(ansi_enable_bracketed_paste())
    }
    if options.focus_events {
      out.write_string(ansi_enable_focus_events())
    }
    out.write_string(paint_styled_frame_inline(frame))
    out.to_string()
  }
}

///|
#coverage.skip
fn start_program_control_output(options : ProgramOptions) -> String {
  let out = StringBuilder::new()
  if options.alternate_screen {
    out.write_string(ansi_enter_alternate_screen())
  }
  out.write_string(ansi_disable_autowrap())
  if options.hide_cursor {
    out.write_string(ansi_hide_cursor())
  }
  if options.mouse_mode != MouseOff {
    out.write_string(ansi_enable_mouse(options.mouse_mode))
  }
  if options.bracketed_paste {
    out.write_string(ansi_enable_bracketed_paste())
  }
  if options.focus_events {
    out.write_string(ansi_enable_focus_events())
  }
  out.to_string()
}

///|
#coverage.skip
fn frame_update_output(
  options : ProgramOptions,
  previous : StyledFrame?,
  next : StyledFrame,
) -> String {
  if options.alternate_screen {
    match previous {
      None => paint_styled_frame_ansi(next)
      Some(prev) => diff_styled_frame(prev, next)
    }
  } else {
    match previous {
      None => repaint_styled_frame_inline(next.lines.length(), next)
      Some(prev) => diff_styled_frame_inline(prev, next)
    }
  }
}

///|
#coverage.skip
fn stop_program_output(options : ProgramOptions) -> String {
  let out = StringBuilder::new()
  out.write_string(ansi_stop_program(options))
  if !options.alternate_screen {
    out.write_string("\r\n")
  }
  out.to_string()
}

///|
#coverage.skip
fn repaint_resized_frame(frame : StyledFrame) -> String {
  let out = StringBuilder::new()
  out.write_string(ansi_clear_screen())
  out.write_string(ansi_move_cursor(1, 1))
  out.write_string(paint_styled_frame_ansi(frame))
  out.to_string()
}

///|
#coverage.skip
fn safe_terminal_command_output(
  command : TerminalCommand,
  options : ProgramOptions,
  state : RuntimeState,
  fd~ : Int,
) -> String {
  if fd == 2 && !is_tty(2) {
    return raw_terminal_command_output(command)
  }
  match command {
    Print(value) => safe_print_output(value, newline=false, options, state)
    PrintLine(value) => safe_print_output(value, newline=true, options, state)
    PrintErr(value) => safe_print_output(value, newline=false, options, state)
    PrintErrLine(value) =>
      safe_print_output(value, newline=true, options, state)
    _ => ansi_terminal_command(command)
  }
}

///|
#coverage.skip
fn raw_terminal_command_output(command : TerminalCommand) -> String {
  match command {
    Print(value) | PrintErr(value) => value
    PrintLine(value) | PrintErrLine(value) => "\{value}\n"
    _ => ansi_terminal_command(command)
  }
}

///|
#coverage.skip
fn terminal_command_fd(command : TerminalCommand) -> Int {
  match command {
    PrintErr(_) | PrintErrLine(_) => 2
    _ => 1
  }
}

///|
#coverage.skip
fn safe_print_output(
  value : String,
  newline~ : Bool,
  options : ProgramOptions,
  state : RuntimeState,
) -> String {
  if !options.renderer_enabled {
    return if newline { "\{value}\r\n" } else { value }
  }
  match state.previous {
    None => if newline { "\{value}\r\n" } else { value }
    Some(frame) => {
      let out = StringBuilder::new()
      if options.alternate_screen {
        out.write_string(ansi_leave_alternate_screen())
        write_safe_print_text(out, value, newline)
        out.write_string(ansi_enter_alternate_screen())
        out.write_string(
          start_program_control_output({ ..options, alternate_screen: false }),
        )
        out.write_string(paint_styled_frame_ansi(frame))
        return out.to_string()
      } else if frame.lines.length() > 0 {
        out.write_string(ansi_move_cursor_up(frame.lines.length() - 1))
      }
      out.write_string("\r")
      write_safe_print_text(out, value, newline)
      if options.alternate_screen {
        out.write_string(paint_styled_frame_ansi(frame))
      } else {
        out.write_string(paint_styled_frame_inline(frame))
      }
      out.to_string()
    }
  }
}

///|
#coverage.skip
fn write_safe_print_text(
  out : StringBuilder,
  value : String,
  newline : Bool,
) -> Unit {
  let lines = split_safe_print(value)
  if lines.is_empty() {
    if newline {
      out.write_string(ansi_clear_line())
      out.write_string("\r\n")
    }
    return
  }
  for index, line in lines {
    out.write_string(line)
    out.write_string(ansi_clear_line())
    if index + 1 < lines.length() || newline {
      out.write_string("\r\n")
    }
  }
}

///|
#coverage.skip
fn split_safe_print(value : String) -> Array[String] {
  let lines : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < value.length() {
    if value.code_unit_at(index) == Int::to_uint16('\n'.to_int()) {
      lines.push(trim_safe_print_cr(value[start:index].to_owned()))
      start = index + 1
    }
    index += 1
  }
  if start < value.length() {
    lines.push(trim_safe_print_cr(value[start:].to_owned()))
  }
  lines
}

///|
#coverage.skip
fn trim_safe_print_cr(value : String) -> String {
  if value.length() > 0 &&
    value.code_unit_at(value.length() - 1) == Int::to_uint16('\r'.to_int()) {
    value[:value.length() - 1].to_owned()
  } else {
    value
  }
}

///|
#coverage.skip
async fn[Model, Msg] handle_runtime_item(
  program : Program[Model, Msg],
  emit : Emit[Msg],
  queue : @aqueue.Queue[RuntimeItem[Msg]],
  group : @async.TaskGroup[Unit],
  item : RuntimeItem[Msg],
  options : ProgramOptions,
  state : RuntimeState,
) -> ProgramExit? {
  match item {
    RuntimeMsg(msg) => {
      handle_runtime_msg(program, emit, queue, group, msg, options, state)
      None
    }
    RuntimeTerminal(command) =>
      handle_terminal_command(command, program, options, state)
    RuntimeRender => None
    RuntimeResize(size) => {
      state.current_size = size
      program.mark_dirty()
      for msg in program.subscriptions().map_event(Resize(size)) {
        queue.put(RuntimeMsg(msg))
      }
      None
    }
    RuntimeCancel => Some(ProgramCancelled)
    RuntimeTimeout => Some(ProgramTimedOut)
  }
}

///|
#coverage.skip
async fn[Model, Msg] handle_runtime_msg(
  program : Program[Model, Msg],
  emit : Emit[Msg],
  queue : @aqueue.Queue[RuntimeItem[Msg]],
  group : @async.TaskGroup[Unit],
  msg : Msg,
  options : ProgramOptions,
  state : RuntimeState,
) -> Unit {
  let cmd = program.step(emit, msg)
  if cmd_needs_suspension(cmd) {
    run_runtime_cmd(program, cmd, queue, group, options, state)
  } else {
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      run_runtime_cmd(program, cmd, queue, group, options, state)
    })
  }
}

///|
#coverage.skip
fn cmd_needs_suspension(cmd : Cmd) -> Bool {
  match cmd {
    CmdSuspend(_) | CmdExecProcess(_, _, _) => true
    CmdBatch(cmds) | CmdSequence(cmds) => {
      for child in cmds {
        if cmd_needs_suspension(child) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
#coverage.skip
async fn[Model, Msg] run_runtime_cmd(
  program : Program[Model, Msg],
  cmd : Cmd,
  queue : @aqueue.Queue[RuntimeItem[Msg]],
  group : @async.TaskGroup[Unit],
  options : ProgramOptions,
  state : RuntimeState,
) -> Unit {
  match cmd {
    NoCmd => ()
    CmdMessage(send) => send()
    CmdBatch(cmds) =>
      @async.with_task_group(batch => {
        for child in cmds {
          batch.spawn_bg(() => {
            run_runtime_cmd(program, child, queue, group, options, state)
          })
        }
      })
    CmdSequence(cmds) =>
      for child in cmds {
        run_runtime_cmd(program, child, queue, group, options, state)
      }
    CmdDelay(milliseconds, cmd) => {
      @async.sleep(Int::max(1, milliseconds))
      run_runtime_cmd(program, cmd, queue, group, options, state)
    }
    CmdEvery(milliseconds, cmd) => {
      let interval = Int::max(1, milliseconds)
      while true {
        @async.sleep(interval)
        run_runtime_cmd(program, cmd, queue, group, options, state)
      }
    }
    CmdTask(task) => {
      let next = task()
      run_runtime_cmd(program, next, queue, group, options, state)
    }
    CmdSuspend(task) => {
      let next = run_suspended_task(program, options, state, task)
      run_runtime_cmd(program, next, queue, group, options, state)
    }
    CmdExecProcess(command, args, done) => {
      let status = run_suspended_process(program, options, state, command, args)
      run_runtime_cmd(program, done(status), queue, group, options, state)
    }
    CmdTerminal(command) => queue.put(RuntimeTerminal(command))
  }
}

///|
#coverage.skip
async fn[Model, Msg] run_suspended_task(
  program : Program[Model, Msg],
  options : ProgramOptions,
  state : RuntimeState,
  task : async () -> Cmd,
) -> Cmd raise TerminalError {
  suspend_terminal(options, state)
  let msg = task() catch {
    err => {
      resume_terminal(program, options, state) catch {
        _ => ()
      }
      raise NativeError(err.to_string())
    }
  }
  resume_terminal(program, options, state)
  msg
}

///|
#coverage.skip
fn[Model, Msg] run_suspended_process(
  program : Program[Model, Msg],
  options : ProgramOptions,
  state : RuntimeState,
  command : String,
  args : Array[String],
) -> Int raise TerminalError {
  suspend_terminal(options, state)
  let status = run_process(command, args) catch {
    err => {
      resume_terminal(program, options, state) catch {
        _ => ()
      }
      raise err
    }
  }
  resume_terminal(program, options, state)
  status
}

///|
#coverage.skip
fn suspend_terminal(
  options : ProgramOptions,
  state : RuntimeState,
) -> Unit raise TerminalError {
  let output = StringBuilder::new()
  match state.previous {
    Some(frame) if options.renderer_enabled =>
      if !options.alternate_screen && frame.lines.length() > 0 {
        output.write_string(
          "\{ansi_move_cursor_up(frame.lines.length() - 1)}\r",
        )
      }
    _ => ()
  }
  output.write_string(stop_program_output(options))
  write_terminal(output.to_string()) catch {
    err => {
      restore_terminal()
      raise err
    }
  }
  restore_terminal()
}

///|
#coverage.skip
fn[Model, Msg] resume_terminal(
  program : Program[Model, Msg],
  options : ProgramOptions,
  state : RuntimeState,
) -> Unit raise TerminalError {
  enter_raw_mode()
  if options.renderer_enabled {
    let size = terminal_size()
    let view = program.view()
    let frame = StyledFrame::from_node(view, size)
    write_terminal(start_program_output(options, view, size, frame))
    state.current_size = size
    state.previous = Some(frame)
  } else {
    write_terminal(start_program_control_output(options))
    state.current_size = terminal_size() catch { _ => state.current_size }
    state.previous = None
  }
}

///|
#coverage.skip
#cfg(not(platform="windows"))
fn run_process(
  command : String,
  args : Array[String],
) -> Int raise TerminalError {
  let bytes = @encoding/utf8.encode(command)
  let packed_args = pack_exec_args(args)
  let status = tui_exec_process(
    bytes,
    0,
    bytes.length(),
    packed_args,
    0,
    packed_args.length(),
    args.length(),
  )
  if status < 0 {
    raise NativeError("failed to execute process: \{command}")
  }
  status
}

///|
#coverage.skip
#cfg(platform="windows")
fn run_process(
  command : String,
  args : Array[String],
) -> Int raise TerminalError {
  ignore(command)
  ignore(args)
  raise UnsupportedPlatform
}

///|
#coverage.skip
fn pack_exec_args(args : Array[String]) -> Bytes {
  let out = StringBuilder::new()
  for index, arg in args {
    if index > 0 {
      out.write_char('\u{00}')
    }
    out.write_string(arg)
  }
  @encoding/utf8.encode(out.to_string())
}

///|
#coverage.skip
fn[Model, Msg] handle_terminal_command(
  command : TerminalCommand,
  program : Program[Model, Msg],
  options : ProgramOptions,
  state : RuntimeState,
) -> ProgramExit? raise TerminalError {
  match command {
    QuitProgram => Some(ProgramQuit)
    Repaint => {
      program.mark_dirty()
      None
    }
    _ => {
      let fd = terminal_command_fd(command)
      write_terminal_fd(
        fd,
        safe_terminal_command_output(command, options, state, fd~),
      )
      if command is ClearScreen {
        program.mark_dirty()
      }
      None
    }
  }
}

///|
#coverage.skip
async fn[Msg] watch_terminal_resize(
  queue : @aqueue.Queue[RuntimeItem[Msg]],
  initial_size : Size,
  poll_millis : Int,
) -> Unit {
  let mut last = initial_size
  while true {
    @async.sleep(poll_millis)
    let next = terminal_size() catch { _ => last }
    if next != last {
      last = next
      queue.put(RuntimeResize(next))
    }
  }
}

///|
#coverage.skip
async fn[Model, Msg] read_terminal_input(
  program : Program[Model, Msg],
  queue : @aqueue.Queue[RuntimeItem[Msg]],
  group : @async.TaskGroup[Unit],
) -> Unit {
  let mut decoder = InputDecoder::new()
  let mut pending_idle = 0
  while true {
    match @stdio.stdin.read_some(max_len=32) {
      None => {
        if decoder.has_pending() && decoder.pending_is_lone_escape() {
          pending_idle += 1
          if pending_idle >= 2 {
            let (events, next) = decoder.flush()
            decoder = next
            pending_idle = 0
            dispatch_input_events(program, queue, group, events)
          }
        }
        @async.sleep(16)
      }
      Some(bytes) => {
        pending_idle = 0
        let (events, next) = decoder.feed(bytes)
        decoder = next
        dispatch_input_events(program, queue, group, events)
      }
    }
  }
}

///|
#coverage.skip
async fn[Model, Msg] dispatch_input_events(
  program : Program[Model, Msg],
  queue : @aqueue.Queue[RuntimeItem[Msg]],
  group : @async.TaskGroup[Unit],
  events : Array[Event],
) -> Unit {
  ignore(group)
  for event in events {
    for msg in program.subscriptions().map_event(event) {
      queue.put(RuntimeMsg(msg))
    }
  }
}

///|
#coverage.skip
fn[Msg, X] Sub::start(
  self : Sub[Msg],
  emit : Emit[Msg],
  group : @async.TaskGroup[X],
) -> Unit {
  match self {
    NoSub => ()
    SubBatch(subs) =>
      for sub in subs {
        sub.start(emit, group)
      }
    TickSub(milliseconds, msg) =>
      group.spawn_bg(no_wait=true, allow_failure=true, () => {
        while true {
          @async.sleep(milliseconds)
          emit.send(msg)
        }
      })
    EventSub(_)
    | Keyboard(_)
    | KeySub(_)
    | MouseSub(_)
    | MouseEventSub(_)
    | ResizeSub(_)
    | PasteSub(_)
    | FocusSub(_)
    | FocusChangesSub(_) => ()
  }
}

///|
#coverage.skip
#cfg(not(platform="windows"))
fn write_terminal(output : String) -> Unit raise TerminalError {
  write_terminal_fd(1, output)
}

///|
#coverage.skip
#cfg(not(platform="windows"))
fn write_terminal_fd(fd : Int, output : String) -> Unit raise TerminalError {
  let bytes = @encoding/utf8.encode(output)
  let mut offset = 0
  while offset < bytes.length() {
    let written = tui_write(fd, bytes, offset, bytes.length() - offset)
    if written <= 0 {
      raise NativeError("failed to write terminal output")
    } else {
      offset += written
    }
  }
}

///|
#coverage.skip
#cfg(platform="windows")
fn write_terminal(output : String) -> Unit raise TerminalError {
  ignore(output)
  raise UnsupportedPlatform
}

///|
#coverage.skip
#cfg(platform="windows")
fn write_terminal_fd(fd : Int, output : String) -> Unit raise TerminalError {
  ignore(fd)
  ignore(output)
  raise UnsupportedPlatform
}
