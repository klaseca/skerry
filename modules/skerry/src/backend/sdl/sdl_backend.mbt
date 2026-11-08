///|
const TEXTURE_CAPACITY_STEP : Int32 = 256

///|
pub fn run(app : @runtime.App, renderer : &@backend.Renderer) -> Unit raise {
  let options = app.options()
  @sdl_lib.init_lib(@sdl_lib.INIT_VIDEO)
  defer @sdl_lib.quit()
  let window = @sdl_lib.Window(
    title=options.title,
    width=options.width,
    height=options.height,
    resizable=true,
    high_pixel_density=true,
    hidden=true,
  )
  defer window.destroy()
  let initial_scale = window.display_scale().to_double()
  let density = window.pixel_density().to_double()
  let width = initial_window_dimension(options.width, initial_scale, density)
  let height = initial_window_dimension(options.height, initial_scale, density)
  if width != options.width || height != options.height {
    window.set_size(width~, height~)
  }
  window.start_text_input()
  defer (fn() { window.stop_text_input() catch { _ => () } })()
  let sdl_renderer = @sdl_lib.Renderer(window, name="software")
  defer sdl_renderer.destroy()
  let root = app.mount(
    text_layout_system=renderer.text_layout_system(),
    system_theme?=system_theme(),
  )
  defer root.dispose()
  guard !root.is_disposed() else { return }
  let state = SdlAppState(root, sdl_renderer, renderer, options.clear, display_scale=() => {
    window.display_scale().to_double()
  })
  defer state.destroy()
  root.set_wakeup(fn() { state.wakeup() })
  state.drain_actions()
  state.check_error()
  state.sync_frame()
  let listeners = state.watch_window(window)
  defer (fn() {
    for listener in listeners {
      listener.dispose()
    }
  })()
  guard !root.is_disposed() else { return }
  window.show()
  let event = @sdl_sys.Event()
  for running = true; running && !root.is_disposed(); {
    let poll_result = poll_events(root, window, sdl_renderer, running)
    state.check_error()
    guard poll_result.running && !root.is_disposed() else { break }
    state.drain_actions()
    state.check_error()
    guard !root.is_disposed() else { break }
    state.sync_frame(allow_shrink=!poll_result.handled_event)
    state.check_error()
    guard !root.is_disposed() else { break }
    if !state.prepare_wait() {
      // An update during paint belongs to the next iteration, without waiting
      // for another input event or recursively painting the same root.
      continue true
    }
    let received = state.wait_for_event(event)
    state.check_error()
    guard !root.is_disposed() else { break }
    if !received {
      // A timer deadline elapsed. Run due actions on the next pass; the event
      // buffer still contains an older event and must not be dispatched again.
      continue true
    }
    let running = dispatch_event(root, event, window_id=window.id(), geometry=() => {
      input_geometry(sdl_renderer, window)
    })
    continue running
  }
}

///|
priv struct PollResult {
  running : Bool
  handled_event : Bool
}

///|
priv struct SdlAppState {
  root : @runtime.UiRoot
  sdl_renderer : @sdl_lib.Renderer
  renderer : &@backend.Renderer
  clear : @foundation.Color?
  display_scale : () -> Double raise
  mut texture_width : Int32
  mut texture_height : Int32
  mut frame_width : Int32
  mut frame_height : Int32
  mut frame_scale : Double
  mut has_frame : Bool
  mut frame_revision : Int32
  mut pending_error : Error?
  mut texture : @sdl_lib.Texture
  mut drawing : Bool
  mut redraw_pending : Bool
  wakeup_event_type : UInt32
}

///|
fn SdlAppState::SdlAppState(
  root : @runtime.UiRoot,
  sdl_renderer : @sdl_lib.Renderer,
  renderer : &@backend.Renderer,
  clear : @foundation.Color?,
  display_scale~ : () -> Double raise,
) -> SdlAppState raise {
  let size = sdl_renderer.output_size()
  let width = size.width.max(1)
  let height = size.height.max(1)
  let wakeup_event_type = @sdl_sys.register_events(1)
  guard wakeup_event_type != 0 else {
    raise @sdl_lib.SdlError("SDL_RegisterEvents failed for the UI dispatcher")
  }
  {
    root,
    sdl_renderer,
    renderer,
    clear,
    display_scale,
    texture_width: width,
    texture_height: height,
    frame_width: width,
    frame_height: height,
    frame_scale: 1.0,
    has_frame: false,
    frame_revision: 0,
    pending_error: None,
    texture: create_texture(sdl_renderer, width, height),
    drawing: false,
    redraw_pending: false,
    wakeup_event_type,
  }
}

///|
fn SdlAppState::watch_window(
  self : SdlAppState,
  window : @sdl_lib.Window,
) -> Array[@sdl_lib.EventListener] raise {
  let listeners : Array[@sdl_lib.EventListener] = []
  errdefer (fn() {
    for listener in listeners {
      listener.dispose()
    }
  })()
  listeners.push(
    window.on(Exposed, fn(_) {
      self.present_cached_frame() catch {
        error => self.record_error(error)
      }
    }),
  )
  listeners.push(window.on(Resized, fn(_) { self.redraw_now() }))
  listeners.push(window.on(PixelSizeChanged, fn(_) { self.redraw_now() }))
  listeners.push(window.on(DisplayScaleChanged, fn(_) { self.redraw_now() }))
  listeners
}

///|
fn SdlAppState::record_error(self : SdlAppState, error : Error) -> Unit {
  if self.pending_error is None {
    self.pending_error = Some(error)
  }
}

///|
fn SdlAppState::check_error(self : SdlAppState) -> Unit raise {
  if self.pending_error is Some(error) {
    raise error
  }
}

///|
fn SdlAppState::wakeup(self : SdlAppState) -> Unit {
  let event = @sdl_sys.Event()
  event.set_event_type(self.wakeup_event_type)
  if !@sdl_sys.push_event(event) {
    self.record_error(
      @sdl_lib.SdlError("SDL_PushEvent failed for the UI dispatcher"),
    )
  }
}

///|
fn SdlAppState::drain_actions(self : SdlAppState) -> Unit {
  guard !self.drawing else { return }
  // Modal resize callbacks can arrive synchronously from an action. Defer
  // their redraw until the whole action batch and its reactive updates finish.
  self.drawing = true
  defer self.finish_drawing()
  self.root.drain_actions()
}

///|
fn SdlAppState::prepare_wait(self : SdlAppState) -> Bool raise {
  self.check_error()
  guard !self.root.is_disposed() &&
    !self.root.needs_frame() &&
    !self.root.has_pending_actions() else {
    return false
  }
  // Finish idle texture maintenance before blocking. Otherwise a large texture
  // retained after resize would only shrink when another input event arrives.
  self.sync_frame(allow_shrink=true)
  self.check_error()
  !self.root.is_disposed() &&
  !self.root.needs_frame() &&
  !self.root.has_pending_actions()
}

///|
fn SdlAppState::wait_for_event(
  self : SdlAppState,
  event : @sdl_sys.Event,
) -> Bool raise {
  let timeout = self.root.next_action_delay().unwrap_or(-1)
  let received = @sdl_sys.wait_event_timeout(event, timeout)
  if !received && timeout < 0 {
    raise @sdl_lib.SdlError(
      "SDL_WaitEventTimeout failed: \{@utf8.decode_lossy(@sdl_sys.get_error())}",
    )
  }
  received
}

///|
fn SdlAppState::sync_frame(
  self : SdlAppState,
  allow_shrink~ : Bool = false,
) -> Unit raise {
  guard !self.root.is_disposed() else { return }
  guard !self.drawing else {
    self.redraw_pending = true
    return
  }
  self.drawing = true
  defer self.finish_drawing()
  let size = self.sdl_renderer.output_size()
  let width = size.width.max(1)
  let height = size.height.max(1)
  let scale = (self.display_scale)()
  let resized = self.sync_texture_size(width, height, allow_shrink)
  if resized ||
    !self.has_frame ||
    width != self.frame_width ||
    height != self.frame_height ||
    scale != self.frame_scale ||
    self.root.dirty() != Clean {
    render_root_to_texture(
      self.renderer,
      self.root,
      self.texture,
      width,
      height,
      self.clear.unwrap_or(self.root.theme().resolve(@style.surface_token)),
      scale~,
    )
    guard !self.root.is_disposed() else { return }
    self.frame_width = width
    self.frame_height = height
    self.frame_scale = scale
    self.frame_revision = self.root.paint_revision()
    self.has_frame = true
    present_texture(
      self.sdl_renderer,
      self.texture,
      source_width=width,
      source_height=height,
      width~,
      height~,
    )
    self.root.record_present(self.frame_revision)
  }
}

///|
fn SdlAppState::redraw_now(self : SdlAppState) -> Unit {
  if self.drawing {
    self.redraw_pending = true
    return
  }
  // SDL can report both logical and pixel-size changes for one resize.
  // sync_frame redraws for a new output size or pending UI work.
  self.sync_frame() catch {
    error => self.record_error(error)
  }
}

///|
fn SdlAppState::present_cached_frame(self : SdlAppState) -> Unit raise {
  if !self.has_frame || self.drawing || self.root.is_disposed() {
    return
  }
  if (self.display_scale)() != self.frame_scale {
    self.sync_frame()
    return
  }
  self.drawing = true
  defer self.finish_drawing()
  let size = self.sdl_renderer.output_size()
  present_texture(
    self.sdl_renderer,
    self.texture,
    source_width=self.frame_width,
    source_height=self.frame_height,
    width=size.width.max(1),
    height=size.height.max(1),
  )
  self.root.record_present(self.frame_revision)
}

///|
fn SdlAppState::finish_drawing(self : SdlAppState) -> Unit {
  self.drawing = false
  if self.redraw_pending {
    self.redraw_pending = false
    self.root.mark_paint_dirty()
  }
}

///|
fn SdlAppState::sync_texture_size(
  self : SdlAppState,
  width : Int32,
  height : Int32,
  allow_shrink : Bool,
) -> Bool raise {
  let shrink = allow_shrink &&
    (
      self.texture_width - width >= TEXTURE_CAPACITY_STEP ||
      self.texture_height - height >= TEXTURE_CAPACITY_STEP
    )
  let texture_width = if shrink {
    width
  } else {
    grow_capacity(self.texture_width, width)
  }
  let texture_height = if shrink {
    height
  } else {
    grow_capacity(self.texture_height, height)
  }
  if texture_width == self.texture_width &&
    texture_height == self.texture_height {
    false
  } else {
    // Keep the current frame intact if allocating its replacement fails.
    let texture = create_texture(
      self.sdl_renderer,
      texture_width,
      texture_height,
    )
    let old_texture = self.texture
    self.texture = texture
    self.texture_width = texture_width
    self.texture_height = texture_height
    self.has_frame = false
    old_texture.destroy()
    true
  }
}

///|
fn grow_capacity(current : Int32, required : Int32) -> Int32 {
  if required <= current {
    current
  } else {
    let remainder = required % TEXTURE_CAPACITY_STEP
    if remainder == 0 {
      required
    } else {
      let extra = TEXTURE_CAPACITY_STEP - remainder
      if required > @int.MAX_VALUE - extra {
        required
      } else {
        required + extra
      }
    }
  }
}

///|
fn SdlAppState::destroy(self : SdlAppState) -> Unit {
  self.root.set_wakeup(fn() { () })
  self.has_frame = false
  self.texture.destroy()
}

///|
fn poll_events(
  root : @runtime.UiRoot,
  window : @sdl_lib.Window,
  renderer : @sdl_lib.Renderer,
  running : Bool,
) -> PollResult raise {
  let mut running = running
  let mut handled_event = false
  let window_id = window.id()
  let event = @sdl_sys.Event()
  while running && !root.is_disposed() && @sdl_sys.poll_event(event) {
    handled_event = true
    running = dispatch_event(root, event, window_id~, geometry=() => {
      input_geometry(renderer, window)
    })
  }
  { running, handled_event, }
}

///|
// Use raw events so host focus loss retains its window ID on current SDL bindings.
fn dispatch_event(
  root : @runtime.UiRoot,
  event : @sdl_sys.Event,
  window_id~ : UInt32,
  geometry~ : () -> InputGeometry raise,
) -> Bool raise {
  match event.event_type() {
    @sdl_sys.EVENT_QUIT => return false
    @sdl_sys.EVENT_SYSTEM_THEME_CHANGED => root.set_system_theme(system_theme())
    @sdl_sys.EVENT_WINDOW_CLOSE_REQUESTED =>
      if event.window().window_id() == window_id {
        root.focus_lost()
        return false
      }
    @sdl_sys.EVENT_WINDOW_FOCUS_LOST =>
      if event.window().window_id() == window_id {
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
        if !handle_clipboard_shortcut(root, key) {
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
              ignore(root.key_down(key, size=coordinates.logical_size))
            }
            _ => ignore(root.key_down(key))
          }
        }
      }
    }
    @sdl_sys.EVENT_KEY_UP => {
      let raw_key = event.key()
      if raw_key.window_id() == window_id {
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
        ignore(root.text_input(@utf8.decode_lossy(event.text().text())))
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

///|
fn create_texture(
  renderer : @sdl_lib.Renderer,
  width : Int32,
  height : Int32,
) -> @sdl_lib.Texture raise {
  let texture = renderer.create_texture(
    width~,
    height~,
    format=Bgra32,
    access=Streaming,
  )
  texture.set_blend_mode(NoBlend)
  texture
}

///|
fn render_root_to_texture(
  renderer : &@backend.Renderer,
  root : @runtime.UiRoot,
  texture : @sdl_lib.Texture,
  width : Int32,
  height : Int32,
  clear : @foundation.Color,
  scale~ : Double = 1.0,
) -> Unit raise {
  let pixels = Ref(@sdl_sys.Pointer::null())
  let pitch = Ref(0)
  if !@sdl_sys.lock_texture(
      texture.raw(),
      // The capacity can exceed the visible frame during resize. Lock only
      // the pixels we paint so SDL need not stage/upload the unused capacity.
      Rect(0, 0, width, height),
      true,
      pixels,
      pitch,
    ) {
    let message = @utf8.decode_lossy(@sdl_sys.get_error())
    if message == "" {
      raise @sdl_lib.SdlError("SDL_LockTexture failed")
    } else {
      raise @sdl_lib.SdlError("SDL_LockTexture failed: \{message}")
    }
  }
  defer @sdl_sys.unlock_texture(texture.raw())
  if pixels.val.is_null() {
    raise InvalidTextureMemory(width~, height~, row_bytes=pitch.val)
  }
  renderer.render(
    root,
    RasterTarget(
      memory=to_raster_memory(pixels.val),
      width~,
      height~,
      row_bytes=pitch.val,
      format=Bgra8888Premultiplied,
      scale~,
    ),
    clear,
  )
}

///|
#derive(Debug, Eq)
pub(all) suberror SdlBackendError {
  InvalidTextureMemory(width~ : Int32, height~ : Int32, row_bytes~ : Int32)
}

///|
pub extend SdlBackendError with Debug::{to_repr}

///|
pub extend SdlBackendError with Eq::{not_equal, equal}

///|
fn to_raster_memory(pointer : @sdl_sys.Pointer) -> @backend.RasterMemory = "%identity"

///|
fn present_texture(
  renderer : @sdl_lib.Renderer,
  texture : @sdl_lib.Texture,
  source_width~ : Int32,
  source_height~ : Int32,
  width~ : Int32,
  height~ : Int32,
) -> Unit raise {
  renderer.set_draw_color(@sdl_lib.Color::rgb(r=18, g=20, b=24))
  renderer.clear()
  renderer.render_texture(
    texture,
    src=FRect(
      x=0.0,
      y=0.0,
      w=Float::from_int(source_width),
      h=Float::from_int(source_height),
    ),
    dst=FRect(x=0.0, y=0.0, w=Float::from_int(width), h=Float::from_int(height)),
  )
  renderer.present()
}
