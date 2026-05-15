///|
pub fn empty(style? : Style = Style::default()) -> Node {
  apply_style(Empty, style)
}

///|
pub fn text(style? : Style = Style::default(), value : String) -> Node {
  apply_layout_style(Text(value, style_text(style)), style)
}

///|
pub fn fragment(
  style? : Style = Style::default(),
  children : Array[Node],
) -> Node {
  apply_style(Fragment(children), style)
}

///|
pub fn vstack(
  gap? : Int = 0,
  style? : Style = Style::default(),
  children : Array[Node],
) -> Node {
  apply_style(VStack(children, gap), style)
}

///|
pub fn hstack(
  gap? : Int = 0,
  style? : Style = Style::default(),
  children : Array[Node],
) -> Node {
  apply_style(HStack(children, gap), style)
}

///|
pub fn pad(
  edge~ : Edge,
  style? : Style = Style::default(),
  node : Node,
) -> Node {
  apply_style(Pad(node, edge), style)
}

///|
pub fn border(
  kind? : Border = Rounded,
  style? : Style = Style::default(),
  node : Node,
) -> Node {
  apply_style(Bordered(node, kind, Style::default()), style)
}

///|
pub fn clip(
  size~ : Size,
  style? : Style = Style::default(),
  node : Node,
) -> Node {
  apply_style(Clip(node, size), style)
}

///|
pub fn sized(
  width? : Int = -1,
  height? : Int = -1,
  style? : Style = Style::default(),
  node : Node,
) -> Node {
  apply_style(Sized(node, { width, height }), style)
}

///|
pub fn align(
  horizontal? : Align = Start,
  vertical? : Align = Start,
  style? : Style = Style::default(),
  node : Node,
) -> Node {
  apply_style(Aligned(node, horizontal, vertical), style)
}

///|
pub fn place(
  size~ : Size,
  horizontal? : Align = Center,
  vertical? : Align = Center,
  style? : Style = Style::default(),
  node : Node,
) -> Node {
  apply_style(Placed(node, size, horizontal, vertical), style)
}

///|
pub fn join_horizontal(
  gap? : Int = 0,
  style? : Style = Style::default(),
  children : Array[Node],
) -> Node {
  hstack(gap~, style~) <| children
}

///|
pub fn join_vertical(
  gap? : Int = 0,
  style? : Style = Style::default(),
  children : Array[Node],
) -> Node {
  vstack(gap~, style~) <| children
}

///|
pub fn fill(style? : Style = Style::default(), value : String) -> Node {
  Fill(value, style)
}

///|
fn apply_style(node : Node, style : Style) -> Node {
  let mut out = node
  let text_style = style_text(style)
  if text_style != Style::default() {
    out = Styled(out, text_style)
  }
  apply_layout_style(out, style)
}

///|
fn apply_layout_style(node : Node, style : Style) -> Node {
  let mut out = node
  if style.padding != Edge::zero() {
    out = Pad(out, style.padding)
  }
  if style.border != NoBorder {
    out = Bordered(out, style.border, Style::default())
  }
  if style.align_set {
    out = Aligned(out, style.align_horizontal, style.align_vertical)
  }
  if style.width >= 0 || style.height >= 0 {
    out = Sized(out, { width: style.width, height: style.height })
  }
  if style.clip_width >= 0 && style.clip_height >= 0 {
    out = Clip(out, { width: style.clip_width, height: style.clip_height })
  }
  out
}

///|
fn style_text(style : Style) -> Style {
  {
    ..Style::default(),
    fg: style.fg,
    bg: style.bg,
    bold: style.bold,
    dim: style.dim,
    italic: style.italic,
    underline: style.underline,
    blink: style.blink,
    reverse: style.reverse,
    strikethrough: style.strikethrough,
  }
}

///|
pub fn render_plain(node : Node, size : Size) -> Array[String] {
  let lines = render_lines(node, size, Style::default())
  fit_lines(lines, size)
}

///|
fn render_lines(node : Node, size : Size, inherited : Style) -> Array[String] {
  match node {
    Empty => []
    Text(value, _) => split_lines(value)
    Fragment(children) => {
      let out : Array[String] = []
      for child in children {
        for line in render_lines(child, size, inherited) {
          out.push(line)
        }
      }
      out
    }
    VStack(children, gap) => render_vstack(children, gap, size, inherited)
    HStack(children, gap) => render_hstack(children, gap, size, inherited)
    Pad(child, edge) => render_padded(child, edge, size, inherited)
    Styled(child, style) => render_lines(child, size, inherited.merge(style))
    Bordered(child, border, _) => render_border(child, border, size, inherited)
    Clip(child, clip_size) =>
      fit_lines(render_lines(child, clip_size, inherited), clip_size)
    Sized(child, fixed) => render_sized(child, fixed, size, inherited)
    Aligned(child, horizontal, vertical) =>
      render_aligned(child, size, horizontal, vertical, inherited)
    Placed(child, place_size, horizontal, vertical) =>
      render_aligned(child, place_size, horizontal, vertical, inherited)
    Fill(value, _) => {
      let out : Array[String] = []
      for _ in 0..<size.height {
        out.push(repeat_to_width(value, size.width))
      }
      out
    }
  }
}

///|
fn render_sized(
  child : Node,
  fixed : Size,
  available : Size,
  inherited : Style,
) -> Array[String] {
  let target = {
    width: if fixed.width >= 0 {
      fixed.width
    } else {
      available.width
    },
    height: if fixed.height >= 0 {
      fixed.height
    } else {
      available.height
    },
  }
  fit_block(render_lines(child, target, inherited), target)
}

///|
fn render_aligned(
  child : Node,
  size : Size,
  horizontal : Align,
  vertical : Align,
  inherited : Style,
) -> Array[String] {
  let raw = render_lines(child, size, inherited)
  let lines : Array[String] = []
  let limit = Int::min(raw.length(), size.height)
  for index in 0..<limit {
    lines.push(take_width(raw[index], size.width))
  }
  let mut top = 0
  if vertical is Center {
    top = Int::max(0, (size.height - lines.length()) / 2)
  } else if vertical is End {
    top = Int::max(0, size.height - lines.length())
  }
  let out : Array[String] = []
  let blank = repeat_to_width(" ", size.width)
  for _ in 0..<top {
    out.push(blank)
  }
  for line in lines {
    out.push(align_line(line, size.width, horizontal))
  }
  while out.length() < size.height {
    out.push(blank)
  }
  out
}

///|
fn render_vstack(
  children : Array[Node],
  gap : Int,
  size : Size,
  inherited : Style,
) -> Array[String] {
  let out : Array[String] = []
  for index, child in children {
    if index > 0 {
      for _ in 0..<gap {
        out.push("")
      }
    }
    for line in render_lines(child, size, inherited) {
      out.push(line)
    }
  }
  out
}

///|
fn render_hstack(
  children : Array[Node],
  gap : Int,
  size : Size,
  inherited : Style,
) -> Array[String] {
  if children.is_empty() {
    return []
  }
  let child_width = Int::max(
    1,
    (size.width - gap * (children.length() - 1)) / children.length(),
  )
  let rendered : Array[Array[String]] = []
  let mut height = 0
  for child in children {
    let child_lines = fit_lines(
      render_lines(
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
  let out : Array[String] = []
  let spacer = repeat_to_width(" ", gap)
  for row in 0..<height {
    let line = StringBuilder::new()
    for index, child_lines in rendered {
      if index > 0 {
        line.write_string(spacer)
      }
      if row < child_lines.length() {
        line.write_string(pad_right(child_lines[row], child_width))
      } else {
        line.write_string(repeat_to_width(" ", child_width))
      }
    }
    out.push(line.to_string())
  }
  out
}

///|
fn render_padded(
  child : Node,
  edge : Edge,
  size : Size,
  inherited : Style,
) -> Array[String] {
  let inner = {
    width: Int::max(0, size.width - edge.left - edge.right),
    height: Int::max(0, size.height - edge.top - edge.bottom),
  }
  let out : Array[String] = []
  let blank = repeat_to_width(" ", size.width)
  for _ in 0..<edge.top {
    out.push(blank)
  }
  for line in render_lines(child, inner, inherited) {
    let left = repeat_to_width(" ", edge.left)
    let right = repeat_to_width(" ", edge.right)
    out.push("\{left}\{fit_line(line, inner.width)}\{right}")
  }
  for _ in 0..<edge.bottom {
    out.push(blank)
  }
  out
}

///|
fn render_border(
  child : Node,
  kind : Border,
  size : Size,
  inherited : Style,
) -> Array[String] {
  if kind is NoBorder || size.width < 2 || size.height < 2 {
    return render_lines(child, size, inherited)
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
  let inner_lines = fit_lines(render_lines(child, inner, inherited), inner)
  let out : Array[String] = []
  out.push("\{tl}\{repeat_to_width(horizontal, inner.width)}\{tr}")
  for line in inner_lines {
    out.push("\{vertical}\{fit_line(line, inner.width)}\{vertical}")
  }
  while out.length() < size.height - 1 {
    let blank = repeat_to_width(" ", inner.width)
    out.push("\{vertical}\{blank}\{vertical}")
  }
  out.push("\{bl}\{repeat_to_width(horizontal, inner.width)}\{br}")
  out
}

///|
fn split_lines(value : String) -> Array[String] {
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
pub fn fit_lines(lines : Array[String], size : Size) -> Array[String] {
  let out : Array[String] = []
  let limit = Int::min(lines.length(), size.height)
  for index in 0..<limit {
    out.push(fit_line(lines[index], size.width))
  }
  out
}

///|
pub fn wrap_text(value : String, width : Int) -> Array[String] {
  if width <= 0 {
    return [""]
  }
  let out : Array[String] = []
  for paragraph in split_lines(value) {
    wrap_paragraph(paragraph, width, out)
  }
  out
}

///|
fn wrap_paragraph(value : String, width : Int, out : Array[String]) -> Unit {
  if value == "" {
    out.push("")
    return
  }
  let mut line = ""
  for word in split_words(value) {
    let word_width = display_width(word)
    if word_width > width {
      if line != "" {
        out.push(line)
        line = ""
      }
      line = wrap_long_word(word, width, out)
    } else if line == "" {
      line = word
    } else if display_width(line) + 1 + word_width <= width {
      line = "\{line} \{word}"
    } else {
      out.push(line)
      line = word
    }
  }
  if line != "" {
    out.push(line)
  }
}

///|
fn wrap_long_word(value : String, width : Int, out : Array[String]) -> String {
  let mut line = ""
  let mut used = 0
  for char in value {
    let piece = char.to_string()
    let piece_width = display_width(piece)
    if used > 0 && used + piece_width > width {
      out.push(line)
      line = ""
      used = 0
    }
    line = "\{line}\{piece}"
    used += piece_width
  }
  line
}

///|
fn split_words(value : String) -> Array[String] {
  let out : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < value.length() {
    if value[index] == ' ' {
      if start < index {
        out.push(value[start:index].to_owned())
      }
      start = index + 1
    }
    index += 1
  }
  if start < value.length() {
    out.push(value[start:].to_owned())
  }
  out
}

///|
pub fn fit_block(lines : Array[String], size : Size) -> Array[String] {
  let out = fit_lines(lines, size)
  let blank = repeat_to_width(" ", size.width)
  while out.length() < size.height {
    out.push(blank)
  }
  out
}

///|
pub fn fit_line(line : String, width : Int) -> String {
  if width <= 0 {
    ""
  } else if display_width(line) <= width {
    pad_right(line, width)
  } else {
    take_width(line, width)
  }
}

///|
pub fn pad_right(line : String, width : Int) -> String {
  let current = display_width(line)
  if current >= width {
    line
  } else {
    let padding = repeat_to_width(" ", width - current)
    "\{line}\{padding}"
  }
}

///|
pub fn align_line(line : String, width : Int, alignment : Align) -> String {
  let clipped = if display_width(line) > width {
    take_width(line, width)
  } else {
    line
  }
  let remaining = Int::max(0, width - display_width(clipped))
  match alignment {
    Start => {
      let padding = repeat_to_width(" ", remaining)
      "\{clipped}\{padding}"
    }
    Center => {
      let left = remaining / 2
      let left_padding = repeat_to_width(" ", left)
      let right_padding = repeat_to_width(" ", remaining - left)
      "\{left_padding}\{clipped}\{right_padding}"
    }
    End => {
      let padding = repeat_to_width(" ", remaining)
      "\{padding}\{clipped}"
    }
  }
}

///|
pub fn repeat_to_width(value : String, width : Int) -> String {
  if width <= 0 || value == "" {
    return ""
  }
  let out = StringBuilder::new()
  let mut used = 0
  while used < width {
    out.write_string(value)
    used += display_width(value)
  }
  take_width(out.to_string(), width)
}

///|
pub fn display_width(value : String) -> Int {
  let mut width = 0
  for char in value {
    width += char_width(char)
  }
  width
}

///|
pub fn take_width(value : String, width : Int) -> String {
  if width <= 0 {
    return ""
  }
  let out = StringBuilder::new()
  let mut used = 0
  for char in value {
    let width_of_char = char_width(char)
    if used + width_of_char > width {
      break
    }
    out.write_char(char)
    used += width_of_char
  }
  out.to_string()
}

///|
fn char_width(char : Char) -> Int {
  let code = char.to_int()
  if (code >= 0x1100 && code <= 0x115f) ||
    (code >= 0x2e80 && code <= 0xa4cf && !(code >= 0x2500 && code <= 0x259f)) ||
    (code >= 0xac00 && code <= 0xd7a3) ||
    (code >= 0xf900 && code <= 0xfaff) ||
    (code >= 0xfe10 && code <= 0xfe6f) ||
    (code >= 0xff00 && code <= 0xff60) ||
    (code >= 0xffe0 && code <= 0xffe6) ||
    (code >= 0x1f300 && code <= 0x1faff) {
    2
  } else {
    1
  }
}
