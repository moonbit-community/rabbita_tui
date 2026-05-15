///|
pub(all) struct Size {
  width : Int
  height : Int
} derive(Eq, Debug)

///|
pub(all) struct Point {
  x : Int
  y : Int
} derive(Eq, Debug)

///|
pub(all) enum Color {
  Default
  Ansi(Int)
  Rgb(Int, Int, Int)
} derive(Eq, Debug)

///|
pub(all) enum Align {
  Start
  Center
  End
} derive(Eq, Debug)

///|
pub(all) struct Edge {
  top : Int
  right : Int
  bottom : Int
  left : Int
} derive(Eq, Debug)

///|
pub fn Edge::all(value : Int) -> Edge {
  { top: value, right: value, bottom: value, left: value }
}

///|
pub fn Edge::zero() -> Edge {
  Edge::all(0)
}

///|
pub fn Edge::xy(x : Int, y : Int) -> Edge {
  { top: y, right: x, bottom: y, left: x }
}

///|
pub fn Edge::horizontal(value : Int) -> Edge {
  { top: 0, right: value, bottom: 0, left: value }
}

///|
pub fn Edge::vertical(value : Int) -> Edge {
  { top: value, right: 0, bottom: value, left: 0 }
}

///|
pub fn Edge::trbl(top : Int, right : Int, bottom : Int, left : Int) -> Edge {
  { top, right, bottom, left }
}

///|
pub(all) enum Border {
  NoBorder
  Normal
  Rounded
  Square
  Double
  Thick
} derive(Eq, Debug)

///|
pub(all) struct Style {
  fg : Color
  bg : Color
  bold : Bool
  dim : Bool
  italic : Bool
  underline : Bool
  blink : Bool
  reverse : Bool
  strikethrough : Bool
  width : Int
  height : Int
  padding : Edge
  border : Border
  align_horizontal : Align
  align_vertical : Align
  align_set : Bool
  clip_width : Int
  clip_height : Int
} derive(Eq, Debug)

///|
pub fn Style::default() -> Style {
  {
    fg: Default,
    bg: Default,
    bold: false,
    dim: false,
    italic: false,
    underline: false,
    blink: false,
    reverse: false,
    strikethrough: false,
    width: -1,
    height: -1,
    padding: Edge::zero(),
    border: NoBorder,
    align_horizontal: Start,
    align_vertical: Start,
    align_set: false,
    clip_width: -1,
    clip_height: -1,
  }
}

///|
pub fn Style::fg(self : Style, color : Color) -> Style {
  { ..self, fg: color }
}

///|
pub fn Style::bg(self : Style, color : Color) -> Style {
  { ..self, bg: color }
}

///|
pub fn Style::bold(self : Style) -> Style {
  { ..self, bold: true }
}

///|
pub fn Style::dim(self : Style) -> Style {
  { ..self, dim: true }
}

///|
pub fn Style::italic(self : Style) -> Style {
  { ..self, italic: true }
}

///|
pub fn Style::underline(self : Style) -> Style {
  { ..self, underline: true }
}

///|
pub fn Style::blink(self : Style) -> Style {
  { ..self, blink: true }
}

///|
pub fn Style::reverse(self : Style) -> Style {
  { ..self, reverse: true }
}

///|
pub fn Style::strikethrough(self : Style) -> Style {
  { ..self, strikethrough: true }
}

///|
pub fn Style::width(self : Style, width : Int) -> Style {
  { ..self, width, }
}

///|
pub fn Style::height(self : Style, height : Int) -> Style {
  { ..self, height, }
}

///|
pub fn Style::size(
  self : Style,
  width? : Int = -1,
  height? : Int = -1,
) -> Style {
  { ..self, width, height }
}

///|
pub fn Style::padding(self : Style, edge : Edge) -> Style {
  { ..self, padding: edge }
}

///|
pub fn Style::border(self : Style, kind? : Border = Rounded) -> Style {
  { ..self, border: kind }
}

///|
pub fn Style::align(
  self : Style,
  horizontal? : Align = Start,
  vertical? : Align = Start,
) -> Style {
  {
    ..self,
    align_horizontal: horizontal,
    align_vertical: vertical,
    align_set: true,
  }
}

///|
pub fn Style::clip(self : Style, size : Size) -> Style {
  { ..self, clip_width: size.width, clip_height: size.height }
}

///|
pub fn Style::merge(self : Style, next : Style) -> Style {
  {
    fg: if next.fg == Default {
      self.fg
    } else {
      next.fg
    },
    bg: if next.bg == Default {
      self.bg
    } else {
      next.bg
    },
    bold: self.bold || next.bold,
    dim: self.dim || next.dim,
    italic: self.italic || next.italic,
    underline: self.underline || next.underline,
    blink: self.blink || next.blink,
    reverse: self.reverse || next.reverse,
    strikethrough: self.strikethrough || next.strikethrough,
    width: if next.width >= 0 {
      next.width
    } else {
      self.width
    },
    height: if next.height >= 0 {
      next.height
    } else {
      self.height
    },
    padding: if next.padding == Edge::zero() {
      self.padding
    } else {
      next.padding
    },
    border: if next.border == NoBorder {
      self.border
    } else {
      next.border
    },
    align_horizontal: if next.align_set {
      next.align_horizontal
    } else {
      self.align_horizontal
    },
    align_vertical: if next.align_set {
      next.align_vertical
    } else {
      self.align_vertical
    },
    align_set: self.align_set || next.align_set,
    clip_width: if next.clip_width >= 0 {
      next.clip_width
    } else {
      self.clip_width
    },
    clip_height: if next.clip_height >= 0 {
      next.clip_height
    } else {
      self.clip_height
    },
  }
}

///|
enum Node {
  Empty
  Text(String, Style)
  Fragment(Array[Node])
  VStack(Array[Node], Int)
  HStack(Array[Node], Int)
  Pad(Node, Edge)
  Styled(Node, Style)
  Bordered(Node, Border, Style)
  Clip(Node, Size)
  Sized(Node, Size)
  Aligned(Node, Align, Align)
  Placed(Node, Size, Align, Align)
  Fill(String, Style)
} derive(Eq, Debug)

///|
pub(all) enum Key {
  Char(String)
  Enter
  Escape
  Backspace
  Tab
  BackTab
  Up
  Down
  Left
  Right
  Home
  End
  Delete
  PageUp
  PageDown
  Ctrl(String)
  Alt(String)
  Modified(Key, KeyModifiers)
  Function(Int)
  Unknown(String)
} derive(Eq, Debug)

///|
pub(all) struct KeyModifiers {
  shift : Bool
  alt : Bool
  ctrl : Bool
  super_key : Bool
  hyper : Bool
  meta : Bool
} derive(Eq, Debug)

///|
pub fn KeyModifiers::none() -> KeyModifiers {
  {
    shift: false,
    alt: false,
    ctrl: false,
    super_key: false,
    hyper: false,
    meta: false,
  }
}

///|
pub fn KeyModifiers::shift(self : KeyModifiers, enabled : Bool) -> KeyModifiers {
  { ..self, shift: enabled }
}

///|
pub fn KeyModifiers::alt(self : KeyModifiers, enabled : Bool) -> KeyModifiers {
  { ..self, alt: enabled }
}

///|
pub fn KeyModifiers::ctrl(self : KeyModifiers, enabled : Bool) -> KeyModifiers {
  { ..self, ctrl: enabled }
}

///|
pub fn KeyModifiers::super_key(
  self : KeyModifiers,
  enabled : Bool,
) -> KeyModifiers {
  { ..self, super_key: enabled }
}

///|
pub fn KeyModifiers::hyper(self : KeyModifiers, enabled : Bool) -> KeyModifiers {
  { ..self, hyper: enabled }
}

///|
pub fn KeyModifiers::meta(self : KeyModifiers, enabled : Bool) -> KeyModifiers {
  { ..self, meta: enabled }
}

///|
pub(all) enum MouseButton {
  Primary
  Middle
  Secondary
  WheelUp
  WheelDown
  Other(Int)
} derive(Eq, Debug)

///|
pub(all) enum MouseAction {
  Press
  Release
  Drag
} derive(Eq, Debug)

///|
pub(all) enum MouseMode {
  MouseOff
  MouseCellMotion
  MouseButtonMotion
  MouseAllMotion
} derive(Eq, Debug)

///|
pub(all) struct Mouse {
  button : MouseButton
  action : MouseAction
  x : Int
  y : Int
} derive(Eq, Debug)

///|
pub(all) enum Event {
  Key(Key)
  Mouse(Mouse)
  Resize(Size)
  FocusGained
  FocusLost
  Paste(String)
  Tick(Int64)
  Quit
  UnknownEvent(String)
} derive(Eq, Debug)

///|
pub(all) enum ProgramExit {
  ProgramQuit
  ProgramCancelled
  ProgramTimedOut
} derive(Eq, Debug)

///|
pub(all) struct ProgramRuntimeResult[Model] {
  model : Model
  exit : ProgramExit
} derive(Eq, Debug)

///|
pub(all) struct CancelToken {
  mut cancelled : Bool
} derive(Debug)

///|
pub fn CancelToken::new() -> CancelToken {
  { cancelled: false }
}

///|
pub fn CancelToken::cancel(self : CancelToken) -> Unit {
  self.cancelled = true
}

///|
pub fn CancelToken::is_cancelled(self : CancelToken) -> Bool {
  self.cancelled
}

///|
pub(all) struct ProgramOptions {
  alternate_screen : Bool
  mouse_mode : MouseMode
  bracketed_paste : Bool
  focus_events : Bool
  hide_cursor : Bool
  renderer_enabled : Bool
  renderer_fps : Int
  max_messages_per_frame : Int
  resize_poll_millis : Int
} derive(Eq, Debug)

///|
pub fn ProgramOptions::default() -> ProgramOptions {
  {
    alternate_screen: true,
    mouse_mode: MouseOff,
    bracketed_paste: false,
    focus_events: false,
    hide_cursor: true,
    renderer_enabled: true,
    renderer_fps: 60,
    max_messages_per_frame: 64,
    resize_poll_millis: 100,
  }
}

///|
pub fn ProgramOptions::inline() -> ProgramOptions {
  {
    alternate_screen: false,
    mouse_mode: MouseOff,
    bracketed_paste: false,
    focus_events: false,
    hide_cursor: false,
    renderer_enabled: true,
    renderer_fps: 60,
    max_messages_per_frame: 64,
    resize_poll_millis: 100,
  }
}

///|
pub fn ProgramOptions::alternate_screen(
  self : ProgramOptions,
  enabled : Bool,
) -> ProgramOptions {
  { ..self, alternate_screen: enabled }
}

///|
pub fn ProgramOptions::mouse(
  self : ProgramOptions,
  mode : MouseMode,
) -> ProgramOptions {
  { ..self, mouse_mode: mode }
}

///|
pub fn ProgramOptions::bracketed_paste(
  self : ProgramOptions,
  enabled : Bool,
) -> ProgramOptions {
  { ..self, bracketed_paste: enabled }
}

///|
pub fn ProgramOptions::focus_events(
  self : ProgramOptions,
  enabled : Bool,
) -> ProgramOptions {
  { ..self, focus_events: enabled }
}

///|
pub fn ProgramOptions::hide_cursor(
  self : ProgramOptions,
  enabled : Bool,
) -> ProgramOptions {
  { ..self, hide_cursor: enabled }
}

///|
pub fn ProgramOptions::renderer(
  self : ProgramOptions,
  enabled : Bool,
) -> ProgramOptions {
  { ..self, renderer_enabled: enabled }
}

///|
pub fn ProgramOptions::without_renderer(
  self : ProgramOptions,
) -> ProgramOptions {
  { ..self, renderer_enabled: false }
}

///|
pub fn ProgramOptions::fps(
  self : ProgramOptions,
  value : Int,
) -> ProgramOptions {
  { ..self, renderer_fps: Int::max(0, value) }
}

///|
pub fn ProgramOptions::max_messages_per_frame(
  self : ProgramOptions,
  value : Int,
) -> ProgramOptions {
  { ..self, max_messages_per_frame: Int::max(1, value) }
}

///|
pub fn ProgramOptions::resize_poll_millis(
  self : ProgramOptions,
  value : Int,
) -> ProgramOptions {
  { ..self, resize_poll_millis: Int::max(16, value) }
}

///|
pub(all) enum TerminalCommand {
  QuitProgram
  Repaint
  Print(String)
  PrintLine(String)
  PrintErr(String)
  PrintErrLine(String)
  ClearScreen
  EnterAlternateScreen
  LeaveAlternateScreen
  HideCursor
  ShowCursor
  EnableMouse(MouseMode)
  DisableMouse
  EnableBracketedPaste
  DisableBracketedPaste
  EnableFocusEvents
  DisableFocusEvents
  SetWindowTitle(String)
} derive(Eq, Debug)

///|
pub(all) suberror TerminalError {
  UnsupportedPlatform
  NotATty(String)
  NativeError(String)
} derive(Eq, Debug)
