///|
using @tui {render_plain}

///|
test "text input editing and cursor movement" {
  let empty = TextInput(placeholder="ask")
  let input1 = empty.update(TextInputKey(Char("abc")))
  let input2 = input1.update(TextInputKey(Left))
  let input3 = input2.update(TextInputKey(Char("X")))
  let input4 = input3.update(TextInputKey(Backspace))
  let input = input4.update(TextInputKey(Delete))
  @debug.assert_eq(input.value, "ab")
  @debug.assert_eq(input.cursor, 2)
  @debug.assert_eq(render_plain(input.view(width=5), { width: 5, height: 1 }), [
    "ab█  ",
  ])
  @debug.assert_eq(empty.update(TextInputKey(Backspace)).value, "")
  @debug.assert_eq(empty.update(TextInputKey(Delete)).value, "")
  @debug.assert_eq(TextInput(value="xy").update(TextInputKey(Right)).cursor, 2)
  @debug.assert_eq(
    empty
    .update(TextInputKey(Char("a")))
    .update(TextInputKey(Left))
    .update(TextInputKey(Delete)).value,
    "",
  )
  let wide = TextInput(value="ab你cd")
    .update(TextInputKey(Left))
    .update(TextInputKey(Left))
    .update(TextInputKey(Backspace))
  @debug.assert_eq(wide.value, "abcd")
  @debug.assert_eq(wide.cursor, 2)
  @debug.assert_eq(
    render_plain(TextInput(value="abcdef").view(width=4), {
      width: 4,
      height: 1,
    }),
    ["def█"],
  )
}

///|
test "textarea edits multiple lines and renders cursor" {
  let empty = Textarea(placeholder="message")
  let area1 = empty.update(TextareaKey(Char("hello")))
  let area2 = area1.update(TextareaKey(Enter))
  let area3 = area2.update(TextareaKey(Char("world")))
  let area4 = area3.update(TextareaKey(Up))
  let area5 = area4.update(TextareaKey(End))
  let area = area5.update(TextareaKey(Char("!")))
  @debug.assert_eq(area.value(), "hello!\nworld")
  @debug.assert_eq(area.row, 0)
  @debug.assert_eq(area.column, 6)
  @debug.assert_eq(
    render_plain(area.view(size={ width: 8, height: 3 }), {
      width: 8,
      height: 3,
    }),
    ["hello!█ ", "world   ", "        "],
  )
  @debug.assert_eq(
    Textarea(placeholder="message", value="a\nb")
    .update(TextareaKey(Backspace))
    .value(),
    "a\n",
  )
  @debug.assert_eq(
    Textarea(placeholder="message", value="a\nb")
    .update(TextareaKey(Home))
    .update(TextareaKey(Backspace))
    .value(),
    "ab",
  )
  @debug.assert_eq(
    render_plain(empty.view(size={ width: 10, height: 2 }), {
      width: 10,
      height: 2,
    }),
    ["█message  ", "          "],
  )
  @debug.assert_eq(
    render_plain(
      Textarea(value="one\ntwo\nthree").view(size={ width: 7, height: 2 }),
      { width: 7, height: 2 },
    ),
    ["two    ", "three█ "],
  )
}

///|
test "list view marks selected item" {
  let base = List(items=["one", "two", "three"])
  let state = base.update(ListMove(1, 0))
  @debug.assert_eq(
    render_plain(state.view(size={ width: 8, height: 3 }), {
      width: 8,
      height: 3,
    }),
    ["  one   ", "> two   ", "  three "],
  )
  @debug.assert_eq(List(items=[]).update(ListMove(1, 0)).items, [])
  @debug.assert_eq(state.update(ListMove(-1, 0)).selected, 0)
  @debug.assert_eq(state.selected_item(), Some("two"))
  @debug.assert_eq(
    List(items=["a", "b", "c", "d"]).update(ListMove(3, 2)).offset,
    2,
  )
}

///|
test "table renders headers rows and selection" {
  @debug.assert_eq(
    render_plain(
      table(
        columns=[{ title: "Name", width: 4 }, { title: "State", width: 5 }],
        rows=[["job1", "done"], ["job2", "run"], ["job3", "wait"]],
        selected=1,
        size={ width: 14, height: 4 },
      ),
      { width: 14, height: 4 },
    ),
    ["Name State    ", "--------------", "  job1 done   ", "> job2 run    "],
  )
}

///|
test "viewport scroll clamps to available lines" {
  let viewport_model = Viewport(lines=["a", "b", "c", "d"]).update(
    ViewportScroll(10, 2),
  )
  @debug.assert_eq(viewport_model.offset, 2)
  @debug.assert_eq(
    render_plain(viewport_model.view(size={ width: 3, height: 2 }), {
      width: 3,
      height: 2,
    }),
    ["c  ", "d  "],
  )
}

///|
test "paginator progress timer keymap tabs and modal render" {
  @debug.assert_eq(
    render_plain(paginator(page=4, per_page=10, total_items=21, width=10), {
      width: 10,
      height: 1,
    }),
    ["Page 3/3  "],
  )
  @debug.assert_eq(
    render_plain(progress(current=5, total=10, width=12), {
      width: 12,
      height: 1,
    }),
    ["███░░░ 50%  "],
  )
  @debug.assert_eq(
    render_plain(timer(remaining_ms=1600, width=4), { width: 4, height: 1 }),
    ["2s  "],
  )
  let bindings : Array[KeyBinding] = [
    { keys: [Ctrl("c"), Char("q")], help: "quit" },
    { keys: [Enter], help: "send" },
  ]
  @debug.assert_eq(
    render_plain(keymap(bindings~, width=30), { width: 30, height: 1 }),
    ["ctrl+c/q quit  enter send     "],
  )
  @debug.assert_eq(
    render_plain(tabs(labels=["Chat", "Diff", "Log"], active=1, width=20), {
      width: 20,
      height: 1,
    }),
    [" Chat  [Diff]  Log  "],
  )
  let dialog = modal(title="Title", size={ width: 8, height: 4 }) <| [
    text("Body"),
  ]
  @debug.assert_eq(render_plain(dialog, { width: 8, height: 4 }), [
    "╭──────╮", "│Title │", "│Body  │", "╰──────╯",
  ])
}

///|
test "command palette filters and selects commands" {
  let palette = CommandPalette(items=["open file", "run tests", "close"]).update(
    CommandPaletteKey(Char("run")),
  )
  @debug.assert_eq(palette.items(), ["run tests"])
  @debug.assert_eq(palette.selected_item(), Some("run tests"))
  @debug.assert_eq(
    render_plain(palette.view(size={ width: 14, height: 4 }), {
      width: 14,
      height: 4,
    }),
    [
      "╭────────────╮", "│run█        │", "│> run tests │",
      "╰────────────╯",
    ],
  )
}

///|
test "status line aligns right side" {
  @debug.assert_eq(
    render_plain(status_line(left="left", right="right", width=12), {
      width: 12,
      height: 1,
    }),
    ["left   right"],
  )
  @debug.assert_eq(
    render_plain(status_line(left="very long", right="right", width=8), {
      width: 8,
      height: 1,
    }),
    ["very lon"],
  )
}

///|
test "spinner cycles frames" {
  @debug.assert_eq(render_plain(spinner(0), { width: 1, height: 1 }), ["-"])
  @debug.assert_eq(render_plain(spinner(3), { width: 1, height: 1 }), ["/"])
  @debug.assert_eq(render_plain(spinner(4), { width: 1, height: 1 }), ["-"])
}
