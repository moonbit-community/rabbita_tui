///|
test "plain renderer stacks pads borders and clips" {
  let node = border(
    kind=Square,
    pad(
      edge=Edge::xy(1, 0),
      vstack(gap=1) <| [
        text("hello"),
        text("world"),
      ],
    ),
  )
  @debug.assert_eq(render_plain(node, { width: 9, height: 5 }), [
    "+-------+", "| hello |", "|       |", "| world |", "+-------+",
  ])
}

///|
test "plain renderer covers empty fragment style fill and rounded border" {
  @debug.assert_eq(render_plain(empty(), { width: 3, height: 2 }), [])
  @debug.assert_eq(
    render_plain(
      fragment <| [
        text("a"),
        text(style=Style::default().dim(), "b"),
      ],
      { width: 2, height: 3 },
    ),
    ["a ", "b "],
  )
  @debug.assert_eq(
    render_plain(fill(style=Style::default(), "."), { width: 4, height: 2 }),
    ["....", "...."],
  )
  @debug.assert_eq(render_plain(border(text("x")), { width: 5, height: 3 }), [
    "╭───╮", "│x  │", "╰───╯",
  ])
  @debug.assert_eq(
    render_plain(border(kind=NoBorder, text("x")), { width: 2, height: 1 }),
    ["x "],
  )
  @debug.assert_eq(
    render_plain(border(kind=Normal, text("x")), { width: 5, height: 3 }),
    ["┌───┐", "│x  │", "└───┘"],
  )
  @debug.assert_eq(
    render_plain(border(kind=Double, text("x")), { width: 5, height: 3 }),
    ["╔═══╗", "║x  ║", "╚═══╝"],
  )
  @debug.assert_eq(
    render_plain(border(kind=Thick, text("x")), { width: 5, height: 3 }),
    ["┏━━━┓", "┃x  ┃", "┗━━━┛"],
  )
}

///|
test "horizontal stack distributes width" {
  let node = hstack(gap=1) <| [
      text("left"),
      text("right"),
    ]
  @debug.assert_eq(render_plain(node, { width: 11, height: 1 }), ["left  right"])
  @debug.assert_eq(render_plain(hstack <| [], { width: 4, height: 1 }), [])
  @debug.assert_eq(
    render_plain(
      hstack(gap=1) <| [
        text("a"),
        text("b\nc"),
      ],
      { width: 5, height: 2 },
    ),
    ["a  b ", "   c "],
  )
}

///|
test "wide characters are measured and clipped by display width" {
  @debug.assert_eq(display_width("a你b"), 4)
  @debug.assert_eq(take_width("a你b", 3), "a你")
  @debug.assert_eq(fit_line("a你b", 3), "a你")
  @debug.assert_eq(fit_line("abc", 0), "")
  @debug.assert_eq(repeat_to_width("", 3), "")
  @debug.assert_eq(repeat_to_width("x", 0), "")
  @debug.assert_eq(align_line("x", 5, Start), "x    ")
  @debug.assert_eq(align_line("x", 5, Center), "  x  ")
  @debug.assert_eq(align_line("x", 5, End), "    x")
  @debug.assert_eq(wrap_text("abcdef", 2), ["ab", "cd", "ef"])
  @debug.assert_eq(wrap_text("a你b", 3), ["a你", "b"])
  @debug.assert_eq(wrap_text("a\nb", 4), ["a", "b"])
  @debug.assert_eq(wrap_text("hello world", 8), ["hello", "world"])
  @debug.assert_eq(wrap_text("hello world", 20), ["hello world"])
}

///|
test "layout supports sizing alignment placement and edge constructors" {
  @debug.assert_eq(Edge::zero(), Edge::all(0))
  @debug.assert_eq(Edge::horizontal(2), { top: 0, right: 2, bottom: 0, left: 2 })
  @debug.assert_eq(Edge::vertical(1), { top: 1, right: 0, bottom: 1, left: 0 })
  @debug.assert_eq(Edge::trbl(1, 2, 3, 4), {
    top: 1,
    right: 2,
    bottom: 3,
    left: 4,
  })
  @debug.assert_eq(
    render_plain(sized(width=3, height=2, text("hello")), {
      width: 8,
      height: 3,
    }),
    ["hel     ", "        "],
  )
  @debug.assert_eq(
    render_plain(sized(width=4, text("hi")), { width: 8, height: 1 }),
    ["hi      "],
  )
  @debug.assert_eq(
    render_plain(sized(height=3, text("hi")), { width: 4, height: 4 }),
    ["hi  ", "    ", "    "],
  )
  @debug.assert_eq(fit_block(["x"], { width: 3, height: 2 }), ["x  ", "   "])
  @debug.assert_eq(
    render_plain(align(horizontal=End, vertical=End, text("x")), {
      width: 4,
      height: 3,
    }),
    ["    ", "    ", "   x"],
  )
  @debug.assert_eq(
    render_plain(place(size={ width: 5, height: 3 }, text("x")), {
      width: 8,
      height: 4,
    }),
    ["        ", "  x     ", "        "],
  )
  @debug.assert_eq(
    render_plain(
      join_horizontal(gap=1) <| [
        text("a"),
        text("b"),
      ],
      { width: 5, height: 1 },
    ),
    ["a  b "],
  )
  @debug.assert_eq(
    render_plain(
      join_vertical(gap=1) <| [
        text("a"),
        text("b"),
      ],
      { width: 2, height: 3 },
    ),
    ["a ", "  ", "b "],
  )
}

///|
test "style layout composes size padding and border" {
  let node = vstack(
      style=Style::default()
        .size(width=9, height=5)
        .padding(Edge::all(1))
        .border(kind=Square),
    ) <| [
      text("x"),
    ]
  @debug.assert_eq(render_plain(node, { width: 9, height: 5 }), [
    "+-------+", "|       |", "| x     |", "|       |", "+-------+",
  ])
  @debug.assert_eq(
    render_plain(
      text(
        style=Style::default().size(width=5, height=3).border(kind=Square),
        "x",
      ),
      { width: 5, height: 3 },
    ),
    ["+---+", "|x  |", "+---+"],
  )
}

///|
test "styles merge and ansi style emits compact sgr" {
  let style = Style::default()
    .fg(Ansi(2))
    .bg(Rgb(10, 20, 30))
    .bold()
    .underline()
  let merged = Style::default().fg(Ansi(1)).merge(style)
  @debug.assert_eq(merged.fg, Ansi(2))
  assert_true(ansi_style(merged).contains("1;4;32;48;2;10;20;30"))
  @debug.assert_eq(ansi_style(Style::default()), "")
  assert_true(
    ansi_style(
      Style::default().dim().italic().blink().reverse().strikethrough(),
    ).contains("2;3;5;7;9"),
  )
  assert_true(ansi_style(Style::default().fg(Ansi(9))).contains("91"))
  assert_true(ansi_style(Style::default().fg(Ansi(200))).contains("38;5;200"))
  @debug.assert_eq(ansi_reset(), "\u{1b}[0m")
  @debug.assert_eq(ansi_leave_alternate_screen(), "\u{1b}[?1049l")
  @debug.assert_eq(ansi_show_cursor(), "\u{1b}[?25h")
  let rendered = render_ansi(
    text(style=Style::default().fg(Ansi(1)).bold(), "ok"),
    { width: 3, height: 1 },
  )
  assert_true(rendered.has_prefix("\u{1b}[1;31m"))
  assert_true(rendered.contains(ansi_reset()))
  let container = render_ansi(
    vstack(style=Style::default().fg(Ansi(2)).bold()) <| [
      text("ok"),
    ],
    { width: 3, height: 1 },
  )
  assert_true(container.has_prefix("\u{1b}[1;32m"))
  let with_bg = ansi_start_program(
    ProgramOptions::inline(),
    text(style=Style::default().fg(Ansi(15)).bg(Ansi(4)), fit_line("bg", 8)),
    { width: 8, height: 1 },
  )
  assert_true(with_bg.contains("97;44m"))
  assert_true(with_bg.contains("\u{1b}[K\u{1b}[0m"))
}

///|
test "frame diff only rewrites changed lines" {
  let prev : Frame = { lines: ["a", "b", "long"] }
  let next : Frame = { lines: ["a", "B", "lo"] }
  let diff = diff_ansi(Some(prev), next)
  assert_true(diff.contains("\u{1b}[2;1HB"))
  assert_true(diff.contains("\u{1b}[3;1Hlo\u{1b}[K"))
  assert_true(!diff.contains("\u{1b}[1;1H"))
  assert_true(diff_ansi(None, next).has_prefix("\u{1b}[1;1H"))
  let (_, styled_diff) = diff_node_ansi(
    Some(Frame::from_node(text("same"), { width: 6, height: 1 })),
    text(style=Style::default().fg(Ansi(1)), "same"),
    { width: 6, height: 1 },
  )
  assert_true(styled_diff.contains("\u{1b}[31m"))
}

///|
test "full render enters alternate screen and hides cursor" {
  let output = full_render_ansi(text("hi"), { width: 4, height: 1 })
  assert_true(output.has_prefix(ansi_enter_alternate_screen()))
  assert_true(output.contains(ansi_hide_cursor()))
  assert_true(output.contains("hi\u{1b}[K"))
}

///|
test "terminal ansi options and commands cover program modes" {
  let options = ProgramOptions::default()
    .mouse(MouseButtonMotion)
    .bracketed_paste(true)
    .focus_events(true)
  let output = ansi_start_program(options, text("hi"), { width: 4, height: 1 })
  assert_true(output.contains(ansi_enter_alternate_screen()))
  assert_true(output.contains(ansi_enable_mouse(MouseButtonMotion)))
  assert_true(output.contains(ansi_enable_bracketed_paste()))
  assert_true(output.contains(ansi_enable_focus_events()))
  let cleanup = ansi_stop_program(options)
  assert_true(cleanup.contains(ansi_disable_focus_events()))
  assert_true(cleanup.contains(ansi_disable_bracketed_paste()))
  assert_true(cleanup.contains(ansi_disable_mouse()))
  assert_true(cleanup.contains(ansi_leave_alternate_screen()))
  let inline = ProgramOptions::inline().mouse(MouseButtonMotion)
  assert_true(
    ansi_start_program(inline, text("hi"), { width: 4, height: 1 }).contains(
      ansi_enable_mouse(MouseButtonMotion),
    ),
  )
  @debug.assert_eq(
    ansi_terminal_command(SetWindowTitle("demo")),
    "\u{1b}]0;demo\u{07}",
  )
  assert_true(ansi_terminal_command(ClearScreen).contains(ansi_clear_screen()))
  @debug.assert_eq(
    ansi_terminal_command(EnableMouse(MouseOff)),
    ansi_disable_mouse(),
  )
  @debug.assert_eq(ansi_terminal_command(QuitProgram), "")
  @debug.assert_eq(ansi_clear_line(), "\u{1b}[K")
}

///|
test "padding and split lines cover vertical padding" {
  let node = pad(edge={ top: 1, right: 1, bottom: 1, left: 1 }, text("a\nb"))
  @debug.assert_eq(render_plain(node, { width: 4, height: 4 }), [
    "    ", " a  ", " b  ", "    ",
  ])
}
