///|
fn OverlayState::toggle_after(
  self : OverlayState,
  anchor : NodeLifecycle,
  before : Bool,
) -> Unit {
  // Existing anchor behavior may change the model or detach its owner. That
  // explicit action takes precedence over the default trigger behavior.
  if anchor.phase is Mounted && self.open.peek() == before {
    self.change(!before)
  }
}

///|
fn overlay_click_anchor(anchor : View, state : OverlayState) -> View {
  let previous = anchor.node.events
  let lifecycle = anchor.node.lifecycle
  let click = scoped_callback(fn() {
    let before = state.open.peek()
    if previous.on_click is Some(action) {
      action()
    }
    state.toggle_after(lifecycle, before)
  })
  let key_down = scoped_handler(fn(event : @foundation.KeyEvent) {
    let before = state.open.peek()
    match (previous.on_key_down)(event) {
      KeyActivated => {
        if !event.repeat {
          state.toggle_after(lifecycle, before)
        }
        KeyActivated
      }
      KeyHandled => KeyHandled
      KeyIgnored =>
        match event.key {
          KeyEnter | KeySpace => {
            if !event.repeat && state.open.peek() == before {
              if previous.on_click is Some(action) {
                action()
              }
              state.toggle_after(lifecycle, before)
            }
            KeyActivated
          }
          _ => KeyIgnored
        }
    }
  })
  view_from_node({
    ..anchor.node,
    events: {
      ..previous,
      focusable: true,
      hit_testable: true,
      on_click: Some(click),
      on_key_down: key_down,
    },
  })
}
