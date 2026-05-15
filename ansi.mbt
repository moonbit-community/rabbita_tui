///|
pub(all) struct Frame {
  lines : Array[String]
} derive(Eq, Debug)

///|
pub fn Frame::from_node(node : Node, size : Size) -> Frame {
  { lines: render_plain(node, size) }
}

///|
pub fn Frame::to_string(self : Frame) -> String {
  join_lines(self.lines)
}

///|
priv struct StyledLine {
  plain : String
  ansi : String
  style : Style
}

///|
priv struct StyledFrame {
  lines : Array[StyledLine]
}

///|
pub fn ansi_style(style : Style) -> String {
  let codes : Array[String] = []
  if style.bold {
    codes.push("1")
  }
  if style.dim {
    codes.push("2")
  }
  if style.italic {
    codes.push("3")
  }
  if style.underline {
    codes.push("4")
  }
  if style.blink {
    codes.push("5")
  }
  if style.reverse {
    codes.push("7")
  }
  if style.strikethrough {
    codes.push("9")
  }
  write_color_codes(codes, style.fg, foreground=true)
  write_color_codes(codes, style.bg, foreground=false)
  if codes.is_empty() {
    ""
  } else {
    let joined = join_with(codes, ";")
    "\u{1b}[\{joined}m"
  }
}

///|
pub fn ansi_reset() -> String {
  "\u{1b}[0m"
}

///|
pub fn ansi_enter_alternate_screen() -> String {
  "\u{1b}[?1049h"
}

///|
pub fn ansi_leave_alternate_screen() -> String {
  "\u{1b}[?1049l"
}

///|
pub fn ansi_hide_cursor() -> String {
  "\u{1b}[?25l"
}

///|
pub fn ansi_show_cursor() -> String {
  "\u{1b}[?25h"
}

///|
pub fn ansi_clear_screen() -> String {
  "\u{1b}[2J"
}

///|
pub fn ansi_clear_line() -> String {
  "\u{1b}[K"
}

///|
pub fn ansi_disable_autowrap() -> String {
  "\u{1b}[?7l"
}

///|
pub fn ansi_enable_autowrap() -> String {
  "\u{1b}[?7h"
}

///|
pub fn ansi_move_cursor(row : Int, column : Int) -> String {
  "\u{1b}[\{row};\{column}H"
}

///|
pub fn ansi_move_cursor_up(rows : Int) -> String {
  if rows <= 0 {
    ""
  } else {
    "\u{1b}[\{rows}A"
  }
}

///|
pub fn ansi_enable_mouse(mode : MouseMode) -> String {
  match mode {
    MouseOff => ansi_disable_mouse()
    MouseCellMotion => "\u{1b}[?1000h\u{1b}[?1006h"
    MouseButtonMotion => "\u{1b}[?1002h\u{1b}[?1006h"
    MouseAllMotion => "\u{1b}[?1003h\u{1b}[?1006h"
  }
}

///|
pub fn ansi_disable_mouse() -> String {
  "\u{1b}[?1000l\u{1b}[?1002l\u{1b}[?1003l\u{1b}[?1006l"
}

///|
pub fn ansi_enable_bracketed_paste() -> String {
  "\u{1b}[?2004h"
}

///|
pub fn ansi_disable_bracketed_paste() -> String {
  "\u{1b}[?2004l"
}

///|
pub fn ansi_enable_focus_events() -> String {
  "\u{1b}[?1004h"
}

///|
pub fn ansi_disable_focus_events() -> String {
  "\u{1b}[?1004l"
}

///|
pub fn ansi_set_window_title(title : String) -> String {
  "\u{1b}]0;\{title}\u{07}"
}

///|
pub fn ansi_start_program(
  options : ProgramOptions,
  node : Node,
  size : Size,
) -> String {
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
  out.write_string(ansi_clear_screen())
  out.write_string(paint_styled_frame_ansi(StyledFrame::from_node(node, size)))
  out.to_string()
}

///|
pub fn ansi_stop_program(options : ProgramOptions) -> String {
  let out = StringBuilder::new()
  out.write_string(ansi_enable_autowrap())
  if options.focus_events {
    out.write_string(ansi_disable_focus_events())
  }
  if options.bracketed_paste {
    out.write_string(ansi_disable_bracketed_paste())
  }
  if options.mouse_mode != MouseOff {
    out.write_string(ansi_disable_mouse())
  }
  if options.hide_cursor {
    out.write_string(ansi_show_cursor())
  }
  if options.alternate_screen {
    out.write_string(ansi_leave_alternate_screen())
  }
  out.to_string()
}

///|
pub fn ansi_terminal_command(command : TerminalCommand) -> String {
  match command {
    QuitProgram | Repaint => ""
    Print(value) => value
    PrintLine(value) => "\{value}\r\n"
    PrintErr(value) => value
    PrintErrLine(value) => "\{value}\r\n"
    ClearScreen => "\{ansi_clear_screen()}\{ansi_move_cursor(1, 1)}"
    EnterAlternateScreen => ansi_enter_alternate_screen()
    LeaveAlternateScreen => ansi_leave_alternate_screen()
    HideCursor => ansi_hide_cursor()
    ShowCursor => ansi_show_cursor()
    EnableMouse(mode) => ansi_enable_mouse(mode)
    DisableMouse => ansi_disable_mouse()
    EnableBracketedPaste => ansi_enable_bracketed_paste()
    DisableBracketedPaste => ansi_disable_bracketed_paste()
    EnableFocusEvents => ansi_enable_focus_events()
    DisableFocusEvents => ansi_disable_focus_events()
    SetWindowTitle(title) => ansi_set_window_title(title)
  }
}

///|
pub fn render_ansi(node : Node, size : Size) -> String {
  let frame = StyledFrame::from_node(node, size)
  let lines : Array[String] = []
  for line in frame.lines {
    lines.push(line.ansi)
  }
  join_lines(lines)
}

///|
pub fn full_render_ansi(node : Node, size : Size) -> String {
  ansi_start_program(ProgramOptions::default(), node, size)
}

///|
pub fn diff_ansi(previous : Frame?, next : Frame) -> String {
  match previous {
    None => paint_frame_ansi(next)
    Some(prev) => diff_lines(prev.lines, next.lines)
  }
}

///|
pub fn diff_node_ansi(
  previous : Frame?,
  node : Node,
  size : Size,
) -> (Frame, String) {
  let next = StyledFrame::from_node(node, size)
  let plain = next.plain_frame()
  let output = paint_styled_frame_ansi(next)
  ignore(previous)
  (plain, output)
}

///|
pub fn paint_frame_ansi(frame : Frame) -> String {
  let out = StringBuilder::new()
  for index, line in frame.lines {
    out.write_string(ansi_move_cursor(index + 1, 1))
    out.write_string(screen_line(line))
  }
  out.to_string()
}

///|
fn paint_styled_frame_ansi(frame : StyledFrame) -> String {
  let out = StringBuilder::new()
  for index, line in frame.lines {
    out.write_string(ansi_move_cursor(index + 1, 1))
    out.write_string(screen_styled_line(line))
  }
  out.to_string()
}

///|
fn paint_styled_frame_inline(frame : StyledFrame) -> String {
  let out = StringBuilder::new()
  for index, line in frame.lines {
    if index > 0 {
      out.write_string("\r\n")
    }
    out.write_string(screen_styled_line(line))
  }
  out.to_string()
}

///|
fn repaint_styled_frame_inline(
  previous_height : Int,
  frame : StyledFrame,
) -> String {
  let out = StringBuilder::new()
  out.write_string(ansi_move_cursor_up(previous_height - 1))
  out.write_string("\r")
  let limit = Int::max(previous_height, frame.lines.length())
  for index in 0..<limit {
    if index > 0 {
      out.write_string("\r\n")
    }
    let line = if index < frame.lines.length() {
      frame.lines[index]
    } else {
      styled_line("", Style::default())
    }
    out.write_string(screen_styled_line(line))
  }
  out.to_string()
}

///|
fn diff_styled_frame_inline(
  previous : StyledFrame,
  next : StyledFrame,
) -> String {
  let out = StringBuilder::new()
  if previous.lines.length() > 0 {
    out.write_string(ansi_move_cursor_up(previous.lines.length() - 1))
  }
  out.write_string("\r")
  let limit = Int::max(previous.lines.length(), next.lines.length())
  for index in 0..<limit {
    if index > 0 {
      out.write_string("\r\n")
    }
    let old_line = if index < previous.lines.length() {
      previous.lines[index]
    } else {
      styled_line("", Style::default())
    }
    let new_line = if index < next.lines.length() {
      next.lines[index]
    } else {
      styled_line("", Style::default())
    }
    if old_line.plain != new_line.plain || old_line.ansi != new_line.ansi {
      out.write_string(screen_styled_line(new_line))
    }
  }
  out.to_string()
}

///|
fn diff_styled_frame(previous : StyledFrame, next : StyledFrame) -> String {
  let out = StringBuilder::new()
  let limit = Int::max(previous.lines.length(), next.lines.length())
  for index in 0..<limit {
    let old_line = if index < previous.lines.length() {
      previous.lines[index]
    } else {
      styled_line("", Style::default())
    }
    let new_line = if index < next.lines.length() {
      next.lines[index]
    } else {
      styled_line("", Style::default())
    }
    if old_line.plain != new_line.plain || old_line.ansi != new_line.ansi {
      out.write_string(ansi_move_cursor(index + 1, 1))
      out.write_string(screen_styled_line(new_line))
    }
  }
  out.to_string()
}

///|
fn diff_lines(previous : Array[String], next : Array[String]) -> String {
  let out = StringBuilder::new()
  let limit = Int::max(previous.length(), next.length())
  for index in 0..<limit {
    let old_line = if index < previous.length() { previous[index] } else { "" }
    let new_line = if index < next.length() { next[index] } else { "" }
    if old_line != new_line {
      out.write_string(ansi_move_cursor(index + 1, 1))
      out.write_string(screen_line(new_line))
    }
  }
  out.to_string()
}

///|
fn screen_line(line : String) -> String {
  "\{trim_trailing_spaces(line)}\{ansi_clear_line()}"
}

///|
fn screen_styled_line(line : StyledLine) -> String {
  let plain = trim_trailing_spaces(line.plain)
  if line.style == Style::default() {
    if line.ansi == line.plain {
      "\{plain}\{ansi_clear_line()}"
    } else {
      "\{trim_trailing_spaces(line.ansi)}\{ansi_clear_line()}"
    }
  } else if line.style.bg != Default {
    "\{ansi_style(line.style)}\{plain}\{ansi_clear_line()}\{ansi_reset()}"
  } else {
    "\{styled_text(plain, line.style)}\{ansi_clear_line()}"
  }
}

///|
fn trim_trailing_spaces(line : String) -> String {
  let mut end = line.length()
  while end > 0 && line[end - 1] == ' ' {
    end -= 1
  }
  line[:end].to_owned()
}

///|
fn StyledFrame::from_node(node : Node, size : Size) -> StyledFrame {
  {
    lines: fit_styled_lines(
      render_styled_lines(node, size, Style::default()),
      size,
    ),
  }
}

///|
fn StyledFrame::plain_frame(self : StyledFrame) -> Frame {
  let lines : Array[String] = []
  for line in self.lines {
    lines.push(line.plain)
  }
  { lines, }
}

///|
fn render_styled_lines(
  node : Node,
  size : Size,
  inherited : Style,
) -> Array[StyledLine] {
  match node {
    Empty => []
    Text(value, style) => {
      let out : Array[StyledLine] = []
      let text_style = inherited.merge(style)
      for line in split_ansi_lines(value) {
        out.push(styled_line(line, text_style))
      }
      out
    }
    Fragment(children) => {
      let out : Array[StyledLine] = []
      for child in children {
        for line in render_styled_lines(child, size, inherited) {
          out.push(line)
        }
      }
      out
    }
    VStack(children, gap) =>
      render_styled_vstack(children, gap, size, inherited)
    HStack(children, gap) =>
      render_styled_hstack(children, gap, size, inherited)
    Pad(child, edge) => render_styled_padded(child, edge, size, inherited)
    Styled(child, style) =>
      render_styled_lines(child, size, inherited.merge(style))
    Bordered(child, border, style) =>
      render_styled_border(
        child,
        border,
        inherited.merge(style),
        size,
        inherited,
      )
    Clip(child, clip_size) =>
      fit_styled_lines(
        render_styled_lines(child, clip_size, inherited),
        clip_size,
      )
    Sized(child, fixed) => {
      let target = {
        width: if fixed.width >= 0 {
          fixed.width
        } else {
          size.width
        },
        height: if fixed.height >= 0 {
          fixed.height
        } else {
          size.height
        },
      }
      fit_styled_block(
        render_styled_lines(child, target, inherited),
        target,
        inherited,
      )
    }
    Aligned(child, horizontal, vertical) =>
      render_styled_aligned(child, size, horizontal, vertical, inherited)
    Placed(child, place_size, horizontal, vertical) =>
      render_styled_aligned(child, place_size, horizontal, vertical, inherited)
    Fill(value, style) => {
      let out : Array[StyledLine] = []
      let fill_style = inherited.merge(style)
      for _ in 0..<size.height {
        out.push(styled_line(repeat_to_width(value, size.width), fill_style))
      }
      out
    }
  }
}

///|
fn render_styled_vstack(
  children : Array[Node],
  gap : Int,
  size : Size,
  inherited : Style,
) -> Array[StyledLine] {
  let out : Array[StyledLine] = []
  for index, child in children {
    if index > 0 {
      for _ in 0..<gap {
        out.push(styled_line("", inherited))
      }
    }
    for line in render_styled_lines(child, size, inherited) {
      out.push(line)
    }
  }
  out
}

///|
fn render_styled_hstack(
  children : Array[Node],
  gap : Int,
  size : Size,
  inherited : Style,
) -> Array[StyledLine] {
  if children.is_empty() {
    return []
  }
  let child_width = Int::max(
    1,
    (size.width - gap * (children.length() - 1)) / children.length(),
  )
  let rendered : Array[Array[StyledLine]] = []
  let mut height = 0
  for child in children {
    let child_lines = fit_styled_lines(
      render_styled_lines(
        child,
        { width: child_width, height: size.height },
        inherited,
      ),
      { width: child_width, height: size.height },
    )
    if child_lines.length() > height {
      height = child_lines.length()
    }
    rendered.push(child_lines)
  }
  let out : Array[StyledLine] = []
  let spacer = repeat_to_width(" ", gap)
  let styled_spacer = styled_text(spacer, inherited)
  for row in 0..<height {
    let plain = StringBuilder::new()
    let ansi = StringBuilder::new()
    for index, child_lines in rendered {
      if index > 0 {
        plain.write_string(spacer)
        ansi.write_string(styled_spacer)
      }
      let part = if row < child_lines.length() {
        pad_styled_right(child_lines[row], child_width)
      } else {
        styled_line(repeat_to_width(" ", child_width), inherited)
      }
      plain.write_string(part.plain)
      ansi.write_string(part.ansi)
    }
    out.push(raw_styled_line(plain.to_string(), ansi.to_string()))
  }
  out
}

///|
fn render_styled_padded(
  child : Node,
  edge : Edge,
  size : Size,
  inherited : Style,
) -> Array[StyledLine] {
  let inner = {
    width: Int::max(0, size.width - edge.left - edge.right),
    height: Int::max(0, size.height - edge.top - edge.bottom),
  }
  let out : Array[StyledLine] = []
  let blank = styled_line(repeat_to_width(" ", size.width), inherited)
  for _ in 0..<edge.top {
    out.push(blank)
  }
  let left = repeat_to_width(" ", edge.left)
  let right = repeat_to_width(" ", edge.right)
  let styled_left = styled_text(left, inherited)
  let styled_right = styled_text(right, inherited)
  for line in render_styled_lines(child, inner, inherited) {
    let fitted = fit_styled_line(line, inner.width)
    out.push(
      raw_styled_line(
        "\{left}\{fitted.plain}\{right}",
        "\{styled_left}\{fitted.ansi}\{styled_right}",
      ),
    )
  }
  for _ in 0..<edge.bottom {
    out.push(blank)
  }
  out
}

///|
fn render_styled_border(
  child : Node,
  kind : Border,
  border_style : Style,
  size : Size,
  inherited : Style,
) -> Array[StyledLine] {
  if kind is NoBorder || size.width < 2 || size.height < 2 {
    return render_styled_lines(child, size, inherited)
  }
  let (tl, tr, bl, br, horizontal, vertical) = match kind {
    Normal => ("┌", "┐", "└", "┘", "─", "│")
    Rounded => ("╭", "╮", "╰", "╯", "─", "│")
    Square => ("+", "+", "+", "+", "-", "|")
    Double => ("╔", "╗", "╚", "╝", "═", "║")
    Thick => ("┏", "┓", "┗", "┛", "━", "┃")
    NoBorder => ("", "", "", "", "", "")
  }
  let inner = { width: size.width - 2, height: size.height - 2 }
  let inner_lines = fit_styled_lines(
    render_styled_lines(child, inner, inherited),
    inner,
  )
  let out : Array[StyledLine] = []
  let horizontal_line = repeat_to_width(horizontal, inner.width)
  out.push(styled_line("\{tl}\{horizontal_line}\{tr}", border_style))
  for line in inner_lines {
    let vertical_line = styled_text(vertical, border_style)
    out.push(
      raw_styled_line(
        "\{vertical}\{line.plain}\{vertical}",
        "\{vertical_line}\{line.ansi}\{vertical_line}",
      ),
    )
  }
  while out.length() < size.height - 1 {
    let blank = repeat_to_width(" ", inner.width)
    let styled_vertical = styled_text(vertical, border_style)
    let styled_blank = styled_text(blank, inherited)
    out.push(
      raw_styled_line(
        "\{vertical}\{blank}\{vertical}",
        "\{styled_vertical}\{styled_blank}\{styled_vertical}",
      ),
    )
  }
  out.push(styled_line("\{bl}\{horizontal_line}\{br}", border_style))
  out
}

///|
fn render_styled_aligned(
  child : Node,
  size : Size,
  horizontal : Align,
  vertical : Align,
  inherited : Style,
) -> Array[StyledLine] {
  let raw = render_styled_lines(child, size, inherited)
  let lines : Array[StyledLine] = []
  let limit = Int::min(raw.length(), size.height)
  for index in 0..<limit {
    lines.push(fit_styled_line(raw[index], size.width))
  }
  let mut top = 0
  if vertical is Center {
    top = Int::max(0, (size.height - lines.length()) / 2)
  } else if vertical is End {
    top = Int::max(0, size.height - lines.length())
  }
  let out : Array[StyledLine] = []
  let blank = styled_line(repeat_to_width(" ", size.width), Style::default())
  for _ in 0..<top {
    out.push(blank)
  }
  for line in lines {
    out.push(align_styled_line(line, size.width, horizontal))
  }
  while out.length() < size.height {
    out.push(blank)
  }
  out
}

///|
fn fit_styled_lines(
  lines : Array[StyledLine],
  size : Size,
) -> Array[StyledLine] {
  let out : Array[StyledLine] = []
  let limit = Int::min(lines.length(), size.height)
  for index in 0..<limit {
    out.push(fit_styled_line(lines[index], size.width))
  }
  out
}

///|
fn fit_styled_block(
  lines : Array[StyledLine],
  size : Size,
  inherited : Style,
) -> Array[StyledLine] {
  let out = fit_styled_lines(lines, size)
  while out.length() < size.height {
    out.push(styled_line(repeat_to_width(" ", size.width), inherited))
  }
  out
}

///|
fn fit_styled_line(line : StyledLine, width : Int) -> StyledLine {
  let plain = fit_line(line.plain, width)
  if line.style != Style::default() {
    styled_line(plain, line.style)
  } else if line.ansi == line.plain {
    styled_line(plain, Style::default())
  } else if display_width(line.plain) <= width {
    pad_styled_right(line, width)
  } else {
    raw_styled_line(plain, take_ansi_width(line.ansi, width))
  }
}

///|
fn take_ansi_width(value : String, width : Int) -> String {
  if width <= 0 {
    return ""
  }
  let out = StringBuilder::new()
  let mut used = 0
  let mut index = 0
  let mut saw_escape = false
  while index < value.length() && used < width {
    if is_ansi_escape_start(value, index) {
      let end = ansi_escape_end(value, index + 2)
      out.write_string(value[index:end].to_owned())
      saw_escape = true
      index = end
    } else {
      let char = Int::unsafe_to_char(value.code_unit_at(index).to_int())
      let char_width = display_width(char.to_string())
      if used + char_width > width {
        break
      }
      out.write_char(char)
      used += char_width
      index += 1
    }
  }
  if saw_escape {
    out.write_string(ansi_reset())
  }
  out.to_string()
}

///|
fn is_ansi_escape_start(value : String, index : Int) -> Bool {
  index + 1 < value.length() &&
  value.code_unit_at(index) == Int::to_uint16(0x1b) &&
  value.code_unit_at(index + 1) == Int::to_uint16('['.to_int())
}

///|
fn ansi_escape_end(value : String, start : Int) -> Int {
  let mut index = start
  while index < value.length() {
    let code = value.code_unit_at(index).to_int()
    index += 1
    if code >= 0x40 && code <= 0x7e {
      break
    }
  }
  index
}

///|
fn pad_styled_right(line : StyledLine, width : Int) -> StyledLine {
  let padding = repeat_to_width(
    " ",
    Int::max(0, width - display_width(line.plain)),
  )
  raw_styled_line("\{line.plain}\{padding}", "\{line.ansi}\{padding}")
}

///|
fn align_styled_line(
  line : StyledLine,
  width : Int,
  alignment : Align,
) -> StyledLine {
  let clipped = fit_styled_line(
    line,
    Int::min(width, display_width(line.plain)),
  )
  let remaining = Int::max(0, width - display_width(clipped.plain))
  match alignment {
    Start => pad_styled_right(clipped, width)
    Center => {
      let left = remaining / 2
      let left_pad = repeat_to_width(" ", left)
      let right_pad = repeat_to_width(" ", remaining - left)
      raw_styled_line(
        "\{left_pad}\{clipped.plain}\{right_pad}",
        "\{left_pad}\{clipped.ansi}\{right_pad}",
      )
    }
    End => {
      let pad = repeat_to_width(" ", remaining)
      raw_styled_line("\{pad}\{clipped.plain}", "\{pad}\{clipped.ansi}")
    }
  }
}

///|
fn styled_line(plain : String, style : Style) -> StyledLine {
  { plain, ansi: styled_text(plain, style), style }
}

///|
fn raw_styled_line(plain : String, ansi : String) -> StyledLine {
  { plain, ansi, style: Style::default() }
}

///|
fn styled_text(value : String, style : Style) -> String {
  if style == Style::default() || value == "" {
    value
  } else {
    "\{ansi_style(style)}\{value}\{ansi_reset()}"
  }
}

///|
fn split_ansi_lines(value : String) -> Array[String] {
  let out : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < value.length() {
    if value[index] == '\n' {
      out.push(value[start:index].to_owned())
      start = index + 1
    }
    index += 1
  }
  out.push(value[start:].to_owned())
  out
}

///|
fn write_color_codes(
  codes : Array[String],
  color : Color,
  foreground~ : Bool,
) -> Unit {
  let base = if foreground { 30 } else { 40 }
  match color {
    Default => ()
    Ansi(index) =>
      if index >= 0 && index < 8 {
        codes.push((base + index).to_string())
      } else if index >= 8 && index < 16 {
        codes.push((base + 60 + index - 8).to_string())
      } else {
        codes.push(if foreground { "38" } else { "48" })
        codes.push("5")
        codes.push(index.to_string())
      }
    Rgb(r, g, b) => {
      codes.push(if foreground { "38" } else { "48" })
      codes.push("2")
      codes.push(clamp_color(r).to_string())
      codes.push(clamp_color(g).to_string())
      codes.push(clamp_color(b).to_string())
    }
  }
}

///|
fn clamp_color(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value
  }
}

///|
fn join_lines(lines : Array[String]) -> String {
  join_with(lines, "\n")
}

///|
fn join_with(items : Array[String], sep : String) -> String {
  let out = StringBuilder::new()
  for index, item in items {
    if index > 0 {
      out.write_string(sep)
    }
    out.write_string(item)
  }
  out.to_string()
}
