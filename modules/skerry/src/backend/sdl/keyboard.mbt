///|
// SDL reports a key's text separately. Preserve command consumption through
// focus changes and repeats, while leaving independent text/IME commits intact.
priv struct KeyboardInput {
  handled : @hashset.HashSet[(UInt32, Int32)]
  mut pending_text : (UInt32, Int32)?
}

///|
fn KeyboardInput::KeyboardInput() -> KeyboardInput {
  { handled: @hashset.HashSet([]), pending_text: None, }
}

///|
fn KeyboardInput::key_down(
  self : Self,
  event : @sdl_sys.KeyboardEvent,
  handled : Bool,
) -> Unit {
  let key = (event.which(), event.scancode())
  // SDL command keycodes are outside Unicode. Control characters such as Tab
  // also produce no text and must not suppress an independent commit.
  let produces_text = event
    .key()
    .reinterpret_as_int()
    .to_char()
    .map(character => !character.is_control())
    .unwrap_or(false)
  if !event.repeat() {
    self.handled.remove(key)
  }
  if handled && produces_text {
    self.handled.add(key)
  }
  self.pending_text = if produces_text && self.handled.contains(key) {
    Some(key)
  } else {
    None
  }
}

///|
fn KeyboardInput::key_up(self : Self, event : @sdl_sys.KeyboardEvent) -> Unit {
  let key = (event.which(), event.scancode())
  self.handled.remove(key)
  if self.pending_text == Some(key) {
    self.pending_text = None
  }
}

///|
fn KeyboardInput::text_input(
  self : Self,
  root : @runtime.UiRoot,
  text : String,
) -> Bool {
  let prevented = self.pending_text is Some(_)
  // Apply consumption to this native key's text event, never to later commits
  // that can arrive independently of keyboard events (e.g. from an IME).
  self.pending_text = None
  !prevented && root.text_input(text)
}

///|
fn KeyboardInput::reset(self : Self) -> Unit {
  self.handled.clear()
  self.pending_text = None
}
