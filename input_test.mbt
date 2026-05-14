///|
test "input parser decodes printable keys and controls" {
  @debug.assert_eq(parse_input(b"a\r\x7f\t\x03"), [
    Key(Char("a")),
    Key(Enter),
    Key(Backspace),
    Key(Tab),
    Key(Ctrl("c")),
  ])
}

///|
test "input parser decodes arrows navigation keys and function keys" {
  @debug.assert_eq(
    parse_input(
      b"\x1b[A\x1b[B\x1b[C\x1b[D\x1b[H\x1b[F\x1b[3~\x1b[5~\x1b[6~\x1bOP",
    ),
    [
      Key(Up),
      Key(Down),
      Key(Right),
      Key(Left),
      Key(Home),
      Key(End),
      Key(Delete),
      Key(PageUp),
      Key(PageDown),
      Key(Function(1)),
    ],
  )
}

///|
test "input parser decodes escape variants and function key ranges" {
  @debug.assert_eq(parse_input(b"\x1b"), [Key(Escape)])
  @debug.assert_eq(parse_input(b"\x1b[I\x1b[O"), [FocusGained, FocusLost])
  @debug.assert_eq(parse_input(b"\x1bOQ\x1bOR\x1bOS\x1bOH\x1bOF\x1b[Z"), [
    Key(Function(2)),
    Key(Function(3)),
    Key(Function(4)),
    Key(Home),
    Key(End),
    Key(BackTab),
  ])
  @debug.assert_eq(
    parse_input(
      b"\x1b[1~\x1b[4~\x1b[15~\x1b[17~\x1b[18~\x1b[19~\x1b[20~\x1b[21~\x1b[23~\x1b[24~",
    ),
    [
      Key(Home),
      Key(End),
      Key(Function(5)),
      Key(Function(6)),
      Key(Function(7)),
      Key(Function(8)),
      Key(Function(9)),
      Key(Function(10)),
      Key(Function(11)),
      Key(Function(12)),
    ],
  )
}

///|
test "input parser decodes modified xterm and kitty keyboard events" {
  @debug.assert_eq(
    parse_input(
      b"\x1b[1;2A\x1b[1;5D\x1b[5;7~\x1b[1;2P\x1b[97;5u\x1b[13;2u\x1b[27;5;65~",
    ),
    [
      Key(Modified(Up, KeyModifiers::none().shift(true))),
      Key(Modified(Left, KeyModifiers::none().ctrl(true))),
      Key(Modified(PageUp, KeyModifiers::none().alt(true).ctrl(true))),
      Key(Modified(Function(1), KeyModifiers::none().shift(true))),
      Key(Modified(Char("a"), KeyModifiers::none().ctrl(true))),
      Key(Modified(Enter, KeyModifiers::none().shift(true))),
      Key(Modified(Char("A"), KeyModifiers::none().ctrl(true))),
    ],
  )
}

///|
test "input parser decodes bracketed paste" {
  @debug.assert_eq(parse_input(b"\x1b[200~hello\nworld\xe4\xbd\xa0\x1b[201~"), [
    Paste("hello\nworld你"),
  ])
  assert_true(parse_input(b"\x1b[200~unfinished")[0] is UnknownEvent(_))
}

///|
test "input parser decodes alt and utf8 input" {
  @debug.assert_eq(parse_input(b"\x1bb\xe4\xbd\xa0"), [
    Key(Alt("b")),
    Key(Char("你")),
  ])
  @debug.assert_eq(parse_input(b"\xc3\xa9\xf0\x9f\x98\x80"), [
    Key(Char("é")),
    Key(Char("😀")),
  ])
}

///|
test "input parser decodes sgr mouse events" {
  @debug.assert_eq(
    parse_input(
      b"\x1b[<0;12;5M\x1b[<0;12;5m\x1b[<32;6;7M\x1b[<65;2;3M\x1b[<64;4;5M\x1b[<1;1;2M\x1b[<2;3;4M\x1b[<3;5;6M",
    ),
    [
      Mouse({ button: Primary, action: Press, x: 12, y: 5 }),
      Mouse({ button: Primary, action: Release, x: 12, y: 5 }),
      Mouse({ button: Primary, action: Drag, x: 6, y: 7 }),
      Mouse({ button: WheelDown, action: Press, x: 2, y: 3 }),
      Mouse({ button: WheelUp, action: Press, x: 4, y: 5 }),
      Mouse({ button: Middle, action: Press, x: 1, y: 2 }),
      Mouse({ button: Secondary, action: Press, x: 3, y: 4 }),
      Mouse({ button: Other(3), action: Press, x: 5, y: 6 }),
    ],
  )
}

///|
test "input parser keeps incomplete escape as unknown" {
  let events = parse_input(b"\x1b[<0;1")
  assert_true(events[0] is UnknownEvent(_))
  assert_true(parse_input(b"\x1bOZ")[0] is UnknownEvent(_))
  assert_true(parse_input(b"\x1b[?25h")[0] is UnknownEvent(_))
  assert_true(parse_input(b"\x1b[<0;1M")[0] is UnknownEvent(_))
  assert_true(parse_input(b"\x1b[<x;1;2M")[0] is UnknownEvent(_))
  assert_true(parse_input(b"\xff")[0] is Key(Char(_)))
}
