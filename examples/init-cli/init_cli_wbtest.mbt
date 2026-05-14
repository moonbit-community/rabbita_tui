///|
using @tui {display_width}

///|
fn emit_stub() -> Emit[InitMsg] {
  Emit::new(_ => ())
}

///|
fn scripted_snapshot() -> String {
  let app = demo_app()
  let emit = emit_stub()
  ignore(app.step(emit, Resize({ width: 80, height: 24 })))
  for char in "orbit" {
    ignore(app.step(emit, KeyPressed(Char(char.to_string()))))
  }
  ignore(app.step(emit, KeyPressed(Enter)))
  ignore(app.step(emit, KeyPressed(Down)))
  ignore(app.step(emit, KeyPressed(Enter)))
  ignore(app.step(emit, KeyPressed(Enter)))
  ignore(app.step(emit, KeyPressed(Down)))
  ignore(app.step(emit, KeyPressed(Char(" "))))
  ignore(app.step(emit, KeyPressed(Enter)))
  for char in "Ada" {
    ignore(app.step(emit, KeyPressed(Char(char.to_string()))))
  }
  ignore(app.step(emit, KeyPressed(Enter)))
  ignore(app.step(emit, KeyPressed(Enter)))
  ignore(app.step(emit, KeyPressed(Enter)))
  for _ in generation_tasks() {
    ignore(app.step(emit, GenerateTick))
  }
  Frame::from_node(app.view(), { width: 80, height: 24 }).to_string()
}

///|
test "scripted project initializer reaches ready summary" {
  let snapshot = scripted_snapshot()
  assert_true(snapshot.contains("Project ready"))
  assert_true(snapshot.contains("orbit"))
  assert_true(snapshot.contains("cd orbit && moon test"))
}

///|
test "initializer layout fills common terminal sizes" {
  let sizes : Array[Size] = [
    { width: 48, height: 18 },
    { width: 80, height: 24 },
    { width: 110, height: 30 },
  ]
  for size in sizes {
    let model = { ..initial_model(), width: size.width, height: size.height }
    let frame = Frame::from_node(view(model), size)
    @debug.assert_eq(frame.lines.length(), size.height)
    for line in frame.lines {
      assert_true(display_width(line) <= size.width)
    }
  }
}

///|
test "initializer validates name and moves through selections" {
  let emit = emit_stub()
  let (_, invalid) = update(emit, KeyPressed(Enter), initial_model())
  @debug.assert_eq(invalid.step, Name)
  assert_true(invalid.status.contains("required"))
  let (_, typed) = update(emit, KeyPressed(Char("x")), invalid)
  let (_, templating) = update(emit, KeyPressed(Enter), typed)
  @debug.assert_eq(templating.step, Template)
  let (_, selected) = update(emit, KeyPressed(Down), templating)
  @debug.assert_eq(selected.template.selected, 1)
}

///|
test "initializer toggles features and generates to done" {
  let emit = emit_stub()
  let model = { ..initial_model(), step: Features, feature_cursor: 2 }
  let (_, toggled) = update(emit, KeyPressed(Char(" ")), model)
  @debug.assert_eq(toggled.features[2], true)
  let confirm = { ..toggled, step: Confirm }
  let (cmd, generating) = update(emit, KeyPressed(Enter), confirm)
  assert_true(cmd.terminal_commands().is_empty())
  @debug.assert_eq(generating.step, Generating)
  let mut current = generating
  for _ in generation_tasks() {
    let (_, next) = update(emit, GenerateTick, current)
    current = next
  }
  @debug.assert_eq(current.step, Done)
}

///|
test "initializer reset preserves terminal size" {
  let model = { ..initial_model(), step: Done, width: 96, height: 26 }
  let reset = reset_model(model)
  @debug.assert_eq(reset.step, Name)
  @debug.assert_eq(reset.width, 96)
  @debug.assert_eq(reset.height, 26)
}

///|
test "initializer subscriptions map only meaningful runtime events" {
  let sub = subscriptions(initial_model())
  @debug.assert_eq(sub.map_event(Key(Char("a"))), [KeyPressed(Char("a"))])
  @debug.assert_eq(sub.map_event(Paste("name")), [Pasted("name")])
  @debug.assert_eq(sub.map_event(FocusGained), [])
  @debug.assert_eq(sub.map_event(Resize({ width: 90, height: 22 })), [
    Resize({ width: 90, height: 22 }),
  ])
}
