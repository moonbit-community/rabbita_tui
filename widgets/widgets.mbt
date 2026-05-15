///|
using @tui {
  display_width,
  fit_line,
  repeat_to_width,
  take_width,
  text,
  type Key,
  type KeyModifiers,
  type Node,
  type Size,
  type Style,
  vstack,
}

///|
pub(all) struct TextInput {
  value : String
  cursor : Int
  placeholder : String
} derive(Eq, Debug)

///|
pub(all) enum TextInputMsg {
  TextInputKey(Key)
  TextInputSet(String)
  TextInputClear
} derive(Eq, Debug)

///|
pub fn TextInput::TextInput(
  placeholder? : String = "",
  value? : String = "",
) -> TextInput {
  { value, cursor: char_count(value), placeholder }
}

///|
fn insert_text_input(input : TextInput, text : String) -> TextInput {
  let cursor = clamp(0, char_count(input.value), input.cursor)
  let (left, right) = split_at_chars(input.value, cursor)
  let value = "\{left}\{text}\{right}"
  { ..input, value, cursor: cursor + char_count(text) }
}

///|
fn backspace_text_input(input : TextInput) -> TextInput {
  let cursor = clamp(0, char_count(input.value), input.cursor)
  if cursor == 0 {
    input
  } else {
    let (left, right) = split_at_chars(input.value, cursor)
    {
      ..input,
      value: "\{take_chars(left, cursor - 1)}\{right}",
      cursor: cursor - 1,
    }
  }
}

///|
fn delete_text_input(input : TextInput) -> TextInput {
  let count = char_count(input.value)
  let cursor = clamp(0, count, input.cursor)
  if cursor >= count {
    input
  } else {
    let (left, rest) = split_at_chars(input.value, cursor)
    let (_, right) = split_at_chars(rest, 1)
    { ..input, value: "\{left}\{right}", cursor }
  }
}

///|
fn move_text_input_left(input : TextInput) -> TextInput {
  { ..input, cursor: Int::max(0, input.cursor - 1) }
}

///|
fn move_text_input_right(input : TextInput) -> TextInput {
  { ..input, cursor: Int::min(char_count(input.value), input.cursor + 1) }
}

///|
fn update_text_input(input : TextInput, key : Key) -> TextInput {
  match key {
    Char(value) => insert_text_input(input, value)
    Backspace => backspace_text_input(input)
    Delete => delete_text_input(input)
    Left => move_text_input_left(input)
    Right => move_text_input_right(input)
    Home => { ..input, cursor: 0 }
    End => { ..input, cursor: char_count(input.value) }
    _ => input
  }
}

///|
pub fn TextInput::update(self : TextInput, msg : TextInputMsg) -> TextInput {
  match msg {
    TextInputKey(key) => update_text_input(self, key)
    TextInputSet(value) => { ..self, value, cursor: char_count(value) }
    TextInputClear => { ..self, value: "", cursor: 0 }
  }
}

///|
pub fn TextInput::view(
  self : TextInput,
  width~ : Int,
  style? : Style = Style::default(),
) -> Node {
  let shown = if self.value == "" { self.placeholder } else { self.value }
  let cursor = if self.value == "" {
    0
  } else {
    clamp(0, char_count(shown), self.cursor)
  }
  text(style~, fit_line(line_with_cursor(shown, cursor, width), width))
}

///|
pub(all) struct Textarea {
  lines : Array[String]
  row : Int
  column : Int
  placeholder : String
} derive(Eq, Debug)

///|
pub(all) enum TextareaMsg {
  TextareaKey(Key)
  TextareaSet(String)
  TextareaClear
} derive(Eq, Debug)

///|
pub fn Textarea::Textarea(
  placeholder? : String = "",
  value? : String = "",
) -> Textarea {
  set_textarea({ lines: [""], row: 0, column: 0, placeholder }, value)
}

///|
fn set_textarea(area : Textarea, value : String) -> Textarea {
  let lines = split_widget_lines(value)
  let last = Int::max(0, lines.length() - 1)
  { ..area, lines, row: last, column: char_count(lines[last]) }
}

///|
pub fn Textarea::value(self : Textarea) -> String {
  textarea_value(self)
}

///|
fn textarea_value(area : Textarea) -> String {
  join_widget_lines(area.lines)
}

///|
fn insert_textarea(area : Textarea, value : String) -> Textarea {
  if value.contains("\n") {
    let mut next = area
    for char in value {
      if char == '\n' {
        next = newline_textarea(next)
      } else {
        next = insert_textarea(next, char.to_string())
      }
    }
    return next
  }
  let row = clamp(0, area.lines.length() - 1, area.row)
  let current = area.lines[row]
  let column = clamp(0, char_count(current), area.column)
  let lines = area.lines.copy()
  let (left, right) = split_at_chars(current, column)
  lines[row] = "\{left}\{value}\{right}"
  { ..area, lines, row, column: column + char_count(value) }
}

///|
fn newline_textarea(area : Textarea) -> Textarea {
  let row = clamp(0, area.lines.length() - 1, area.row)
  let current = area.lines[row]
  let column = clamp(0, char_count(current), area.column)
  let lines : Array[String] = []
  for index in 0..<row {
    lines.push(area.lines[index])
  }
  let (left, right) = split_at_chars(current, column)
  lines.push(left)
  lines.push(right)
  let start = row + 1
  for index in start..<area.lines.length() {
    lines.push(area.lines[index])
  }
  { ..area, lines, row: row + 1, column: 0 }
}

///|
fn backspace_textarea(area : Textarea) -> Textarea {
  let row = clamp(0, area.lines.length() - 1, area.row)
  let current = area.lines[row]
  let column = clamp(0, char_count(current), area.column)
  if column > 0 {
    let lines = area.lines.copy()
    let (left, right) = split_at_chars(current, column)
    lines[row] = "\{take_chars(left, column - 1)}\{right}"
    { ..area, lines, row, column: column - 1 }
  } else if row > 0 {
    let previous = area.lines[row - 1]
    let lines : Array[String] = []
    let stop = row - 1
    for index in 0..<stop {
      lines.push(area.lines[index])
    }
    lines.push("\{previous}\{current}")
    let start = row + 1
    for index in start..<area.lines.length() {
      lines.push(area.lines[index])
    }
    { ..area, lines, row: row - 1, column: char_count(previous) }
  } else {
    area
  }
}

///|
fn delete_textarea(area : Textarea) -> Textarea {
  let row = clamp(0, area.lines.length() - 1, area.row)
  let current = area.lines[row]
  let column = clamp(0, char_count(current), area.column)
  if column < char_count(current) {
    let lines = area.lines.copy()
    let (left, rest) = split_at_chars(current, column)
    let (_, right) = split_at_chars(rest, 1)
    lines[row] = "\{left}\{right}"
    { ..area, lines, row, column }
  } else if row + 1 < area.lines.length() {
    let next = area.lines[row + 1]
    let lines : Array[String] = []
    for index in 0..<row {
      lines.push(area.lines[index])
    }
    lines.push("\{current}\{next}")
    let start = row + 2
    for index in start..<area.lines.length() {
      lines.push(area.lines[index])
    }
    { ..area, lines, row, column }
  } else {
    area
  }
}

///|
fn move_textarea_up(area : Textarea) -> Textarea {
  let row = Int::max(0, area.row - 1)
  { ..area, row, column: Int::min(area.column, char_count(area.lines[row])) }
}

///|
fn move_textarea_down(area : Textarea) -> Textarea {
  let row = Int::min(area.lines.length() - 1, area.row + 1)
  { ..area, row, column: Int::min(area.column, char_count(area.lines[row])) }
}

///|
fn update_textarea(area : Textarea, key : Key) -> Textarea {
  match key {
    Char(value) => insert_textarea(area, value)
    Enter => newline_textarea(area)
    Backspace => backspace_textarea(area)
    Delete => delete_textarea(area)
    Left =>
      if area.column > 0 {
        { ..area, column: area.column - 1 }
      } else if area.row > 0 {
        {
          ..area,
          row: area.row - 1,
          column: char_count(area.lines[area.row - 1]),
        }
      } else {
        area
      }
    Right =>
      if area.column < char_count(area.lines[area.row]) {
        { ..area, column: area.column + 1 }
      } else if area.row + 1 < area.lines.length() {
        { ..area, row: area.row + 1, column: 0 }
      } else {
        area
      }
    Up => move_textarea_up(area)
    Down => move_textarea_down(area)
    Home => { ..area, column: 0 }
    End => { ..area, column: char_count(area.lines[area.row]) }
    _ => area
  }
}

///|
pub fn Textarea::update(self : Textarea, msg : TextareaMsg) -> Textarea {
  match msg {
    TextareaKey(key) => update_textarea(self, key)
    TextareaSet(value) => set_textarea(self, value)
    TextareaClear => set_textarea(self, "")
  }
}

///|
pub fn Textarea::view(
  self : Textarea,
  size~ : Size,
  style? : Style = Style::default(),
) -> Node {
  if textarea_value(self) == "" && self.placeholder != "" {
    return vstack(style~) <| [
        text(
          fit_line(
            line_with_cursor(self.placeholder, 0, size.width),
            size.width,
          ),
        ),
        ..blank_nodes(Int::max(0, size.height - 1), size.width),
      ]
  }
  let row = clamp(0, self.lines.length() - 1, self.row)
  let start = if row >= size.height { row - size.height + 1 } else { 0 }
  let end = Int::min(self.lines.length(), start + size.height)
  let visible = Array::makei(end - start, relative_index => {
    let index = start + relative_index
    let line = self.lines[index]
    let shown = if index == self.row {
      line_with_cursor(line, self.column, size.width)
    } else {
      take_width(line, size.width)
    }
    text(fit_line(shown, size.width))
  })
  vstack(style~) <| [
    ..visible,
    ..blank_nodes(Int::max(0, size.height - visible.length()), size.width),
  ]
}

///|
pub(all) struct List {
  items : Array[String]
  selected : Int
  offset : Int
} derive(Eq, Debug)

///|
pub(all) enum ListMsg {
  ListMove(Int, Int)
  ListPage(Int, Int)
  ListSelect(Int)
} derive(Eq, Debug)

///|
pub fn List::List(
  items~ : Array[String],
  selected? : Int = 0,
  offset? : Int = 0,
) -> List {
  { items, selected, offset }
}

///|
fn move_list_selection(state : List, delta : Int, height? : Int = 0) -> List {
  if state.items.is_empty() {
    { ..state, selected: 0, offset: 0 }
  } else {
    let selected = clamp(0, state.items.length() - 1, state.selected + delta)
    let offset = if height > 0 {
      viewport_offset(selected, state.offset, height)
    } else {
      state.offset
    }
    { ..state, selected, offset }
  }
}

///|
fn page_list(state : List, delta : Int, height : Int) -> List {
  move_list_selection(state, delta * height, height~)
}

///|
pub fn List::selected_item(self : List) -> String? {
  selected_list_item(self)
}

///|
fn selected_list_item(state : List) -> String? {
  if state.items.is_empty() {
    None
  } else {
    Some(state.items[clamp(0, state.items.length() - 1, state.selected)])
  }
}

///|
pub fn List::update(self : List, msg : ListMsg) -> List {
  match msg {
    ListMove(delta, height) => move_list_selection(self, delta, height~)
    ListPage(delta, height) => page_list(self, delta, height)
    ListSelect(index) =>
      move_list_selection(
        { ..self, selected: 0 },
        index,
        height=self.items.length(),
      )
  }
}

///|
pub fn List::view(
  self : List,
  size~ : Size,
  style? : Style = Style::default(),
) -> Node {
  let offset = viewport_offset(self.selected, self.offset, size.height)
  let start = clamp(0, self.items.length(), offset)
  let end = Int::min(self.items.length(), start + size.height)
  vstack(style~) <| Array::makei(end - start, offset => {
    let index = start + offset
    let marker = if index == self.selected { "> " } else { "  " }
    text(fit_line("\{marker}\{self.items[index]}", size.width))
  })
}

///|
pub(all) struct TableColumn {
  title : String
  width : Int
} derive(Eq, Debug)

///|
pub fn table(
  columns~ : Array[TableColumn],
  rows~ : Array[Array[String]],
  selected? : Int = 0,
  offset? : Int = 0,
  size~ : Size,
  style? : Style = Style::default(),
) -> Node {
  let selected = if rows.is_empty() {
    0
  } else {
    clamp(0, rows.length() - 1, selected)
  }
  let header_cells = columns.map(column => fit_line(column.title, column.width))
  let body_height = Int::max(0, size.height - 2)
  let offset = viewport_offset(selected, offset, body_height)
  let end = Int::min(rows.length(), offset + body_height)
  let body = Array::makei(end - offset, relative_index => {
    let row_index = offset + relative_index
    let row = rows[row_index]
    let cells = columns.mapi((column_index, column) => {
      let value = if column_index < row.length() {
        row[column_index]
      } else {
        ""
      }
      fit_line(value, column.width)
    })
    let marker = if row_index == selected { "> " } else { "  " }
    let row = join_cells(cells)
    text(fit_line("\{marker}\{row}", size.width))
  })
  vstack(style~) <| [
    text(fit_line(join_cells(header_cells), size.width)),
    text(repeat_to_width("-", size.width)),
    ..body,
  ]
}

///|
pub(all) struct Viewport {
  lines : Array[String]
  offset : Int
} derive(Eq, Debug)

///|
pub(all) enum ViewportMsg {
  ViewportScroll(Int, Int)
  ViewportJump(Int, Int)
} derive(Eq, Debug)

///|
pub fn Viewport::Viewport(
  lines~ : Array[String],
  offset? : Int = 0,
) -> Viewport {
  { lines, offset }
}

///|
fn scroll_viewport(viewport : Viewport, delta : Int, height : Int) -> Viewport {
  let max_offset = Int::max(0, viewport.lines.length() - height)
  { ..viewport, offset: clamp(0, max_offset, viewport.offset + delta) }
}

///|
pub fn Viewport::update(self : Viewport, msg : ViewportMsg) -> Viewport {
  match msg {
    ViewportScroll(delta, height) => scroll_viewport(self, delta, height)
    ViewportJump(offset, height) =>
      scroll_viewport({ ..self, offset: 0 }, offset, height)
  }
}

///|
pub fn Viewport::view(
  self : Viewport,
  size~ : Size,
  style? : Style = Style::default(),
) -> Node {
  let end = Int::min(self.lines.length(), self.offset + size.height)
  vstack(style~) <| Array::makei(end - self.offset, relative_index => {
    let index = self.offset + relative_index
    text(fit_line(self.lines[index], size.width))
  })
}

///|
pub fn paginator(
  page~ : Int,
  per_page~ : Int,
  total_items~ : Int,
  width~ : Int,
  style? : Style = Style::default(),
) -> Node {
  let pages = paginator_pages(total_items~, per_page~)
  text(style~, fit_line("Page \{clamp_page(page, pages) + 1}/\{pages}", width))
}

///|
fn paginator_pages(total_items~ : Int, per_page~ : Int) -> Int {
  let total_items = Int::max(0, total_items)
  let per_page = Int::max(1, per_page)
  Int::max(1, (total_items + per_page - 1) / per_page)
}

///|
fn clamp_page(page : Int, pages : Int) -> Int {
  clamp(0, Int::max(1, pages) - 1, page)
}

///|
pub fn progress(
  current~ : Int,
  total~ : Int,
  width~ : Int,
  style? : Style = Style::default(),
) -> Node {
  let ratio = Double::min(
    1.0,
    Double::max(
      0.0,
      Int::max(0, current).to_double() / Int::max(1, total).to_double(),
    ),
  )
  let bar_width = Int::max(1, width - 6)
  let filled = (ratio * bar_width.to_double()).to_int()
  let percent = (ratio * 100.0).to_int()
  let filled_bar = repeat_to_width("█", filled)
  let empty_bar = repeat_to_width("░", bar_width - filled)
  text(style~, fit_line("\{filled_bar}\{empty_bar} \{percent}%", width))
}

///|
pub fn timer(
  remaining_ms~ : Int,
  width~ : Int,
  style? : Style = Style::default(),
) -> Node {
  let seconds = (Int::max(0, remaining_ms) + 999) / 1000
  text(style~, fit_line("\{seconds}s", width))
}

///|
pub(all) struct KeyBinding {
  keys : Array[Key]
  help : String
} derive(Eq, Debug)

///|
fn key_binding_label(binding : KeyBinding) -> String {
  "\{key_names(binding.keys)} \{binding.help}"
}

///|
pub fn keymap(
  bindings~ : Array[KeyBinding],
  width~ : Int,
  style? : Style = Style::default(),
) -> Node {
  let parts = bindings.map(key_binding_label)
  text(style~, fit_line(join_with_sep(parts, "  "), width))
}

///|
pub fn tabs(
  labels~ : Array[String],
  active? : Int = 0,
  width~ : Int,
  style? : Style = Style::default(),
) -> Node {
  let active = if labels.is_empty() {
    0
  } else {
    clamp(0, labels.length() - 1, active)
  }
  let parts = labels.mapi((index, label) => {
    if index == active {
      "[\{label}]"
    } else {
      " \{label} "
    }
  })
  text(style~, fit_line(join_with_sep(parts, " "), width))
}

///|
pub(all) struct CommandPalette {
  input : TextInput
  items : Array[String]
  selected : Int
} derive(Eq, Debug)

///|
pub(all) enum CommandPaletteMsg {
  CommandPaletteKey(Key)
  CommandPaletteSelect(Int)
  CommandPaletteSetInput(String)
} derive(Eq, Debug)

///|
pub fn CommandPalette::CommandPalette(
  items~ : Array[String],
  selected? : Int = 0,
) -> CommandPalette {
  { input: TextInput(), items, selected }
}

///|
fn update_command_palette(
  palette : CommandPalette,
  key : Key,
) -> CommandPalette {
  match key {
    Up => { ..palette, selected: Int::max(0, palette.selected - 1) }
    Down => {
      let count = command_palette_items(palette).length()
      {
        ..palette,
        selected: clamp(0, Int::max(0, count - 1), palette.selected + 1),
      }
    }
    _ =>
      { ..palette, input: palette.input.update(TextInputKey(key)), selected: 0 }
  }
}

///|
pub fn CommandPalette::items(self : CommandPalette) -> Array[String] {
  command_palette_items(self)
}

///|
fn command_palette_items(palette : CommandPalette) -> Array[String] {
  if palette.input.value == "" {
    palette.items
  } else {
    palette.items.filter(item => item.contains(palette.input.value))
  }
}

///|
pub fn CommandPalette::selected_item(self : CommandPalette) -> String? {
  selected_command_palette_item(self)
}

///|
fn selected_command_palette_item(palette : CommandPalette) -> String? {
  let items = command_palette_items(palette)
  if items.is_empty() {
    None
  } else {
    Some(items[clamp(0, items.length() - 1, palette.selected)])
  }
}

///|
pub fn CommandPalette::update(
  self : CommandPalette,
  msg : CommandPaletteMsg,
) -> CommandPalette {
  match msg {
    CommandPaletteKey(key) => update_command_palette(self, key)
    CommandPaletteSelect(index) => {
      let count = command_palette_items(self).length()
      { ..self, selected: clamp(0, Int::max(0, count - 1), index) }
    }
    CommandPaletteSetInput(value) =>
      { ..self, input: self.input.update(TextInputSet(value)), selected: 0 }
  }
}

///|
pub fn CommandPalette::view(
  self : CommandPalette,
  size~ : Size,
  style? : Style = Style::default(),
) -> Node {
  let items = command_palette_items(self)
  let end = clamp(0, items.length(), size.height - 1)
  let item_nodes = Array::makei(end, index => {
    let marker = if index == self.selected { "> " } else { "  " }
    text(fit_line("\{marker}\{items[index]}", size.width))
  })
  vstack(style=style.border(kind=Rounded)) <| [
    self.input.view(width=size.width),
    ..item_nodes,
  ]
}

///|
pub fn modal(
  title~ : String,
  size~ : Size,
  style? : Style = Style::default(),
  children : Array[Node],
) -> Node {
  vstack(style=style.border(kind=Rounded)) <| [
    text(fit_line(title, size.width - 2)),
    ..children,
  ]
}

///|
pub fn status_line(
  left~ : String,
  right~ : String,
  width~ : Int,
  style? : Style = Style::default(),
) -> Node {
  let left_width = display_width(left)
  let right_width = display_width(right)
  if left_width + right_width >= width {
    text(style~, fit_line("\{left} \{right}", width))
  } else {
    let gap = repeat_to_width(" ", width - left_width - right_width)
    text(style~, "\{left}\{gap}\{right}")
  }
}

///|
pub fn spinner(style? : Style = Style::default(), frame : Int) -> Node {
  let frames = ["-", "\\", "|", "/"]
  text(style~, frames[frame % frames.length()])
}

///|
fn clamp(lbound : Int, ubound : Int, value : Int) -> Int {
  if value < lbound {
    lbound
  } else if value > ubound {
    ubound
  } else {
    value
  }
}

///|
fn char_count(value : String) -> Int {
  let mut count = 0
  for _char in value {
    count += 1
  }
  count
}

///|
fn take_chars(value : String, count : Int) -> String {
  let out = StringBuilder::new()
  let mut taken = 0
  for char in value {
    if taken >= count {
      break
    }
    out.write_char(char)
    taken += 1
  }
  out.to_string()
}

///|
fn split_at_chars(value : String, count : Int) -> (String, String) {
  let left = StringBuilder::new()
  let right = StringBuilder::new()
  let mut index = 0
  for char in value {
    if index < count {
      left.write_char(char)
    } else {
      right.write_char(char)
    }
    index += 1
  }
  (left.to_string(), right.to_string())
}

///|
fn line_with_cursor(value : String, cursor : Int, width : Int) -> String {
  let cursor = clamp(0, char_count(value), cursor)
  let (before, after) = split_at_chars(value, cursor)
  let text_width = Int::max(0, width - 1)
  let left = take_right_width(before, text_width)
  let right = take_width(after, Int::max(0, text_width - display_width(left)))
  "\{left}█\{right}"
}

///|
fn take_right_width(value : String, width : Int) -> String {
  if width <= 0 {
    return ""
  }
  let chars : Array[String] = []
  for char in value {
    chars.push(char.to_string())
  }
  let mut start = chars.length()
  let mut used = 0
  while start > 0 {
    let next = chars[start - 1]
    let next_width = display_width(next)
    if used + next_width > width {
      break
    }
    start -= 1
    used += next_width
  }
  let out = StringBuilder::new()
  for index in start..<chars.length() {
    out.write_string(chars[index])
  }
  out.to_string()
}

///|
fn blank_nodes(count : Int, width : Int) -> Array[Node] {
  Array::makei(count, _ => text(repeat_to_width(" ", width)))
}

///|
fn viewport_offset(selected : Int, offset : Int, height : Int) -> Int {
  if height <= 0 {
    0
  } else if selected < offset {
    selected
  } else if selected >= offset + height {
    selected - height + 1
  } else {
    offset
  }
}

///|
fn split_widget_lines(value : String) -> Array[String] {
  let lines : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < value.length() {
    if value[index] == '\n' {
      lines.push(value[start:index].to_owned())
      start = index + 1
    }
    index += 1
  }
  lines.push(value[start:].to_owned())
  lines
}

///|
fn join_widget_lines(lines : Array[String]) -> String {
  join_with_sep(lines, "\n")
}

///|
fn join_cells(cells : Array[String]) -> String {
  join_with_sep(cells, " ")
}

///|
fn join_with_sep(items : Array[String], sep : String) -> String {
  let out = StringBuilder::new()
  for index, item in items {
    if index > 0 {
      out.write_string(sep)
    }
    out.write_string(item)
  }
  out.to_string()
}

///|
fn key_names(keys : Array[Key]) -> String {
  join_with_sep(keys.map(key => key_name(key)), "/")
}

///|
fn key_name(key : Key) -> String {
  match key {
    Char(value) => value
    Enter => "enter"
    Escape => "esc"
    Backspace => "backspace"
    Tab => "tab"
    BackTab => "shift+tab"
    Up => "up"
    Down => "down"
    Left => "left"
    Right => "right"
    Home => "home"
    End => "end"
    Delete => "delete"
    PageUp => "pgup"
    PageDown => "pgdn"
    Ctrl(value) => "ctrl+\{value}"
    Alt(value) => "alt+\{value}"
    Modified(inner, modifiers) =>
      "\{modifier_name(modifiers)}\{key_name(inner)}"
    Function(index) => "f\{index}"
    Unknown(value) => value
  }
}

///|
fn modifier_name(modifiers : KeyModifiers) -> String {
  let parts = [
    if modifiers.ctrl {
      Some("ctrl")
    } else {
      None
    },
    if modifiers.alt {
      Some("alt")
    } else {
      None
    },
    if modifiers.shift {
      Some("shift")
    } else {
      None
    },
    if modifiers.super_key {
      Some("super")
    } else {
      None
    },
    if modifiers.hyper {
      Some("hyper")
    } else {
      None
    },
    if modifiers.meta {
      Some("meta")
    } else {
      None
    },
  ].filter_map(value => value)
  if parts.is_empty() {
    ""
  } else {
    let label = join_with_sep(parts, "+")
    "\{label}+"
  }
}
