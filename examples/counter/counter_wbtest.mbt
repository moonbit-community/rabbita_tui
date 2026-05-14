///|
using @tui {display_width}

///|
fn emit_stub() -> Emit[CounterMsg] {
  Emit::new(_ => ())
}

///|
test "counter updates count step and reset from keys" {
  let emit = emit_stub()
  let (_, inc) = update(emit, KeyPressed(Up), initial_model())
  @debug.assert_eq(inc.count, 1)
  let (_, stepped) = update(emit, KeyPressed(Char("]")), inc)
  @debug.assert_eq(stepped.step, 2)
  let (_, more) = update(emit, KeyPressed(Char("+")), stepped)
  @debug.assert_eq(more.count, 3)
  let (_, down) = update(emit, KeyPressed(Down), more)
  @debug.assert_eq(down.count, 1)
  let (_, reset) = update(emit, KeyPressed(Char("r")), down)
  @debug.assert_eq(reset.count, 0)
  @debug.assert_eq(reset.step, 1)
}

///|
test "counter subscriptions map keys and resize directly" {
  let sub = subscriptions(initial_model())
  @debug.assert_eq(sub.map_event(Key(Char("+"))), [KeyPressed(Char("+"))])
  @debug.assert_eq(sub.map_event(Resize({ width: 90, height: 22 })), [
    Resize({ width: 90, height: 22 }),
  ])
  @debug.assert_eq(sub.map_event(FocusGained), [])
}

///|
test "counter layout fits common terminal sizes" {
  let sizes : Array[Size] = [
    { width: 36, height: 12 },
    { width: 72, height: 18 },
    { width: 100, height: 24 },
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
test "counter snapshot includes controls and current state" {
  let (_, model) = update(emit_stub(), KeyPressed(Char("+")), initial_model())
  let snapshot = Frame::from_node(view(model), { width: 72, height: 18 }).to_string()
  assert_true(snapshot.contains("Counter"))
  assert_true(snapshot.contains("step 1"))
  assert_true(snapshot.contains("increment"))
}
