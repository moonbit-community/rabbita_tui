
# Stateless Widget

API:

```
pub fn widget(prop1~ : Type1, prop2? : Type2, on_event1? : Cmd, on_event2? : Emit[Payload], childs : Array[Node]) -> Node 
```

Usage:

```
fn view(emit, model) -> Node {
  widget(prop1=..., prop2=..., on_event1=emit(AppMsg1), on_event2=x => emit(AppMsg2(x))) <| [
    ...
  ]
}
```

# Stateful Widget

API:

```
enum WidgetMsg {...}
struct Widget {...}
pub fn Widget::view(self : Self, prop1~ : Type1, prop2? : Type2, on_event1? : Cmd, on_event2? : Emit[Payload], childs : Array[Node]) -> Node
pub fn Widget::update(self : Self, msg : WidgetMsg) -> Self
pub fn Widget::Widget(state1~ : Type1, state2? : Type2) -> Widget
```

Usage:

```
enum Msg {
  ...
  GotWidgetMsg(WidgetMsg)
}

cell(
  model = { ..., s: Widget(state1=...) },
  view = (emit, model) => model.s.view(...) <| [...],
  update = (emit, msg, model) => match msg {
    ...
    GotWidgetMsg(msg) => model.s.update(msg)
  } 
)
```


