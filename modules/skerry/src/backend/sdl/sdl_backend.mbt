///|
pub fn run(
  app : @runtime.App,
  create_renderer : @backend.RendererFactory,
) -> Unit raise {
  @sdl_lib.init_lib(@sdl_lib.INIT_VIDEO)
  defer @sdl_lib.quit()
  let factory = SurfaceFactory(app.options())
  defer factory.dispose()
  let renderer = create_renderer(factory)
  defer renderer.dispose()
  guard factory.window is Some(window) else {
    raise @sdl_lib.SdlError(
      "Renderer did not request an SDL presentation surface",
    )
  }
  run_on_surface(app, window, renderer)
}

///|
/// Create the hidden, HiDPI-aware window used by the native host. The caller
/// owns it and must initialize SDL first.
fn create_window(options : @runtime.WindowOptions) -> @sdl_lib.Window raise {
  let window = @sdl_lib.Window(
    title=options.title,
    width=options.width,
    height=options.height,
    resizable=true,
    high_pixel_density=true,
    hidden=true,
  )
  errdefer window.destroy()
  let initial_scale = window.display_scale().to_double()
  let density = window.pixel_density().to_double()
  let width = initial_window_dimension(options.width, initial_scale, density)
  let height = initial_window_dimension(options.height, initial_scale, density)
  if width != options.width || height != options.height {
    window.set_size(width~, height~)
  }
  window
}

///|
/// Mount once after a complete rendering surface has been selected. Resources
/// are borrowed; application and rendering errors propagate to the caller.
fn run_on_surface(
  app : @runtime.App,
  window : @sdl_lib.Window,
  renderer : &@backend.Renderer,
) -> Unit raise {
  let options = app.options()
  window.start_text_input()
  defer (fn() { window.stop_text_input() catch { _ => () } })()
  let root = app.mount(
    text_layout_system=renderer.text_layout_system(),
    system_theme?=system_theme(),
    rendering={ backend: "SDL", renderer: renderer.name(), },
  )
  defer root.dispose()
  guard !root.is_disposed() else { return }
  let state = SdlAppState(root, renderer, options.clear, display_scale=() => {
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
  let dispatcher = EventDispatcher(root, window_id=window.id(), geometry=() => {
    input_geometry(renderer.surface(), window)
  })
  let event = @sdl_sys.Event()
  for running = true; running && !root.is_disposed(); {
    let poll_result = dispatcher.poll()
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
    let running = dispatcher.dispatch(event)
    continue running
  }
}

///|
priv struct SdlAppState {
  root : @runtime.UiRoot
  renderer : &@backend.Renderer
  surface : &@backend.Surface
  clear : @foundation.Color?
  display_scale : () -> Double raise
  mut frame_width : Int32
  mut frame_height : Int32
  mut frame_scale : Double
  mut has_frame : Bool
  mut frame_revision : Int32
  mut pending_error : Error?
  mut drawing : Bool
  mut redraw_pending : Bool
  wakeup_event_type : UInt32
}

///|
fn SdlAppState::SdlAppState(
  root : @runtime.UiRoot,
  renderer : &@backend.Renderer,
  clear : @foundation.Color?,
  display_scale~ : () -> Double raise,
) -> SdlAppState raise {
  let surface = renderer.surface()
  let size = surface.output_size()
  let width = size.width.max(1)
  let height = size.height.max(1)
  let wakeup_event_type = @sdl_sys.register_events(1)
  guard wakeup_event_type != 0 else {
    raise @sdl_lib.SdlError("SDL_RegisterEvents failed for the UI dispatcher")
  }
  {
    root,
    surface,
    renderer,
    clear,
    display_scale,
    frame_width: width,
    frame_height: height,
    frame_scale: 1.0,
    has_frame: false,
    frame_revision: 0,
    pending_error: None,
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
  let size = self.surface.output_size()
  let width = size.width.max(1)
  let height = size.height.max(1)
  let scale = (self.display_scale)()
  let resized = self.surface.resize(width, height, allow_shrink)
  if resized ||
    !self.has_frame ||
    width != self.frame_width ||
    height != self.frame_height ||
    scale != self.frame_scale ||
    self.root.dirty() != Clean {
    self.renderer.render(
      self.root,
      width,
      height,
      scale,
      self.clear.unwrap_or(self.root.theme().resolve(@style.surface_token)),
    )
    guard !self.root.is_disposed() else { return }
    self.frame_width = width
    self.frame_height = height
    self.frame_scale = scale
    self.frame_revision = self.root.paint_revision()
    self.has_frame = true
    self.surface.present(width, height)
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
  let size = self.surface.output_size()
  let width = size.width.max(1)
  let height = size.height.max(1)
  if (self.display_scale)() != self.frame_scale ||
    width != self.frame_width ||
    height != self.frame_height {
    self.sync_frame()
    return
  }
  let restored = {
    self.drawing = true
    defer self.finish_drawing()
    let restored = self.surface.restore(width, height)
    if restored {
      self.root.record_present(self.frame_revision)
    }
    restored
  }
  if !restored {
    // Reuse the layout when the surface cannot restore the previous frame.
    self.root.mark_paint_dirty()
    self.sync_frame()
  }
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
fn SdlAppState::destroy(self : SdlAppState) -> Unit {
  self.root.set_wakeup(fn() { () })
  self.has_frame = false
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
