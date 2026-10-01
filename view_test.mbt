///|
test "plain renderer stacks pads borders and clips" {
  let node = @rabbita_tui.border(
    kind=Square,
    @rabbita_tui.pad(
      edge=@rabbita_tui.Edge::xy(1, 0),
      @rabbita_tui.vstack(gap=1) <| [
        @rabbita_tui.text("hello"),
        @rabbita_tui.text("world"),
      ],
    ),
  )
  @debug.assert_eq(@rabbita_tui.render_plain(node, { width: 9, height: 5, }), [
    "+-------+", "| hello |", "|       |", "| world |", "+-------+",
  ])
}

///|
test "plain renderer covers empty fragment style fill and rounded border" {
  @debug.assert_eq(
    @rabbita_tui.render_plain(@rabbita_tui.empty(), { width: 3, height: 2, }),
    [],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.fragment <| [
        @rabbita_tui.text("a"),
        @rabbita_tui.text(style=@rabbita_tui.Style::default().dim(), "b"),
      ],
      { width: 2, height: 3, },
    ),
    ["a ", "b "],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.fill(style=@rabbita_tui.Style::default(), "."),
      { width: 4, height: 2, },
    ),
    ["....", "...."],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(@rabbita_tui.border(@rabbita_tui.text("x")), {
      width: 5,
      height: 3,
    }),
    ["╭───╮", "│x  │", "╰───╯"],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.border(kind=NoBorder, @rabbita_tui.text("x")),
      { width: 2, height: 1, },
    ),
    ["x "],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.border(kind=Normal, @rabbita_tui.text("x")),
      { width: 5, height: 3, },
    ),
    ["┌───┐", "│x  │", "└───┘"],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.border(kind=Double, @rabbita_tui.text("x")),
      { width: 5, height: 3, },
    ),
    ["╔═══╗", "║x  ║", "╚═══╝"],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.border(kind=Thick, @rabbita_tui.text("x")),
      { width: 5, height: 3, },
    ),
    ["┏━━━┓", "┃x  ┃", "┗━━━┛"],
  )
}

///|
test "horizontal stack distributes width" {
  let node = @rabbita_tui.hstack(gap=1) <| [
    @rabbita_tui.text("left"),
    @rabbita_tui.text("right"),
  ]
  @debug.assert_eq(@rabbita_tui.render_plain(node, { width: 11, height: 1, }), [
    "left  right",
  ])
  @debug.assert_eq(
    @rabbita_tui.render_plain(@rabbita_tui.hstack <| [], {
      width: 4,
      height: 1,
    }),
    [],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.hstack(gap=1) <| [
        @rabbita_tui.text("a"),
        @rabbita_tui.text("b\nc"),
      ],
      { width: 5, height: 2, },
    ),
    ["a  b ", "   c "],
  )
}

///|
test "wide characters are measured and clipped by display width" {
  @debug.assert_eq(@rabbita_tui.display_width("a你b"), 4)
  @debug.assert_eq(@rabbita_tui.take_width("a你b", 3), "a你")
  @debug.assert_eq(@rabbita_tui.fit_line("a你b", 3), "a你")
  @debug.assert_eq(@rabbita_tui.fit_line("abc", 0), "")
  @debug.assert_eq(@rabbita_tui.repeat_to_width("", 3), "")
  @debug.assert_eq(@rabbita_tui.repeat_to_width("x", 0), "")
  @debug.assert_eq(@rabbita_tui.align_line("x", 5, Start), "x    ")
  @debug.assert_eq(@rabbita_tui.align_line("x", 5, Center), "  x  ")
  @debug.assert_eq(@rabbita_tui.align_line("x", 5, End), "    x")
  @debug.assert_eq(@rabbita_tui.wrap_text("abcdef", 2), ["ab", "cd", "ef"])
  @debug.assert_eq(@rabbita_tui.wrap_text("a你b", 3), ["a你", "b"])
  @debug.assert_eq(@rabbita_tui.wrap_text("a\nb", 4), ["a", "b"])
  @debug.assert_eq(@rabbita_tui.wrap_text("hello world", 8), ["hello", "world"])
  @debug.assert_eq(@rabbita_tui.wrap_text("hello world", 20), ["hello world"])
}

///|
test "layout supports sizing alignment placement and edge constructors" {
  @debug.assert_eq(@rabbita_tui.Edge::zero(), @rabbita_tui.Edge::all(0))
  @debug.assert_eq(@rabbita_tui.Edge::horizontal(2), {
    top: 0,
    right: 2,
    bottom: 0,
    left: 2,
  })
  @debug.assert_eq(@rabbita_tui.Edge::vertical(1), {
    top: 1,
    right: 0,
    bottom: 1,
    left: 0,
  })
  @debug.assert_eq(@rabbita_tui.Edge::trbl(1, 2, 3, 4), {
    top: 1,
    right: 2,
    bottom: 3,
    left: 4,
  })
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.sized(width=3, height=2, @rabbita_tui.text("hello")),
      { width: 8, height: 3, },
    ),
    ["hel     ", "        "],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.sized(width=4, @rabbita_tui.text("hi")),
      { width: 8, height: 1, },
    ),
    ["hi      "],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.sized(height=3, @rabbita_tui.text("hi")),
      { width: 4, height: 4, },
    ),
    ["hi  ", "    ", "    "],
  )
  @debug.assert_eq(@rabbita_tui.fit_block(["x"], { width: 3, height: 2, }), [
    "x  ", "   ",
  ])
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.align(horizontal=End, vertical=End, @rabbita_tui.text("x")),
      { width: 4, height: 3, },
    ),
    ["    ", "    ", "   x"],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.place(size={ width: 5, height: 3, }, @rabbita_tui.text("x")),
      { width: 8, height: 4, },
    ),
    ["        ", "  x     ", "        "],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.join_horizontal(gap=1) <| [
        @rabbita_tui.text("a"),
        @rabbita_tui.text("b"),
      ],
      { width: 5, height: 1, },
    ),
    ["a  b "],
  )
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.join_vertical(gap=1) <| [
        @rabbita_tui.text("a"),
        @rabbita_tui.text("b"),
      ],
      { width: 2, height: 3, },
    ),
    ["a ", "  ", "b "],
  )
}

///|
test "style layout composes size padding and border" {
  let node = @rabbita_tui.vstack(
    style=@rabbita_tui.Style::default()
      .size(width=9, height=5)
      .padding(@rabbita_tui.Edge::all(1))
      .border(kind=Square),
  ) <| [
    @rabbita_tui.text("x"),
  ]
  @debug.assert_eq(@rabbita_tui.render_plain(node, { width: 9, height: 5, }), [
    "+-------+", "|       |", "| x     |", "|       |", "+-------+",
  ])
  @debug.assert_eq(
    @rabbita_tui.render_plain(
      @rabbita_tui.text(
        style=@rabbita_tui.Style::default()
          .size(width=5, height=3)
          .border(kind=Square),
        "x",
      ),
      { width: 5, height: 3, },
    ),
    ["+---+", "|x  |", "+---+"],
  )
}

///|
test "styles merge and ansi style emits compact sgr" {
  let style = @rabbita_tui.Style::default()
    .fg(Ansi(2))
    .bg(Rgb(10, 20, 30))
    .bold()
    .underline()
  let merged = @rabbita_tui.Style::default().fg(Ansi(1)).merge(style)
  @debug.assert_eq(merged.fg, Ansi(2))
  assert_true(@rabbita_tui.ansi_style(merged).contains("1;4;32;48;2;10;20;30"))
  @debug.assert_eq(@rabbita_tui.ansi_style(@rabbita_tui.Style::default()), "")
  assert_true(
    @rabbita_tui.ansi_style(
      @rabbita_tui.Style::default()
      .dim()
      .italic()
      .blink()
      .reverse()
      .strikethrough(),
    ).contains("2;3;5;7;9"),
  )
  assert_true(
    @rabbita_tui.ansi_style(@rabbita_tui.Style::default().fg(Ansi(9))).contains(
      "91",
    ),
  )
  assert_true(
    @rabbita_tui.ansi_style(@rabbita_tui.Style::default().fg(Ansi(200))).contains(
      "38;5;200",
    ),
  )
  @debug.assert_eq(@rabbita_tui.ansi_reset(), "\u{1b}[0m")
  @debug.assert_eq(@rabbita_tui.ansi_leave_alternate_screen(), "\u{1b}[?1049l")
  @debug.assert_eq(@rabbita_tui.ansi_show_cursor(), "\u{1b}[?25h")
  let rendered = @rabbita_tui.render_ansi(
    @rabbita_tui.text(
      style=@rabbita_tui.Style::default().fg(Ansi(1)).bold(),
      "ok",
    ),
    { width: 3, height: 1, },
  )
  assert_true(rendered.has_prefix("\u{1b}[1;31m"))
  assert_true(rendered.contains(@rabbita_tui.ansi_reset()))
  let container = @rabbita_tui.render_ansi(
    @rabbita_tui.vstack(style=@rabbita_tui.Style::default().fg(Ansi(2)).bold()) <| [
      @rabbita_tui.text("ok"),
    ],
    { width: 3, height: 1, },
  )
  assert_true(container.has_prefix("\u{1b}[1;32m"))
  let with_bg = @rabbita_tui.ansi_start_program(
    @rabbita_tui.ProgramOptions::inline(),
    @rabbita_tui.text(
      style=@rabbita_tui.Style::default().fg(Ansi(15)).bg(Ansi(4)),
      @rabbita_tui.fit_line("bg", 8),
    ),
    { width: 8, height: 1, },
  )
  assert_true(with_bg.contains("97;44m"))
  assert_true(with_bg.contains("\u{1b}[K\u{1b}[0m"))
}

///|
test "frame diff only rewrites changed lines" {
  let prev : @rabbita_tui.Frame = { lines: ["a", "b", "long"], }
  let next : @rabbita_tui.Frame = { lines: ["a", "B", "lo"], }
  let diff = @rabbita_tui.diff_ansi(Some(prev), next)
  assert_true(diff.contains("\u{1b}[2;1HB"))
  assert_true(diff.contains("\u{1b}[3;1Hlo\u{1b}[K"))
  assert_true(!diff.contains("\u{1b}[1;1H"))
  assert_true(@rabbita_tui.diff_ansi(None, next).has_prefix("\u{1b}[1;1H"))
  let (_, styled_diff) = @rabbita_tui.diff_node_ansi(
    Some(
      @rabbita_tui.Frame::from_node(@rabbita_tui.text("same"), {
        width: 6,
        height: 1,
      }),
    ),
    @rabbita_tui.text(style=@rabbita_tui.Style::default().fg(Ansi(1)), "same"),
    { width: 6, height: 1, },
  )
  assert_true(styled_diff.contains("\u{1b}[31m"))
}

///|
test "full render enters alternate screen and hides cursor" {
  let output = @rabbita_tui.full_render_ansi(@rabbita_tui.text("hi"), {
    width: 4,
    height: 1,
  })
  assert_true(output.has_prefix(@rabbita_tui.ansi_enter_alternate_screen()))
  assert_true(output.contains(@rabbita_tui.ansi_hide_cursor()))
  assert_true(output.contains("hi\u{1b}[K"))
}

///|
test "terminal ansi options and commands cover program modes" {
  let options = @rabbita_tui.ProgramOptions::default()
    .mouse(MouseButtonMotion)
    .bracketed_paste(true)
    .focus_events(true)
  let output = @rabbita_tui.ansi_start_program(
    options,
    @rabbita_tui.text("hi"),
    { width: 4, height: 1, },
  )
  assert_true(output.contains(@rabbita_tui.ansi_enter_alternate_screen()))
  assert_true(
    output.contains(@rabbita_tui.ansi_enable_mouse(MouseButtonMotion)),
  )
  assert_true(output.contains(@rabbita_tui.ansi_enable_bracketed_paste()))
  assert_true(output.contains(@rabbita_tui.ansi_enable_focus_events()))
  let cleanup = @rabbita_tui.ansi_stop_program(options)
  assert_true(cleanup.contains(@rabbita_tui.ansi_disable_focus_events()))
  assert_true(cleanup.contains(@rabbita_tui.ansi_disable_bracketed_paste()))
  assert_true(cleanup.contains(@rabbita_tui.ansi_disable_mouse()))
  assert_true(cleanup.contains(@rabbita_tui.ansi_leave_alternate_screen()))
  let inline = @rabbita_tui.ProgramOptions::inline().mouse(MouseButtonMotion)
  assert_true(
    @rabbita_tui.ansi_start_program(inline, @rabbita_tui.text("hi"), {
      width: 4,
      height: 1,
    }).contains(@rabbita_tui.ansi_enable_mouse(MouseButtonMotion)),
  )
  @debug.assert_eq(
    @rabbita_tui.ansi_terminal_command(SetWindowTitle("demo")),
    "\u{1b}]0;demo\u{07}",
  )
  assert_true(
    @rabbita_tui.ansi_terminal_command(ClearScreen).contains(
      @rabbita_tui.ansi_clear_screen(),
    ),
  )
  @debug.assert_eq(
    @rabbita_tui.ansi_terminal_command(EnableMouse(MouseOff)),
    @rabbita_tui.ansi_disable_mouse(),
  )
  @debug.assert_eq(@rabbita_tui.ansi_terminal_command(QuitProgram), "")
  @debug.assert_eq(@rabbita_tui.ansi_clear_line(), "\u{1b}[K")
}

///|
test "padding and split lines cover vertical padding" {
  let node = @rabbita_tui.pad(
    edge={ top: 1, right: 1, bottom: 1, left: 1, },
    @rabbita_tui.text("a\nb"),
  )
  @debug.assert_eq(@rabbita_tui.render_plain(node, { width: 4, height: 4, }), [
    "    ", " a  ", " b  ", "    ",
  ])
}
