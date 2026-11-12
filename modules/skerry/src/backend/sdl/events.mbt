///|
// One native event stream per window. Input geometry is queried lazily so
// resize and display-scale changes take effect on the next relevant event.
priv struct EventDispatcher {
  root : @runtime.UiRoot
  window_id : UInt32
  geometry : () -> InputGeometry raise
  keyboard : KeyboardInput
}

///|
fn EventDispatcher::EventDispatcher(
  root : @runtime.UiRoot,
  window_id~ : UInt32,
  geometry~ : () -> InputGeometry raise,
) -> EventDispatcher {
  { root, window_id, geometry, keyboard: KeyboardInput(), }
}

///|
fn EventDispatcher::text_input(self : Self, text : String) -> Bool {
  self.keyboard.text_input(self.root, text)
}

///|
priv struct PollResult {
  running : Bool
  handled_event : Bool
}

///|
fn EventDispatcher::poll(self : Self) -> PollResult raise {
  let root = self.root
  let mut running = true
  let mut handled_event = false
  let event = @sdl_sys.Event()
  while running && !root.is_disposed() && @sdl_sys.poll_event(event) {
    handled_event = true
    running = self.dispatch(event)
  }
  { running, handled_event, }
}

///|
// Use raw events so host focus loss retains its window ID on current SDL bindings.
fn EventDispatcher::dispatch(self : Self, event : @sdl_sys.Event) -> Bool raise {
  let root = self.root
  let keyboard = self.keyboard
  let window_id = self.window_id
  let geometry = self.geometry
  match event.event_type() {
    @sdl_sys.EVENT_QUIT => return false
    @sdl_sys.EVENT_SYSTEM_THEME_CHANGED => root.set_system_theme(system_theme())
    @sdl_sys.EVENT_WINDOW_CLOSE_REQUESTED =>
      if event.window().window_id() == window_id {
        keyboard.reset()
        root.focus_lost()
        return false
      }
    @sdl_sys.EVENT_WINDOW_FOCUS_LOST =>
      if event.window().window_id() == window_id {
        keyboard.reset()
        root.focus_lost()
      }
    @sdl_sys.EVENT_WINDOW_MOUSE_LEAVE =>
      if event.window().window_id() == window_id {
        root.pointer_leave()
      }
    @sdl_sys.EVENT_MOUSE_BUTTON_DOWN | @sdl_sys.EVENT_MOUSE_BUTTON_UP => {
      let button = event.button()
      if button.window_id() == window_id && button.button().to_int() == 1 {
        let point = @foundation.Point(
          x=button.x().to_double(),
          y=button.y().to_double(),
        )
        let phase : @foundation.PointerPhase = if event.event_type() ==
          @sdl_sys.EVENT_MOUSE_BUTTON_DOWN {
          PointerDown
        } else {
          PointerUp
        }
        dispatch_pointer(root, geometry(), point, phase)
      }
    }
    @sdl_sys.EVENT_MOUSE_MOTION => {
      let motion = event.motion()
      if motion.window_id() == window_id {
        dispatch_pointer(
          root,
          geometry(),
          Point(x=motion.x().to_double(), y=motion.y().to_double()),
          PointerMove,
        )
      }
    }
    @sdl_sys.EVENT_MOUSE_WHEEL => {
      let wheel = event.wheel()
      if wheel.window_id() == window_id {
        let coordinates = geometry()
        if coordinates.to_logical(
            Point(x=wheel.mouse_x().to_double(), y=wheel.mouse_y().to_double()),
          )
          is Some(point) {
          // SDL deltas are fractional wheel steps, independent of window DPI.
          // Scroll offsets and navigation steps use logical UI units.
          let direction = if wheel.direction() == @sdl_sys.MOUSEWHEEL_FLIPPED {
            -1.0
          } else {
            1.0
          }
          ignore(
            root.scroll_at(
              size=coordinates.logical_size,
              point~,
              delta=Point(
                x=wheel.x().to_double() * WHEEL_STEP_UNITS * direction,
                y=-wheel.y().to_double() * WHEEL_STEP_UNITS * direction,
              ),
            ),
          )
        }
      }
    }
    @sdl_sys.EVENT_KEY_DOWN => {
      let raw_key = event.key()
      if raw_key.window_id() == window_id {
        let key = @foundation.KeyEvent::{
          key: sdl_key(raw_key.key()),
          modifiers: sdl_key_modifiers(raw_key.mod()),
          repeat: raw_key.repeat(),
        }
        let handled = if handle_clipboard_shortcut(root, key) {
          true
        } else {
          match key.key {
            KeyTab
            | KeyArrowUp
            | KeyArrowDown
            | KeyArrowLeft
            | KeyArrowRight
            | KeyPageUp
            | KeyPageDown
            | KeyHome
            | KeyEnd => {
              let coordinates = geometry()
              root.key_down(key, size=coordinates.logical_size)
            }
            _ => root.key_down(key)
          }
        }
        keyboard.key_down(raw_key, handled)
      }
    }
    @sdl_sys.EVENT_KEY_UP => {
      let raw_key = event.key()
      if raw_key.window_id() == window_id {
        keyboard.key_up(raw_key)
        ignore(
          root.key_up(
            KeyEvent(
              key=sdl_key(raw_key.key()),
              modifiers=sdl_key_modifiers(raw_key.mod()),
            ),
          ),
        )
      }
    }
    @sdl_sys.EVENT_TEXT_INPUT =>
      if event.text().window_id() == window_id {
        ignore(self.text_input(@utf8.decode_lossy(event.text().text())))
      }
    _ => ()
  }
  true
}

///|
fn system_theme() -> @runtime.ColorScheme? {
  match @sdl_sys.get_system_theme() {
    @sdl_sys.SYSTEM_THEME_LIGHT => Some(Light)
    @sdl_sys.SYSTEM_THEME_DARK => Some(Dark)
    _ => None
  }
}

///|
const WHEEL_STEP_UNITS : Double = 40.0

///|
fn dispatch_pointer(
  root : @runtime.UiRoot,
  geometry : InputGeometry,
  point : @foundation.Point,
  phase : @foundation.PointerPhase,
) -> Unit {
  guard geometry.to_logical(point) is Some(point) else {
    ignore(root.pointer_cancel())
    return
  }
  let size = geometry.logical_size
  match phase {
    PointerDown => ignore(root.pointer_down(size~, point~))
    PointerMove => ignore(root.pointer_move(size~, point~))
    PointerUp => ignore(root.pointer_up(size~, point~))
  }
}

///|
fn sdl_key(keycode : UInt32) -> @foundation.Key {
  match keycode {
    0x00000008 => KeyBackspace
    0x0000007F => KeyDelete
    0x0000001B => KeyEscape
    0x00000009 => KeyTab
    0x0000000D => KeyEnter
    0x00000020 => KeySpace
    0x4000004A => KeyHome
    0x4000004D => KeyEnd
    0x4000004F => KeyArrowRight
    0x40000050 => KeyArrowLeft
    // SDL_Keycode values from SDL_keycode.h.
    0x40000052 => KeyArrowUp
    0x40000051 => KeyArrowDown
    0x4000004B => KeyPageUp
    0x4000004E => KeyPageDown
    0x00000061 | 0x00000041 => KeyA
    0x00000063 | 0x00000043 => KeyC
    0x00000076 | 0x00000056 => KeyV
    0x00000078 | 0x00000058 => KeyX
    _ => KeyUnknown
  }
}

///|
fn sdl_key_modifiers(modifiers : UInt32) -> @foundation.KeyModifiers {
  {
    shift: (modifiers & 0x0003) != 0,
    control: (modifiers & 0x00C0) != 0,
    alt: (modifiers & 0x0300) != 0,
    meta: (modifiers & 0x0C00) != 0,
  }
}
