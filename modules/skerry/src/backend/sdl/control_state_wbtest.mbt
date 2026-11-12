///|
test "SDL mouse leave clears hover only for its window and keeps drag capture" {
  let clicks = Ref(0)
  with_render_state(
    fn(_) { @controls.button("button", on_click=fn() { clicks.val += 1 }) },
    (state, _) => {
      state.sync_frame()
      let root = state.root
      let baseline = root.frame_stats().layout_count
      let queries = Ref(0)
      let get_geometry : () -> InputGeometry raise = fn() {
        queries.val += 1
        let size = @foundation.Size(width=160.0, height=80.0)
        { window_size: size, logical_size: size, }
      }
      let dispatcher = EventDispatcher(root, window_id=1, geometry=get_geometry)
      assert_true(
        dispatcher.dispatch(
          input_test_event(
            @sdl_sys.EVENT_MOUSE_MOTION,
            1,
            point=Point(x=10.0, y=10.0),
          ),
        ),
      )
      state.sync_frame()
      assert_true(root.snapshot().unwrap().tree.nodes[0].state.hovered)
      let paints = root.frame_stats().paint_count
      assert_true(
        dispatcher.dispatch(
          input_test_event(
            @sdl_sys.EVENT_MOUSE_MOTION,
            1,
            point=Point(x=20.0, y=10.0),
          ),
        ),
      )
      state.sync_frame()
      assert_eq(root.frame_stats().paint_count, paints)
      assert_true(state.prepare_wait())
      assert_true(
        dispatcher.dispatch(
          input_test_event(
            @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
            1,
            point=Point(x=10.0, y=10.0),
          ),
        ),
      )
      state.sync_frame()
      assert_true(root.snapshot().unwrap().tree.nodes[0].state.pressed)
      let pointer_queries = queries.val
      for window_id in [2U, 1U] {
        assert_true(
          dispatcher.dispatch(
            input_test_event(@sdl_sys.EVENT_WINDOW_MOUSE_LEAVE, window_id),
          ),
        )
        state.sync_frame()
        let node = root.snapshot().unwrap().tree.nodes[0]
        assert_eq(node.state.hovered, window_id == 2U)
        assert_eq(node.state.pressed, window_id == 2U)
        assert_true(node.state.focused)
      }
      assert_eq(queries.val, pointer_queries)
      assert_true(
        dispatcher.dispatch(
          input_test_event(
            @sdl_sys.EVENT_MOUSE_BUTTON_UP,
            1,
            point=Point(x=10.0, y=10.0),
          ),
        ),
      )
      state.sync_frame()
      assert_eq(clicks.val, 1)
      assert_false(root.snapshot().unwrap().tree.nodes[0].state.pressed)
      assert_eq(root.frame_stats().layout_count, baseline)
      assert_true(state.prepare_wait())
    },
  )
}

///|
test "SDL keyup clears keyboard pressed without geometry queries or another activation" {
  let clicks = Ref(0)
  with_render_state(
    fn(_) { @controls.button("button", on_click=fn() { clicks.val += 1 }) },
    (state, _) => {
      state.sync_frame()
      let root = state.root
      let baseline = root.frame_stats().layout_count
      assert_true(root.key_down(KeyEvent(key=KeyTab)))
      let queries = Ref(0)
      let get_geometry : () -> InputGeometry raise = fn() {
        queries.val += 1
        let size = @foundation.Size(width=160.0, height=80.0)
        { window_size: size, logical_size: size, }
      }
      let dispatcher = EventDispatcher(root, window_id=1, geometry=get_geometry)
      assert_true(
        dispatcher.dispatch(
          input_test_event(@sdl_sys.EVENT_KEY_DOWN, 1, keycode=0x20U),
        ),
      )
      state.sync_frame()
      assert_true(root.snapshot().unwrap().tree.nodes[0].state.pressed)
      assert_eq(clicks.val, 1)
      for
        (window_id, keycode, pressed) in [
          (2U, 0x20U, true),
          (1U, 0x0DU, true),
          (1U, 0x20U, false),
        ] {
        assert_true(
          dispatcher.dispatch(
            input_test_event(@sdl_sys.EVENT_KEY_UP, window_id, keycode~),
          ),
        )
        state.sync_frame()
        assert_eq(root.snapshot().unwrap().tree.nodes[0].state.pressed, pressed)
      }
      assert_eq(clicks.val, 1)
      assert_eq(queries.val, 0)
      assert_eq(root.frame_stats().layout_count, baseline)
      assert_true(state.prepare_wait())
    },
  )
}
