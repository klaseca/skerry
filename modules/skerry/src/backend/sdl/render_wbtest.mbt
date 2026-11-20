///|
test "texture capacity rounding cannot overflow signed dimensions" {
  let last_aligned_capacity = @int.MAX_VALUE -
    @int.MAX_VALUE % TEXTURE_CAPACITY_STEP
  assert_eq(
    grow_capacity(1, TEXTURE_CAPACITY_STEP + 1),
    TEXTURE_CAPACITY_STEP * 2,
  )
  assert_eq(grow_capacity(1, last_aligned_capacity), last_aligned_capacity)
  assert_eq(
    grow_capacity(1, last_aligned_capacity + 1),
    last_aligned_capacity + 1,
  )
  assert_eq(grow_capacity(1, @int.MAX_VALUE), @int.MAX_VALUE)
}

///|
test "queued UI actions wake SDL and prevent waiting until they are drained" {
  let value = @reactive.signal("first")
  with_render_state(fn(_) { @view.text_of(value) }, (state, _, _) => {
    state.sync_frame()
    let event = @sdl_sys.Event()
    while @sdl_sys.poll_event(event) {
      ()
    }
    state.root.set_wakeup(fn() { state.wakeup() })
    assert_true(state.prepare_wait())
    ignore(state.root.post(fn() { value.set("second") }))
    ignore(state.root.post(fn() { value.set("third") }))
    assert_false(state.prepare_wait())
    assert_true(@sdl_sys.wait_event_timeout(event, 500))
    assert_eq(event.event_type(), state.wakeup_event_type)
    assert_false(@sdl_sys.poll_event(event))
    state.drain_actions()
    state.sync_frame()
    assert_eq(value.get(), "third")
    assert_eq(state.root.frame_stats().paint_count, 2)
    assert_true(state.prepare_wait())
  })
}

///|
test "SDL waits for a future timer and treats its timeout as normal completion" {
  let now = Ref(0.0)
  let value = @reactive.signal("first")
  with_render_state(
    fn(_) { @view.text_of(value) },
    (state, _, _) => {
      state.sync_frame()
      let event = @sdl_sys.Event()
      while @sdl_sys.poll_event(event) {
        ()
      }
      let calls = Ref(0)
      let cancel = state.root.post_delayed(1, fn() {
        calls.val += 1
        value.set("second")
      })
      assert_true(state.prepare_wait())
      assert_eq(state.root.next_action_delay(), Some(1))
      assert_false(state.wait_for_event(event))
      state.check_error()
      assert_eq(calls.val, 0)
      now.val = 1.0
      assert_false(state.prepare_wait())
      state.drain_actions()
      state.sync_frame()
      assert_eq(calls.val, 1)
      assert_eq(value.get(), "second")
      assert_eq(state.root.frame_stats().paint_count, 2)
      cancel()
      assert_true(state.prepare_wait())
      assert_eq(state.root.next_action_delay(), None)
    },
    clock=fn() { now.val },
  )
}

///|
test "a callback registered during paint uses that present without an extra frame" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let first = Ref(true)
  let calls = Ref(0)
  with_render_state(
    fn(_) {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          if first.val {
            first.val = false
            ignore(root_ref.val.unwrap().after_present(fn() { calls.val += 1 }))
          }
        }),
      )
    },
    (state, _, _) => {
      root_ref.val = Some(state.root)
      state.sync_frame()
      assert_eq(calls.val, 1)
      assert_eq(state.root.frame_stats().paint_count, 1)
      assert_eq(state.root.frame_stats().present_count, 1)
      assert_true(state.prepare_wait())
      state.present_cached_frame()
      assert_eq(calls.val, 1)
      assert_eq(state.root.frame_stats().paint_count, 1)
      assert_eq(state.root.frame_stats().present_count, 2)
    },
  )
}

///|
test "modal resize in a present callback redraws only the final batched state" {
  let value = @reactive.signal(0)
  let painted : Array[Int32] = []
  with_render_state(
    fn(_) {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) { painted.push(value.get()) }),
      )
    },
    (state, window, _) => {
      state.sync_frame()
      let listeners = state.watch_window(window)
      defer (fn() {
        for listener in listeners {
          listener.dispose()
        }
      })()
      ignore(
        state.root.after_present(fn() {
          value.set(1)
          window.set_size(width=180, height=90) catch {
            error => state.record_error(error)
          }
          value.set(2)
        }),
      )
      state.sync_frame()
      state.check_error()
      assert_eq(painted, [0, 0])
      assert_true(state.root.needs_frame())
      state.sync_frame()
      state.check_error()
      assert_eq(painted, [0, 0, 2])
      assert_false(state.root.needs_frame())
    },
  )
}

///|
test "synchronous resize during an action does not paint intermediate batch state" {
  let value = @reactive.signal(0)
  let painted : Array[Int32] = []
  with_render_state(
    fn(_) {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) { painted.push(value.get()) }),
      )
    },
    (state, window, _) => {
      let listener = window.on(Resized, fn(_) { state.redraw_now() })
      defer listener.dispose()
      state.sync_frame()
      ignore(
        state.root.post(fn() {
          value.set(1)
          window.set_size(width=180, height=90) catch {
            error => state.record_error(error)
          }
        }),
      )
      ignore(state.root.post(fn() { value.set(2) }))
      state.drain_actions()
      state.check_error()
      assert_eq(painted, [0])
      state.sync_frame()
      assert_eq(painted, [0, 2])
      assert_eq(state.root.frame_stats().paint_count, 2)
    },
  )
}

///|
fn with_render_state(
  content : (@sdl_lib.Window) -> @view.View,
  check : (SdlAppState, @sdl_lib.Window, RasterSurface) -> Unit raise,
  clock~ : () -> Double = fn() { 0.0 },
  clear~ : @foundation.Color? = Some(@foundation.Color::white()),
  observed_clears~ : Array[@foundation.Color] = [],
  display_scale~ : () -> Double raise = () => 1.0,
) -> Unit raise {
  let driver = @env.get_env_var("SDL_VIDEODRIVER")
  @env.set_env_var("SDL_VIDEODRIVER", "dummy")
  defer (fn() {
    match driver {
      Some(driver) => @env.set_env_var("SDL_VIDEODRIVER", driver)
      None => @env.unset_env_var("SDL_VIDEODRIVER")
    }
  })()
  @sdl_lib.init_lib(@sdl_lib.INIT_VIDEO)
  defer @sdl_lib.quit()
  let window = @sdl_lib.Window(
    title="Frame rendering test",
    width=160,
    height=80,
    hidden=true,
  )
  defer window.destroy()
  let sdl_renderer = @sdl_lib.Renderer(window, name="software")
  defer sdl_renderer.destroy()
  let surface = RasterSurface(sdl_renderer)
  defer surface.destroy()
  let factory = TestSurfaceFactory::{ surface, }
  let renderer = @skia_backend.raster_renderer(factory)
  let recorder : &@backend.Renderer = ThemeRecordingRenderer::{
    delegate: renderer,
    clears: observed_clears,
  }
  defer recorder.dispose()
  let root = @runtime.mount(
    fn() { content(window) },
    text_layout_system=recorder.text_layout_system(),
    clock~,
  )
  defer root.dispose()
  let state = SdlAppState(root, recorder, clear, display_scale~)
  defer state.destroy()
  check(state, window, surface)
}

///|
priv struct TestSurfaceFactory {
  surface : RasterSurface
}

///|
impl @backend.SurfaceFactory for TestSurfaceFactory with fn raster(self) {
  self.surface
}

///|
test "SDL backend paints each output size and reuses a clean frame" {
  let frames : Array[@foundation.Size] = []
  with_render_state(
    fn(_) {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(context, frame) {
          context.fill_box(frame, @foundation.Color::accent(), 0.0)
          frames.push(frame.size)
        }),
      )
    },
    (state, window, surface) => {
      state.sync_frame()
      assert_eq(state.root.dirty(), @runtime.Clean)
      window.set_size(width=180, height=90)
      state.sync_frame()
      let texture = surface.texture
      window.set_size(width=170, height=85)
      state.sync_frame()
      assert_true(physical_equal(surface.texture, texture))
      assert_eq(frames, [
        @foundation.Size(width=160.0, height=80.0),
        @foundation.Size(width=180.0, height=90.0),
        @foundation.Size(width=170.0, height=85.0),
      ])
      state.sync_frame()
      assert_eq(state.root.frame_stats().paint_count, 3)
      assert_eq(state.root.frame_stats().present_count, 3)
      assert_true(state.prepare_wait())
      assert_true(state.prepare_wait())
      state.present_cached_frame()
      assert_eq(frames.length(), 3)
      assert_eq(state.root.frame_stats().present_count, 4)
      assert_eq(state.root.frame_stats().presented_frame, 3)
      assert_eq(state.root.dirty(), @runtime.Clean)
    },
  )
}

///|
test "repeated resize notifications reuse a clean frame and preserve pending paint" {
  with_render_state(fn(_) { @view.text("cached") }, (state, _, _) => {
    state.sync_frame()
    let before = state.root.frame_stats()
    state.redraw_now()
    state.redraw_now()
    state.check_error()
    let unchanged = state.root.frame_stats()
    assert_eq(unchanged.paint_count, before.paint_count)
    assert_eq(unchanged.present_count, before.present_count)
    assert_eq(unchanged.layout_count, before.layout_count)
    state.root.mark_paint_dirty()
    state.redraw_now()
    state.check_error()
    let updated = state.root.frame_stats()
    assert_eq(updated.paint_count, before.paint_count + 1)
    assert_eq(updated.present_count, before.present_count + 1)
    assert_eq(updated.layout_count, before.layout_count)
    assert_eq(state.root.dirty(), Clean)
  })
}

///|
test "CPU paints and idle keep one raster texture until capacity changes" {
  with_render_state(fn(_) { @view.text("cached") }, (state, window, surface) => {
    state.sync_frame()
    let texture = surface.texture
    let before = state.root.frame_stats()
    for _ in 0..<40 {
      state.root.mark_paint_dirty()
      state.sync_frame()
      assert_true(state.prepare_wait())
      assert_true(physical_equal(surface.texture, texture))
      assert_false(texture.raw().is_null())
    }
    let after = state.root.frame_stats()
    assert_eq(after.paint_count, before.paint_count + 40)
    assert_eq(after.present_count, before.present_count + 40)
    assert_eq(after.layout_count, before.layout_count)
    window.set_size(width=180, height=90)
    state.sync_frame()
    assert_true(texture.raw().is_null())
    assert_false(surface.texture.raw().is_null())
    assert_true(state.prepare_wait())
    state.present_cached_frame()
    assert_eq(state.root.dirty(), Clean)
  })
}

///|
test "failed raster resize preserves the working frame and permits a later resize" {
  with_render_state(fn(_) { @view.text("cached") }, (state, window, surface) => {
    state.sync_frame()
    let texture = surface.texture
    let capacity = (surface.texture_width, surface.texture_height)
    let before = state.root.frame_stats()
    let failed = try {
      ignore(surface.sync_texture_size(@int.MAX_VALUE, 2, false))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_false(texture.raw().is_null())
    assert_true(physical_equal(surface.texture, texture))
    assert_eq((surface.texture_width, surface.texture_height), capacity)
    assert_true(state.has_frame)
    state.present_cached_frame()
    assert_eq(state.root.frame_stats().present_count, before.present_count + 1)
    state.sync_frame()
    assert_eq(state.root.frame_stats().paint_count, before.paint_count)
    assert_eq(state.root.frame_stats().present_count, before.present_count + 1)
    assert_eq(state.root.frame_stats().layout_count, before.layout_count)
    window.set_size(width=180, height=90)
    state.sync_frame()
    assert_true(texture.raw().is_null())
    assert_false(surface.texture.raw().is_null())
    assert_true(state.has_frame)
    assert_eq(state.root.frame_stats().paint_count, before.paint_count + 1)
    assert_eq(state.root.frame_stats().present_count, before.present_count + 2)
    assert_true(state.prepare_wait())
    state.destroy()
    state.destroy()
    state.present_cached_frame()
    assert_eq(state.root.frame_stats().present_count, before.present_count + 2)
  })
}

///|
test "window resize during painting schedules the next frame" {
  let frames : Array[@foundation.Size] = []
  let resize = Ref(false)
  let errors : Array[Error] = []
  with_render_state(
    fn(window) {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(context, frame) {
          if resize.val {
            resize.val = false
            window.set_size(width=180, height=90) catch {
              error => errors.push(error)
            }
          }
          context.fill_box(frame, @foundation.Color::accent(), 0.0)
          frames.push(frame.size)
        }),
      )
    },
    (state, window, _) => {
      state.sync_frame()
      let listeners = state.watch_window(window)
      defer (fn() {
        for listener in listeners {
          listener.dispose()
        }
      })()
      resize.val = true
      state.root.mark_paint_dirty()
      state.sync_frame()
      assert_eq(errors.length(), 0)
      assert_true(state.pending_error is None)
      assert_eq(frames.length(), 2)
      assert_eq(state.root.dirty(), @runtime.NeedsPaint)
      state.sync_frame()
      assert_eq(frames, [
        @foundation.Size(width=160.0, height=80.0),
        @foundation.Size(width=160.0, height=80.0),
        @foundation.Size(width=180.0, height=90.0),
      ])
      assert_eq(state.root.dirty(), @runtime.Clean)
    },
  )
}
