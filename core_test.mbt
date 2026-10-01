///|
enum TestMsg {
  Add(Int)
  Rendered
  Pasted(String)
  Focused(String)
  AnyEvent(String)
  ResizeSeen(Int, Int)
  Clicked(Int, Int)
} derive(Eq, Debug)

///|
suberror AttemptFailed derive(Debug)

///|
fn test_emit(log : Array[TestMsg]) -> @rabbita_tui.Emit[TestMsg] {
  @rabbita_tui.Emit::new(msg => log.push(msg))
}

///|
async test "cmd sequence runs emitted messages in order" {
  let log : Array[TestMsg] = []
  let emit = test_emit(log)
  @rabbita_tui.Cmd::sequence([
    emit(Add(1)),
    @rabbita_tui.Cmd::none(),
    @rabbita_tui.Cmd::sequence([emit(Add(2)), emit(Rendered)]),
  ]).run()
  @debug.assert_eq(log, [Add(1), Add(2), Rendered])
  @debug.assert_eq(@rabbita_tui.Cmd::batch([]).is_none(), true)
  @debug.assert_eq(
    @rabbita_tui.Cmd::batch([@rabbita_tui.Cmd::none()]).is_none(),
    true,
  )
  @debug.assert_eq(@rabbita_tui.delay(emit(Add(9)), 1).is_none(), false)
}

///|
test "cmd sequence flattens and terminal commands are inspectable" {
  let cmd = @rabbita_tui.Cmd::sequence([
    @rabbita_tui.Cmd::sequence([
      @rabbita_tui.Cmd::terminal(SetWindowTitle("demo")),
      @rabbita_tui.Cmd::enable_mouse(MouseButtonMotion),
      @rabbita_tui.Cmd::disable_mouse(),
      @rabbita_tui.Cmd::quit(),
    ]),
    @rabbita_tui.Cmd::none(),
  ])
  @debug.assert_eq(cmd.terminal_commands(), [
    SetWindowTitle("demo"),
    EnableMouse(MouseButtonMotion),
    DisableMouse,
    QuitProgram,
  ])
  let empty_cmd = @rabbita_tui.Cmd::sequence([@rabbita_tui.Cmd::none()])
  @debug.assert_eq(empty_cmd.is_none(), true)
  @debug.assert_eq(empty_cmd.terminal_commands(), [])
}

///|
test "program options expose terminal mode builders" {
  let options = @rabbita_tui.ProgramOptions::default()
    .alternate_screen(false)
    .mouse(MouseAllMotion)
    .bracketed_paste(true)
    .focus_events(true)
    .hide_cursor(false)
    .without_renderer()
    .fps(30)
    .max_messages_per_frame(4)
    .resize_poll_millis(25)
  @debug.assert_eq(options.alternate_screen, false)
  @debug.assert_eq(options.mouse_mode, MouseAllMotion)
  @debug.assert_eq(options.bracketed_paste, true)
  @debug.assert_eq(options.focus_events, true)
  @debug.assert_eq(options.hide_cursor, false)
  @debug.assert_eq(options.renderer_enabled, false)
  @debug.assert_eq(options.renderer_fps, 30)
  @debug.assert_eq(options.max_messages_per_frame, 4)
  @debug.assert_eq(options.resize_poll_millis, 25)
  @debug.assert_eq(
    @rabbita_tui.ProgramOptions::inline().alternate_screen,
    false,
  )
}

///|
test "cancel token can be shared with a running program" {
  let token = @rabbita_tui.CancelToken::new()
  @debug.assert_eq(token.is_cancelled(), false)
  token.cancel()
  @debug.assert_eq(token.is_cancelled(), true)
}

///|
test "emit sends through the configured function" {
  let log : Array[TestMsg] = []
  let emit = test_emit(log)
  emit.send(Add(42))
  emit.send(Rendered)
  @debug.assert_eq(log, [Add(42), Rendered])
}

///|
async test "program step updates model and marks dirty" {
  let log : Array[TestMsg] = []
  let emit = test_emit(log)
  let program = @rabbita_tui.simple_cell(
    model=0,
    update=(msg, model) => {
      match msg {
        Add(n) => (emit(Rendered), model + n)
        _ => (@rabbita_tui.Cmd::none(), model)
      }
    },
    view=model => @rabbita_tui.text("count \{model}"),
  )
  program.mark_clean()
  let cmd = program.step(emit, Add(3))
  cmd.run()
  @debug.assert_eq(program.model(), 3)
  @debug.assert_eq(program.is_dirty(), true)
  @debug.assert_eq(log, [Rendered])
  @debug.assert_eq(
    @rabbita_tui.render_plain(program.view(), { width: 10, height: 1, }),
    ["count 3   "],
  )
}

///|
test "subscriptions map keyboard mouse resize and tick events" {
  let sub = @rabbita_tui.Sub::batch([
    @rabbita_tui.Sub::event(event => {
      match event {
        Key(_) => AnyEvent("key")
        Mouse(_) => AnyEvent("mouse")
        Resize(_) => AnyEvent("resize")
        Paste(_) => AnyEvent("paste")
        FocusGained => AnyEvent("focus")
        Tick(_) => AnyEvent("tick")
        _ => AnyEvent("other")
      }
    }),
    @rabbita_tui.Sub::keys(key => {
      match key {
        Enter => Rendered
        _ => AnyEvent("key")
      }
    }),
    @rabbita_tui.Sub::mouse_events(mouse => Clicked(mouse.x, mouse.y)),
    @rabbita_tui.Sub::resize(size => ResizeSeen(size.width, size.height)),
    @rabbita_tui.Sub::paste(value => Pasted(value)),
    @rabbita_tui.Sub::focus_changes(focused => {
      Focused(if focused { "in" } else { "out" })
    }),
    @rabbita_tui.Sub::tick(16, Add(1)),
  ])
  @debug.assert_eq(sub.map_event(Key(Enter)), [AnyEvent("key"), Rendered])
  @debug.assert_eq(
    sub.map_event(Mouse({ button: Primary, action: Press, x: 2, y: 4, })),
    [AnyEvent("mouse"), Clicked(2, 4)],
  )
  @debug.assert_eq(sub.map_event(Resize({ width: 80, height: 24, })), [
    AnyEvent("resize"),
    ResizeSeen(80, 24),
  ])
  @debug.assert_eq(sub.map_event(Paste("abc")), [
    AnyEvent("paste"),
    Pasted("abc"),
  ])
  @debug.assert_eq(sub.map_event(FocusGained), [
    AnyEvent("focus"),
    Focused("in"),
  ])
  @debug.assert_eq(sub.map_event(Tick(1L)), [AnyEvent("tick"), Add(1)])
}

///|
test "direct subscriptions map events without optional callback results" {
  let sub = @rabbita_tui.Sub::batch([
    @rabbita_tui.Sub::event(_ => AnyEvent("event")),
    @rabbita_tui.Sub::keyboard(_ => AnyEvent("keyboard")),
    @rabbita_tui.Sub::mouse(_ => AnyEvent("mouse")),
    @rabbita_tui.Sub::focus(_ => AnyEvent("focus")),
  ])
  @debug.assert_eq(sub.map_event(Key(Enter)), [
    AnyEvent("event"),
    AnyEvent("keyboard"),
  ])
  @debug.assert_eq(
    sub.map_event(Mouse({ button: Primary, action: Press, x: 2, y: 4, })),
    [AnyEvent("event"), AnyEvent("mouse")],
  )
  @debug.assert_eq(sub.map_event(FocusGained), [
    AnyEvent("event"),
    AnyEvent("focus"),
  ])
}

///|
async test "cmd delay and perform deliver messages" {
  let log : Array[TestMsg] = []
  let emit = test_emit(log)
  @rabbita_tui.Cmd::sequence([
    @rabbita_tui.Cmd::none(),
    emit(Add(1)),
    @rabbita_tui.delay(emit(Add(7)), 1),
    @rabbita_tui.Cmd::perform(msg => emit(msg), () => Rendered),
  ]).run()
  @debug.assert_eq(log, [Add(1), Add(7), Rendered])
}

///|
async test "cmd batch runs async commands concurrently" {
  let log : Array[TestMsg] = []
  let emit = test_emit(log)
  @rabbita_tui.Cmd::batch([
    @rabbita_tui.delay(emit(Add(1)), 20),
    @rabbita_tui.delay(emit(Add(2)), 1),
  ]).run()
  @debug.assert_eq(log, [Add(2), Add(1)])
}

///|
async test "cmd run with terminal emits terminal commands in sequence" {
  let log : Array[TestMsg] = []
  let terminal : Array[@rabbita_tui.TerminalCommand] = []
  let emit = test_emit(log)
  @rabbita_tui.Cmd::sequence([
    emit(Add(1)),
    @rabbita_tui.Cmd::log("hello"),
    @rabbita_tui.Cmd::err_log("warn"),
    @rabbita_tui.Cmd::terminal(ClearScreen),
    @rabbita_tui.delay(emit(Add(2)), 1),
    @rabbita_tui.Cmd::write("tail"),
    @rabbita_tui.Cmd::set_window_title("next"),
  ]).run_with_terminal(command => terminal.push(command))
  @debug.assert_eq(log, [Add(1), Add(2)])
  @debug.assert_eq(terminal, [
    PrintLine("hello"),
    PrintErrLine("warn"),
    ClearScreen,
    Print("tail"),
    SetWindowTitle("next"),
  ])
}

///|
async test "cmd attempt maps success and failure into messages" {
  let log : Array[TestMsg] = []
  let emit = test_emit(log)
  @rabbita_tui.Cmd::batch([
    @rabbita_tui.Cmd::attempt(
      result => {
        match result {
          Ok(msg) => emit(msg)
          Err(_) => emit(Rendered)
        }
      },
      () => Add(5),
    ),
    @rabbita_tui.Cmd::attempt(
      result => {
        match result {
          Ok(msg) => emit(msg)
          Err(_) => emit(Add(99))
        }
      },
      () => raise AttemptFailed,
    ),
  ]).run()
  @debug.assert_eq(log, [Add(5), Add(99)])
}

///|
async test "cmd suspend and exec process map back into messages" {
  let log : Array[TestMsg] = []
  let emit = test_emit(log)
  @rabbita_tui.Cmd::sequence([
    @rabbita_tui.Cmd::suspend(() => emit(Add(8))),
    @rabbita_tui.Cmd::exec_process("true", code => emit(Add(code))),
  ]).run()
  @debug.assert_eq(log, [Add(8), Add(0)])
}

///|
test "subscription empty and nested batches are normalized" {
  let empty : @rabbita_tui.Sub[TestMsg] = @rabbita_tui.Sub::batch([
    @rabbita_tui.Sub::none(),
    @rabbita_tui.Sub::batch([]),
  ])
  @debug.assert_eq(empty.map_event(Key(Enter)), [])
  let nested = @rabbita_tui.Sub::batch([
    @rabbita_tui.Sub::none(),
    @rabbita_tui.Sub::batch([
      @rabbita_tui.Sub::keys(key => {
        match key {
          Char("x") => Add(1)
          _ => Add(0)
        }
      }),
    ]),
  ])
  @debug.assert_eq(nested.map_event(Key(Char("x"))), [Add(1)])
  @debug.assert_eq(nested.map_event(Key(Char("y"))), [Add(0)])
}

///|
test "program exposes subscriptions and handles subscribed events" {
  let emit = test_emit([])
  let program = @rabbita_tui.cell(
    model=0,
    update=(_emit, msg, model) => {
      match msg {
        Add(n) => (@rabbita_tui.Cmd::none(), model + n)
        _ => (@rabbita_tui.Cmd::none(), model)
      }
    },
    view=model => @rabbita_tui.text(model.to_string()),
    subscriptions=_ => {
      @rabbita_tui.Sub::keys(key => {
        match key {
          Char("a") => Add(2)
          _ => Add(0)
        }
      })
    },
  )
  let cmds = program.handle_event(emit, Key(Char("a")))
  @debug.assert_eq(cmds.length(), 1)
  @debug.assert_eq(program.model(), 2)
  @debug.assert_eq(program.subscriptions().map_event(Key(Char("z"))), [Add(0)])
}

///|
async test "program init and headless runner return final model frames and commands" {
  let program = @rabbita_tui.simple_cell(
    model=0,
    init=(emit, _) => emit(Add(1)),
    update=(msg, model) => {
      match msg {
        Add(n) => {
          let next = model + n
          let cmd = if next >= 5 {
            @rabbita_tui.Cmd::sequence([
              @rabbita_tui.Cmd::log("done"),
              @rabbita_tui.Cmd::quit(),
            ])
          } else {
            @rabbita_tui.Cmd::write("step")
          }
          (cmd, next)
        }
        _ => (@rabbita_tui.Cmd::none(), model)
      }
    },
    view=model => @rabbita_tui.text(model.to_string()),
    subscriptions=_ => {
      @rabbita_tui.Sub::batch([
        @rabbita_tui.Sub::resize(size => Add(size.width)),
        @rabbita_tui.Sub::keys(key => {
          match key {
            Char("a") => Add(1)
            _ => Add(0)
          }
        }),
      ])
    },
  )
  let result = program.run_headless(
    events=[Key(Char("a"))],
    options=@rabbita_tui.HeadlessOptions::default().size({
      width: 3,
      height: 1,
    }),
  )
  @debug.assert_eq(result.model, 5)
  @debug.assert_eq(result.quit, true)
  @debug.assert_eq(result.limit_reached, false)
  @debug.assert_eq(result.terminal_commands, [
    Print("step"),
    Print("step"),
    PrintLine("done"),
    QuitProgram,
  ])
  @debug.assert_eq(result.frames.length(), 2)
  @debug.assert_eq(result.frames[0].to_string(), "4  ")
  @debug.assert_eq(result.frames[1].to_string(), "5  ")
}

///|
async test "headless runner can disable rendering and stops at step limit" {
  let program = @rabbita_tui.cell(
    model=0,
    init=(emit, _) => emit(Add(1)),
    update=(emit, msg, model) => {
      match msg {
        Add(n) => (emit(Add(n)), model + n)
        _ => (@rabbita_tui.Cmd::none(), model)
      }
    },
    view=model => @rabbita_tui.text(model.to_string()),
  )
  let result = program.run_headless(
    options=@rabbita_tui.HeadlessOptions::default().render(false).max_steps(3),
  )
  @debug.assert_eq(result.model, 3)
  @debug.assert_eq(result.steps, 3)
  @debug.assert_eq(result.limit_reached, true)
  @debug.assert_eq(result.frames.length(), 0)
}

///|
test "cell with emit returns a usable emit and program" {
  let (emit, program) = @rabbita_tui.cell_with_emit(
    model=1,
    update=(_emit, msg, model) => {
      match msg {
        Add(n) => (@rabbita_tui.Cmd::none(), model + n)
        _ => (@rabbita_tui.Cmd::none(), model)
      }
    },
    view=model => @rabbita_tui.text(model.to_string()),
  )
  emit.send(Add(1))
  ignore(program.step(emit, Add(2)))
  @debug.assert_eq(program.model(), 4)
}
