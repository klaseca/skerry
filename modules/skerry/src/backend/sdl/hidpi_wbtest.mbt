///|
test "App dimensions map logical units to each platform's window coordinates" {
  for scale in [1.0, 1.25, 1.5, 2.0] {
    // Windows/X11 use physical pixels as window coordinates.
    assert_eq(
      initial_window_dimension(800, scale, 1.0),
      (800.0 * scale).to_int(),
    )
    // macOS/Wayland can use points backed by high-density pixels.
    assert_eq(initial_window_dimension(800, scale, scale), 800)
  }
  assert_eq(initial_window_dimension(801, 1.25, 1.0), 1001)
  assert_eq(initial_window_dimension(@int.MAX_VALUE, 2.0, 1.0), @int.MAX_VALUE)
}

///|
test "HiDPI pointer and text selection use logical units across platform densities" {
  for scale in [1.0, 1.25, 1.5, 2.0] {
    for density in [1.0, scale] {
      let window_factor = scale / density
      let geometry = InputGeometry(
        window_size=Size(
          width=320.0 * window_factor,
          height=240.0 * window_factor,
        ),
        pixel_size=Size(width=320.0 * scale, height=240.0 * scale),
        scale~,
      )
      assert_eq(geometry.logical_size, Size(width=320.0, height=240.0))
      let value = @reactive.signal("hello world")
      let root = input_test_root(fn() {
        @view.column(
          [
            @controls.text_input(
              value~,
              style=@controls.TextInputStyle().surface(
                @style.BoxStyle()
                .width(180.0)
                .height(36.0)
                .padding(@foundation.Insets::all(0.0)),
              ),
            ),
          ],
          style=@view.FlexStyle().padding(@foundation.Insets::all(40.0)),
        )
      })
      defer root.dispose()
      input_test_pointer(
        root,
        geometry,
        @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
        42.0 * window_factor,
        50.0 * window_factor,
      )
      input_test_pointer(
        root,
        geometry,
        @sdl_sys.EVENT_MOUSE_MOTION,
        90.0 * window_factor,
        50.0 * window_factor,
      )
      assert_eq(root.copy_text(), Some("hello"))
      input_test_pointer(
        root,
        geometry,
        @sdl_sys.EVENT_MOUSE_BUTTON_UP,
        100.0 * window_factor,
        50.0 * window_factor,
      )
      assert_eq(root.copy_text(), Some("hello "))
      assert_true(root.text_input("x"))
      assert_eq(value.get(), "xworld")
    }
  }
}

///|
test "HiDPI wheel and scrollbar drag retain logical scroll distances" {
  for scale in [1.0, 1.25, 1.5, 2.0] {
    for density in [1.0, scale] {
      let factor = scale / density
      let geometry = InputGeometry(
        window_size=Size(width=100.0 * factor, height=120.0 * factor),
        pixel_size=Size(width=100.0 * scale, height=120.0 * scale),
        scale~,
      )
      let offset = @reactive.signal(0.0)
      let root = input_test_root(fn() {
        @view.scroll_view(@view.fill_box(600.0), offset~)
      })
      defer root.dispose()
      assert_true(
        dispatch_event(
          root,
          wheel_test_event(
            1,
            0.0,
            -0.5,
            Point(x=10.0 * factor, y=20.0 * factor),
          ),
          window_id=1,
          geometry=() => geometry,
        ),
      )
      assert_eq(offset.get(), 20.0)
      assert_true(
        dispatch_event(
          root,
          input_test_event(@sdl_sys.EVENT_KEY_DOWN, 1, keycode=0x4000004E),
          window_id=1,
          geometry=() => geometry,
        ),
      )
      assert_eq(offset.get(), 140.0)
      assert_true(
        dispatch_event(
          root,
          input_test_event(@sdl_sys.EVENT_KEY_DOWN, 1, keycode=0x4000004B),
          window_id=1,
          geometry=() => geometry,
        ),
      )
      assert_eq(offset.get(), 20.0)
      input_test_pointer(
        root,
        geometry,
        @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
        90.0 * factor,
        10.0 * factor,
      )
      input_test_pointer(
        root,
        geometry,
        @sdl_sys.EVENT_MOUSE_MOTION,
        90.0 * factor,
        34.0 * factor,
      )
      input_test_pointer(
        root,
        geometry,
        @sdl_sys.EVENT_MOUSE_BUTTON_UP,
        90.0 * factor,
        34.0 * factor,
      )
      assert_true(offset.get() > 100.0)
      assert_true(offset.get() < 200.0)
    }
  }
}

///|
test "display scale events repaint the matching window without remounting or losing focus" {
  let scale = Ref(1.0)
  let mounts = Ref(0)
  let value = @reactive.signal("hello")
  with_render_state(
    fn(_) {
      mounts.val += 1
      @controls.text_input(value~)
    },
    (state, window) => {
      state.sync_frame()
      assert_true(state.root.key_down(@foundation.KeyEvent(key=KeyTab)))
      state.sync_frame()
      let before = state.root.snapshot().unwrap()
      let texture = state.texture
      let listeners = state.watch_window(window)
      defer (fn() {
        for listener in listeners {
          listener.dispose()
        }
      })()
      scale.val = 2.0
      let event = @sdl_sys.Event()
      event.set_event_type(@sdl_sys.EVENT_WINDOW_DISPLAY_SCALE_CHANGED)
      event.window().set_window_id(window.id() + 1)
      assert_true(@sdl_sys.push_event(event))
      assert_eq(state.root.frame_stats().paint_count, before.frame.paint_count)
      event.window().set_window_id(window.id())
      assert_true(@sdl_sys.push_event(event))
      state.check_error()
      let after = state.root.snapshot().unwrap()
      assert_eq(after.tree.size, Size(width=80.0, height=40.0))
      assert_eq(after.tree.nodes[0].id, before.tree.nodes[0].id)
      assert_eq(after.focused_node_id, before.focused_node_id)
      assert_eq(after.frame.paint_count, before.frame.paint_count + 1)
      assert_eq(mounts.val, 1)
      assert_true(physical_equal(texture, state.texture))
      assert_true(state.root.text_input("!"))
      assert_eq(value.get(), "hello!")
      state.sync_frame()
      assert_true(state.prepare_wait())
    },
    display_scale=() => scale.val,
  )
}

///|
test "scaled pixel resize reuses logical layout and cached text measurements" {
  let scale = Ref(1.0)
  with_render_state(
    fn(_) { @view.text("HiDPI") },
    (state, window) => {
      state.sync_frame()
      let before = state.root.snapshot().unwrap()
      scale.val = 2.0
      window.set_size(width=320, height=160)
      state.sync_frame()
      let after = state.root.snapshot().unwrap()
      assert_eq(after.tree, before.tree)
      assert_eq(after.frame.layout_count, before.frame.layout_count)
      assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
      assert_eq(state.frame_scale, 2.0)
      let paints = after.frame.paint_count
      state.sync_frame()
      assert_true(state.prepare_wait())
      state.present_cached_frame()
      assert_eq(state.root.frame_stats().paint_count, paints)
    },
    display_scale=() => scale.val,
  )
}

///|
test "expose detects a changed scale even when the pixel extent is unchanged" {
  let scale = Ref(1.0)
  with_render_state(
    fn(_) { @view.text("HiDPI") },
    (state, _) => {
      state.sync_frame()
      let before = state.root.frame_stats()
      scale.val = 1.25
      state.present_cached_frame()
      assert_eq(
        state.root.snapshot().unwrap().tree.size,
        Size(width=128.0, height=64.0),
      )
      assert_eq(state.root.frame_stats().paint_count, before.paint_count + 1)
      assert_true(state.prepare_wait())
    },
    display_scale=() => scale.val,
  )
}
