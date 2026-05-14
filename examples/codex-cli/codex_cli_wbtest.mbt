///|
using @tui {
  ansi_start_program,
  render_ansi,
  type Event,
  type MouseAction,
  type MouseButton,
}

///|
fn test_emit(log : Array[CodexMsg]) -> Emit[CodexMsg] {
  Emit::new(msg => log.push(msg))
}

///|
fn emit_stub() -> Emit[CodexMsg] {
  Emit::new(_ => ())
}

///|
async fn drain_cmd(
  app : Cell[CodexModel, CodexMsg],
  emit : Emit[CodexMsg],
  log : Array[CodexMsg],
  cmd : Cmd,
) -> Unit {
  let mut cursor = log.length()
  cmd.run()
  while cursor < log.length() {
    let msg = log[cursor]
    cursor += 1
    let next = app.step(emit, msg)
    next.run()
  }
}

///|
async fn scripted_snapshot() -> String {
  let app = demo_app()
  let log : Array[CodexMsg] = []
  let emit = test_emit(log)
  ignore(app.step(emit, Resize({ width: 64, height: 24 })))
  ignore(app.step(emit, KeyPressed(Char("h"))))
  ignore(app.step(emit, KeyPressed(Char("i"))))
  drain_cmd(app, emit, log, app.step(emit, KeyPressed(Enter)))
  Frame::from_node(app.view(), { width: 64, height: 24 }).to_string()
}

///|
async test "scripted codex cli snapshot contains streaming result" {
  let snapshot = scripted_snapshot()
  assert_true(snapshot.contains("codex"))
  assert_true(snapshot.contains("you    hi"))
  assert_true(snapshot.contains("codex  I will inspect"))
  assert_true(snapshot.contains("enter submit"))
}

///|
async test "codex cli layout fits common terminal widths and scrolls to latest content" {
  for width in [40, 64, 80, 120] {
    let model = resized_scripted_model(width, 18)
    let frame = Frame::from_node(view(model), { width, height: 18 })
    @debug.assert_eq(frame.lines.length(), 18)
    for line in frame.lines {
      assert_true(display_width(line) <= width)
    }
    let text = frame.to_string()
    assert_true(text.contains("codex"))
    assert_true(text.contains("enter"))
    assert_true(text.contains("result."))
  }
  let long = model_with_many_entries(40, 14)
  let snapshot = Frame::from_node(view(long), { width: 40, height: 14 }).to_string()
  assert_true(snapshot.contains("latest visible line"))
  assert_true(!snapshot.contains("old hidden line 0"))
}

///|
async test "codex cli view keeps a stable repaint height" {
  let log : Array[CodexMsg] = []
  let emit = test_emit(log)
  let model = initial_model()
  let frame = Frame::from_node(view(model), { width: 80, height: 24 })
  @debug.assert_eq(frame.lines.length(), live_height(model))
  let (_, typed) = update(emit, KeyPressed(Char("x")), model)
  let typed_frame = Frame::from_node(view(typed), { width: 80, height: 24 })
  @debug.assert_eq(typed_frame.lines.length(), live_height(typed))
  let (cmd, submitted) = update(emit, KeyPressed(Enter), typed)
  cmd.run()
  @debug.assert_eq(log, [StreamChunk])
  let submitted_frame = Frame::from_node(view(submitted), {
    width: 80,
    height: 24,
  })
  @debug.assert_eq(submitted_frame.lines.length(), live_height(submitted))
  let (_, streamed) = update(emit, StreamChunk, submitted)
  let streamed_frame = Frame::from_node(view(streamed), {
    width: 80,
    height: 24,
  })
  @debug.assert_eq(streamed_frame.lines.length(), live_height(streamed))
}

///|
test "codex cli transcript scroll helpers clamp page keys and wheel events" {
  let emit = emit_stub()
  let long = model_with_many_entries(40, 14)
  let (_, page_up) = update(emit, KeyPressed(PageUp), long)
  assert_true(page_up.scroll_offset > 0)
  let page_snapshot = Frame::from_node(view(page_up), { width: 40, height: 14 }).to_string()
  assert_true(page_snapshot.contains("scroll"))
  assert_true(!page_snapshot.contains("latest visible line"))
  let (_, wheel_up) = update(
    emit,
    MouseSeen({ button: WheelUp, action: Press, x: 2, y: 6 }),
    page_up,
  )
  assert_true(wheel_up.scroll_offset > page_up.scroll_offset)
  let (_, page_down) = update(emit, KeyPressed(PageDown), wheel_up)
  assert_true(page_down.scroll_offset < wheel_up.scroll_offset)
  let (_, bottom) = update(
    emit,
    MouseSeen({ button: WheelDown, action: Press, x: 2, y: 6 }),
    { ..page_down, scroll_offset: 1 },
  )
  @debug.assert_eq(bottom.scroll_offset, 0)
}

///|
test "codex cli keeps manual scroll position while streaming" {
  let emit = emit_stub()
  let base = model_with_many_entries(44, 18)
  let (_, page_up) = update(emit, KeyPressed(PageUp), base)
  assert_true(page_up.scroll_offset > 0)
  let streaming = {
    ..page_up,
    transcript: page_up.transcript.push({ role: Assistant, text: "" }),
    streaming: true,
    stream_index: 0,
  }
  let (_, next) = update(emit, StreamChunk, streaming)
  assert_true(next.scroll_offset >= page_up.scroll_offset)
}

///|
test "codex cli transcript scroll clamps across resize" {
  let emit = emit_stub()
  let long = { ..model_with_many_entries(44, 12), scroll_offset: 1000 }
  let clamped = clamp_scroll(long)
  @debug.assert_eq(clamped.scroll_offset, max_scroll_offset(clamped))
  let (_, resized) = update(emit, Resize({ width: 44, height: 28 }), clamped)
  assert_true(resized.scroll_offset <= max_scroll_offset(resized))
}

///|
test "codex cli menus and ansi output show foreground and background styling" {
  let emit = emit_stub()
  let app = demo_app()
  ignore(app.step(emit, Resize({ width: 80, height: 18 })))
  ignore(app.step(emit, KeyPressed(Tab)))
  let frame = Frame::from_node(app.view(), { width: 80, height: 18 })
  assert_true(frame.to_string().contains("[plan]"))
  let output = ansi_start_program(ProgramOptions::inline(), app.view(), {
    width: 80,
    height: 18,
  })
  let chat_output = ansi_start_program(
    ProgramOptions::inline(),
    view({ ..initial_model(), width: 80, height: 18 }),
    { width: 80, height: 18 },
  )
  let streaming_output = render_ansi(
    activity_view({ ..initial_model(), streaming: true, stream_index: 2 }, 80),
    { width: 80, height: 1 },
  )
  assert_true(output.contains("48;5;250"))
  assert_true(streaming_output.contains("48;5;153"))
  assert_true(chat_output.contains("92m"))
  assert_true(chat_output.contains("91m"))
  assert_true(output.contains("1;"))
  assert_true(output.contains("\u{1b}[K\u{1b}[0m"))
}

///|
test "codex cli diff stays inside the chat viewport" {
  let model = initial_model()
  for width in [32, 48, 80] {
    let lines = pane_lines({ ..model, width, }, content_width(width))
    let limit = content_width(width)
    let mut saw_diff = false
    for line in lines {
      assert_true(display_width(line.text) <= limit)
      if line.text.contains("diff --git") ||
        line.text.contains("task.with_status") {
        saw_diff = true
      }
    }
    assert_true(saw_diff)
  }
}

///|
test "codex cli clips narrow diff lines instead of wrapping code tokens" {
  let lines = pane_lines({ ..initial_model(), width: 60 }, content_width(60))
  let mut hunk_lines = 0
  for line in lines {
    if line.text.contains("@@ -7") {
      hunk_lines += 1
    }
    assert_true(!line.text.contains("ing {"))
  }
  @debug.assert_eq(hunk_lines, 1)
}

///|
test "codex cli composer does not paint a black half-background" {
  let output = render_ansi(composer_view(initial_model(), 48), {
    width: 48,
    height: 4,
  })
  assert_true(!output.contains("40m"))
}

///|
test "cancel stops streaming" {
  let model = { ..initial_model(), streaming: true, status: "streaming" }
  let (_, next) = update(emit_stub(), KeyPressed(Escape), model)
  @debug.assert_eq(next.streaming, false)
  @debug.assert_eq(next.status, "cancelled")
}

///|
test "event handling edits prompt submits cancels and resizes" {
  let emit = emit_stub()
  let (_, model1) = update(emit, KeyPressed(Char("a")), initial_model())
  let (_, model2) = update(emit, KeyPressed(Char("b")), model1)
  let (_, model3) = update(emit, KeyPressed(Left), model2)
  let (_, model4) = update(emit, KeyPressed(Delete), model3)
  @debug.assert_eq(model4.prompt.value(), "a")
  let (_, model5) = update(emit, KeyPressed(Backspace), model4)
  @debug.assert_eq(model5.prompt.value(), "")
  let (_, model6) = update(emit, KeyPressed(Right), model5)
  @debug.assert_eq(model6.prompt.column, 0)
  let (empty_submit, model7) = update(emit, KeyPressed(Enter), model6)
  @debug.assert_eq(empty_submit.is_none(), true)
  @debug.assert_eq(model7.streaming, false)
  let (_, resized) = update(emit, Resize({ width: 40, height: 12 }), model7)
  @debug.assert_eq((resized.width, resized.height), (40, 12))
  let (_, unchanged) = update(
    emit,
    MouseSeen({ button: Primary, action: Release, x: 1, y: 1 }),
    resized,
  )
  @debug.assert_eq(unchanged, resized)
  let (_, cancelled) = update(emit, KeyPressed(Escape), {
    ..resized,
    streaming: true,
  })
  @debug.assert_eq(cancelled.status, "cancelled")
}

///|
test "prompt history recalls entries and restores the draft" {
  let emit = emit_stub()
  let base = initial_model()
  let model = {
    ..base,
    prompt: base.prompt.update(TextareaSet("draft")),
    draft_prompt: "draft",
    history: Vector::from_array(["first task", "second task"]),
  }
  let (_, recalled_latest) = update(emit, KeyPressed(Up), model)
  @debug.assert_eq(recalled_latest.prompt.value(), "second task")
  @debug.assert_eq(recalled_latest.history_index, 1)
  let (_, recalled_older) = update(emit, KeyPressed(Up), recalled_latest)
  @debug.assert_eq(recalled_older.prompt.value(), "first task")
  @debug.assert_eq(recalled_older.history_index, 0)
  let (_, recalled_newer) = update(emit, KeyPressed(Down), recalled_older)
  @debug.assert_eq(recalled_newer.prompt.value(), "second task")
  let (_, restored_draft) = update(emit, KeyPressed(Down), recalled_newer)
  @debug.assert_eq(restored_draft.prompt.value(), "draft")
  @debug.assert_eq(restored_draft.history_index, -1)
  let (_, edited) = update(emit, KeyPressed(Char("!")), recalled_latest)
  @debug.assert_eq(edited.prompt.value(), "second task!")
  @debug.assert_eq(edited.draft_prompt, "second task!")
  @debug.assert_eq(edited.history_index, -1)
}

///|
async fn resized_scripted_model(width : Int, height : Int) -> CodexModel {
  let log : Array[CodexMsg] = []
  let emit = test_emit(log)
  let app = demo_app()
  ignore(app.step(emit, Resize({ width, height })))
  for char in "please inspect the repository and fix failing tests" {
    ignore(app.step(emit, KeyPressed(Char(char.to_string()))))
  }
  drain_cmd(app, emit, log, app.step(emit, KeyPressed(Enter)))
  app.model()
}

///|
fn model_with_many_entries(width : Int, height : Int) -> CodexModel {
  let mut transcript = Vector::new()
  for index in 0..<16 {
    transcript = transcript.push({
      role: Assistant,
      text: "old hidden line \{index}",
    })
  }
  transcript = transcript.push({ role: Assistant, text: "latest visible line" })
  { ..initial_model(), transcript, width, height }
}

///|
async test "submit and stream guard branches are deterministic" {
  let log : Array[CodexMsg] = []
  let emit = test_emit(log)
  let base = initial_model()
  let ready = { ..base, prompt: base.prompt.update(TextareaSet("run tests")) }
  let (cmd, submitted) = update(emit, KeyPressed(Enter), ready)
  cmd.run()
  @debug.assert_eq(log, [StreamChunk])
  @debug.assert_eq(submitted.streaming, true)
  let (blocked, blocked_model) = update(emit, KeyPressed(Enter), submitted)
  @debug.assert_eq(blocked.is_none(), true)
  @debug.assert_eq(blocked_model, submitted)
  let (_, done) = update(emit, StreamChunk, initial_model())
  @debug.assert_eq(done.status, "done")
}

///|
test "subscriptions map terminal events to codex messages" {
  let sub = subscriptions(initial_model())
  @debug.assert_eq(sub.map_event(Key(Char("x"))), [KeyPressed(Char("x"))])
  let wheel = Event::Mouse({
    button: MouseButton::WheelUp,
    action: MouseAction::Press,
    x: 1,
    y: 1,
  })
  @debug.assert_eq(sub.map_event(wheel), [
    MouseSeen({
      button: MouseButton::WheelUp,
      action: MouseAction::Press,
      x: 1,
      y: 1,
    }),
  ])
  @debug.assert_eq(sub.map_event(Resize({ width: 10, height: 5 })), [
    Resize({ width: 10, height: 5 }),
  ])
}
