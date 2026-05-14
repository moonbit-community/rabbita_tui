///|
using @tui {type HeadlessOptions}

///|
fn scripted_snapshot() -> String {
  let demo = app()
  let emit = Emit::new(_ => ())
  ignore(demo.step(emit, Resize({ width: 80, height: 22 })))
  ignore(demo.step(emit, KeyPressed(Char("p"))))
  ignore(
    demo.step(emit, KeyPressed(Modified(Up, KeyModifiers::none().shift(true)))),
  )
  Frame::from_node(demo.view(), { width: 80, height: 22 }).to_string()
}

///|
test "runtime lab snapshot teaches core controls" {
  let snapshot = scripted_snapshot()
  assert_true(snapshot.contains("Cmd::log/err_log"))
  assert_true(snapshot.contains("shift+up"))
}

///|
async test "runtime lab headless commands cover suspend exec and timeout" {
  let result = app().run_headless(
    events=[Key(Char("s")), Key(Char("x")), Key(Char("t"))],
    options=HeadlessOptions::default().size({ width: 82, height: 22 }),
  )
  let events = join(result.model.events.to_array(), " ")
  assert_true(events.contains("suspend returned"))
  assert_true(events.contains("exec process exit 0"))
  assert_true(events.contains("timed out"))
  assert_true(
    result.terminal_commands.contains(
      PrintLine("external command exited with 0"),
    ),
  )
}
