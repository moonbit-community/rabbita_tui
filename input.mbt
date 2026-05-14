///|
pub fn parse_input(bytes : Bytes) -> Array[Event] {
  let (events, _) = parse_available(bytes, false)
  events
}

///|
struct InputDecoder {
  pending : Bytes
} derive(Eq, Debug)

///|
fn InputDecoder::new() -> InputDecoder {
  { pending: b"" }
}

///|
fn InputDecoder::has_pending(self : InputDecoder) -> Bool {
  self.pending.length() > 0
}

///|
fn InputDecoder::pending_is_lone_escape(self : InputDecoder) -> Bool {
  self.pending.length() == 1 && self.pending[0].to_int() == 0x1b
}

///|
fn InputDecoder::feed(
  self : InputDecoder,
  bytes : Bytes,
) -> (Array[Event], InputDecoder) {
  let input = if self.pending.length() == 0 {
    bytes
  } else {
    concat_bytes(self.pending, bytes)
  }
  let (events, consumed) = parse_available(input, true)
  let pending = if consumed >= input.length() {
    b""
  } else {
    input[consumed:].to_owned()
  }
  (events, { pending, })
}

///|
fn InputDecoder::flush(self : InputDecoder) -> (Array[Event], InputDecoder) {
  (parse_input(self.pending), { pending: b"" })
}

///|
fn parse_available(
  bytes : Bytes,
  hold_incomplete : Bool,
) -> (Array[Event], Int) {
  let events : Array[Event] = []
  let mut index = 0
  while index < bytes.length() {
    match parse_one(bytes, index, hold_incomplete) {
      Parsed(event, next) => {
        events.push(event)
        index = next
      }
      IncompleteInput => break
    }
  }
  (events, index)
}

///|
priv enum InputParse {
  Parsed(Event, Int)
  IncompleteInput
}

///|
fn parse_one(bytes : Bytes, index : Int, hold_incomplete : Bool) -> InputParse {
  let byte = bytes[index].to_int()
  if byte == 0x1b {
    if starts_with_ascii(bytes, index, "\u{1b}[200~") {
      parse_paste(bytes, index, hold_incomplete)
    } else {
      parse_escape(bytes, index, hold_incomplete)
    }
  } else if byte == 0x0d || byte == 0x0a {
    Parsed(Key(Enter), index + 1)
  } else if byte == 0x7f || byte == 0x08 {
    Parsed(Key(Backspace), index + 1)
  } else if byte == 0x09 {
    Parsed(Key(Tab), index + 1)
  } else if byte > 0 && byte < 0x20 {
    Parsed(
      Key(Ctrl(String::make(1, Int::unsafe_to_char(byte + 96)))),
      index + 1,
    )
  } else if byte < 0x80 {
    Parsed(Key(Char(String::make(1, Int::unsafe_to_char(byte)))), index + 1)
  } else {
    let len = utf8_char_len(byte)
    if hold_incomplete && index + len > bytes.length() {
      IncompleteInput
    } else {
      let (text, next) = take_utf8_char(bytes, index)
      Parsed(Key(Char(text)), next)
    }
  }
}

///|
fn parse_escape(
  bytes : Bytes,
  index : Int,
  hold_incomplete : Bool,
) -> InputParse {
  if index + 1 >= bytes.length() {
    return if hold_incomplete {
      IncompleteInput
    } else {
      Parsed(Key(Escape), index + 1)
    }
  }
  let next = bytes[index + 1].to_int()
  if next != '[' && next != 'O'.to_int() {
    let len = utf8_char_len(next)
    if hold_incomplete && index + 1 + len > bytes.length() {
      return IncompleteInput
    }
    let (text, end) = take_utf8_char(bytes, index + 1)
    return Parsed(Key(Alt(text)), end)
  }
  if next == 'O'.to_int() && index + 2 < bytes.length() {
    match bytes[index + 2].to_int().unsafe_to_char() {
      'P' => Parsed(Key(Function(1)), index + 3)
      'Q' => Parsed(Key(Function(2)), index + 3)
      'R' => Parsed(Key(Function(3)), index + 3)
      'S' => Parsed(Key(Function(4)), index + 3)
      'H' => Parsed(Key(Home), index + 3)
      'F' => Parsed(Key(End), index + 3)
      _ =>
        Parsed(
          UnknownEvent(slice_ascii(bytes, index, bytes.length())),
          bytes.length(),
        )
    }
  } else {
    parse_csi(bytes, index, hold_incomplete)
  }
}

///|
fn parse_csi(bytes : Bytes, index : Int, hold_incomplete : Bool) -> InputParse {
  let mut end = index + 2
  while end < bytes.length() && !is_csi_final(bytes[end]) {
    end += 1
  }
  if end >= bytes.length() {
    return if hold_incomplete {
      IncompleteInput
    } else {
      Parsed(
        UnknownEvent(slice_ascii(bytes, index, bytes.length())),
        bytes.length(),
      )
    }
  }
  let terminator = bytes[end].to_int().unsafe_to_char()
  let body = slice_ascii(bytes, index + 2, end)
  if body.has_prefix("<") && (terminator == 'M' || terminator == 'm') {
    Parsed(parse_sgr_mouse(body, terminator), end + 1)
  } else {
    match parse_csi_key(body, terminator) {
      Some(event) => Parsed(event, end + 1)
      None => Parsed(UnknownEvent(slice_ascii(bytes, index, end + 1)), end + 1)
    }
  }
}

///|
fn parse_paste(
  bytes : Bytes,
  index : Int,
  hold_incomplete : Bool,
) -> InputParse {
  let start = index + "\u{1b}[200~".length()
  let mut end = start
  while end < bytes.length() && !starts_with_ascii(bytes, end, "\u{1b}[201~") {
    end += 1
  }
  if end >= bytes.length() {
    return if hold_incomplete {
      IncompleteInput
    } else {
      Parsed(
        UnknownEvent(slice_ascii(bytes, index, bytes.length())),
        bytes.length(),
      )
    }
  }
  let pasted = @encoding/utf8.decode(bytes[start:end]) catch {
    _ => slice_ascii(bytes, start, end)
  }
  Parsed(Paste(pasted), end + "\u{1b}[201~".length())
}

///|
fn parse_sgr_mouse(body : String, terminator : Char) -> Event {
  let parts = split_char(body[1:].to_owned(), ';')
  if parts.length() != 3 {
    return UnknownEvent("\u{1b}[\{body}\{terminator}")
  }
  let code = @string.parse_int(parts[0]) catch {
    _ => return UnknownEvent(body)
  }
  let x = @string.parse_int(parts[1]) catch { _ => return UnknownEvent(body) }
  let y = @string.parse_int(parts[2]) catch { _ => return UnknownEvent(body) }
  Mouse({
    button: mouse_button(code),
    action: if terminator == 'm' {
      Release
    } else if (code & 32) != 0 {
      Drag
    } else {
      Press
    },
    x,
    y,
  })
}

///|
fn parse_csi_key(body : String, terminator : Char) -> Event? {
  match terminator {
    'A' | 'B' | 'C' | 'D' | 'H' | 'F' | 'P' | 'Q' | 'R' | 'S' =>
      parse_modified_final_key(body, terminator)
    'Z' => if body == "" { Some(Key(BackTab)) } else { None }
    'I' => if body == "" { Some(FocusGained) } else { None }
    'O' => if body == "" { Some(FocusLost) } else { None }
    '~' => parse_tilde_key(body)
    'u' => parse_kitty_key(body)
    _ => None
  }
}

///|
fn parse_modified_final_key(body : String, terminator : Char) -> Event? {
  let base = match terminator {
    'A' => Up
    'B' => Down
    'C' => Right
    'D' => Left
    'H' => Home
    'F' => End
    'P' => Function(1)
    'Q' => Function(2)
    'R' => Function(3)
    'S' => Function(4)
    _ => return None
  }
  if body == "" {
    Some(Key(base))
  } else {
    let parts = split_char(body, ';')
    if parts.length() < 2 {
      None
    } else {
      let modifiers = match parse_modifier_code(parts[parts.length() - 1]) {
        Some(value) => value
        None => return None
      }
      Some(Key(apply_modifiers(base, modifiers)))
    }
  }
}

///|
fn parse_tilde_key(body : String) -> Event? {
  let parts = split_char(body, ';')
  if parts.length() == 0 {
    return None
  }
  if parts[0] == "27" && parts.length() >= 3 {
    let modifiers = match parse_modifier_code(parts[1]) {
      Some(value) => value
      None => return None
    }
    let code = @string.parse_int(parts[2]) catch { _ => return None }
    return Some(Key(apply_modifiers(key_from_code(code), modifiers)))
  }
  let code = @string.parse_int(parts[0]) catch { _ => return None }
  let base = tilde_base_key(code)
  let key = match base {
    Some(value) => value
    None => return Some(UnknownEvent(body))
  }
  if parts.length() >= 2 {
    let modifiers = match parse_modifier_code(parts[1]) {
      Some(value) => value
      None => return None
    }
    Some(Key(apply_modifiers(key, modifiers)))
  } else {
    Some(Key(key))
  }
}

///|
fn parse_kitty_key(body : String) -> Event? {
  let parts = split_char(body, ';')
  if parts.length() == 0 {
    return None
  }
  let code = @string.parse_int(parts[0]) catch { _ => return None }
  let key = key_from_code(code)
  if parts.length() >= 2 {
    let modifiers = match parse_modifier_code(parts[1]) {
      Some(value) => value
      None => return None
    }
    Some(Key(apply_modifiers(key, modifiers)))
  } else {
    Some(Key(key))
  }
}

///|
fn tilde_base_key(code : Int) -> Key? {
  match code {
    1 | 7 => Some(Home)
    2 => Some(Unknown("insert"))
    3 => Some(Delete)
    4 | 8 => Some(End)
    5 => Some(PageUp)
    6 => Some(PageDown)
    11 => Some(Function(1))
    12 => Some(Function(2))
    13 => Some(Function(3))
    14 => Some(Function(4))
    15 => Some(Function(5))
    17 => Some(Function(6))
    18 => Some(Function(7))
    19 => Some(Function(8))
    20 => Some(Function(9))
    21 => Some(Function(10))
    23 => Some(Function(11))
    24 => Some(Function(12))
    _ => None
  }
}

///|
fn key_from_code(code : Int) -> Key {
  match code {
    9 => Tab
    13 => Enter
    27 => Escape
    127 => Backspace
    _ =>
      if code >= 32 && code <= 0x10ffff {
        Char(String::make(1, Int::unsafe_to_char(code)))
      } else {
        Unknown(code.to_string())
      }
  }
}

///|
fn parse_modifier_code(value : String) -> KeyModifiers? {
  let code = @string.parse_int(value) catch { _ => return None }
  let mask = Int::max(0, code - 1)
  Some({
    shift: (mask & 1) != 0,
    alt: (mask & 2) != 0,
    ctrl: (mask & 4) != 0,
    super_key: (mask & 8) != 0,
    hyper: (mask & 16) != 0,
    meta: (mask & 32) != 0,
  })
}

///|
fn apply_modifiers(key : Key, modifiers : KeyModifiers) -> Key {
  if modifiers == KeyModifiers::none() {
    key
  } else {
    Modified(key, modifiers)
  }
}

///|
fn mouse_button(code : Int) -> MouseButton {
  if (code & 64) != 0 {
    if (code & 1) == 0 {
      WheelUp
    } else {
      WheelDown
    }
  } else {
    match code & 3 {
      0 => Primary
      1 => Middle
      2 => Secondary
      n => Other(n)
    }
  }
}

///|
fn take_utf8_char(bytes : Bytes, index : Int) -> (String, Int) {
  let first = bytes[index].to_int()
  let len = utf8_char_len(first)
  let end = Int::min(bytes.length(), index + len)
  let text = @encoding/utf8.decode(bytes[index:end]) catch {
    _ => slice_ascii(bytes, index, end)
  }
  (text, end)
}

///|
fn utf8_char_len(first : Int) -> Int {
  if first < 0x80 {
    1
  } else if first >= 0xc2 && first < 0xe0 {
    2
  } else if first >= 0xe0 && first < 0xf0 {
    3
  } else if first >= 0xf0 && first < 0xf5 {
    4
  } else {
    1
  }
}

///|
fn is_csi_final(byte : Byte) -> Bool {
  let value = byte.to_int()
  value >= 0x40 && value <= 0x7e
}

///|
fn split_char(value : String, sep : Char) -> Array[String] {
  let out : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < value.length() {
    if value.code_unit_at(index) == Int::to_uint16(sep.to_int()) {
      out.push(value[start:index].to_owned())
      start = index + 1
    }
    index += 1
  }
  out.push(value[start:].to_owned())
  out
}

///|
fn starts_with_ascii(bytes : Bytes, index : Int, value : String) -> Bool {
  if index + value.length() > bytes.length() {
    return false
  }
  for offset in 0..<value.length() {
    if value.code_unit_at(offset) !=
      Int::to_uint16(bytes[index + offset].to_int()) {
      return false
    }
  }
  true
}

///|
fn slice_ascii(bytes : Bytes, start : Int, end : Int) -> String {
  let out = StringBuilder::new()
  for index in start..<end {
    let byte = bytes[index].to_int()
    if byte >= 32 && byte <= 126 {
      out.write_char(Int::unsafe_to_char(byte))
    } else {
      out.write_string("\\x")
      out.write_string(byte.to_string(radix=16))
    }
  }
  out.to_string()
}

///|
fn concat_bytes(left : Bytes, right : Bytes) -> Bytes {
  let out = FixedArray::make(left.length() + right.length(), b'\x00')
  out.blit_from_bytes(0, left, 0, left.length())
  out.blit_from_bytes(left.length(), right, 0, right.length())
  Bytes::from_array(out)
}
