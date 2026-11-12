///|
test "SDL navigation keys use logical viewport dimensions and ignore foreign windows" {
  for scale in [1.0, 1.5, 2.0] {
    let offset = @reactive.signal(0.0)
    let root = input_test_root(fn() {
      @view.scroll_view(@view.fill_box(300.0), offset~)
    })
    defer root.dispose()
    let queries = Ref(0)
    let get_geometry : () -> InputGeometry raise = fn() {
      queries.val += 1
      {
        window_size: Size(width=100.0 / scale, height=50.0 / scale),
        logical_size: Size(width=100.0, height=50.0),
      }
    }
    let dispatcher = EventDispatcher(root, window_id=1U, geometry=get_geometry)
    assert_true(
      dispatcher.dispatch(
        input_test_event(@sdl_sys.EVENT_KEY_DOWN, 2U, keycode=0x4000004EU),
      ),
    )
    assert_eq(queries.val, 0)
    assert_eq(offset.get(), 0.0)
    // SDL_keycode.h: PageDown, Down, Up, PageUp, End, Home.
    for
      (keycode, expected) in [
        (0x4000004EU, 50.0),
        (0x40000051U, 90.0),
        (0x40000052U, 50.0),
        (0x4000004BU, 0.0),
        (0x4000004DU, 250.0),
        (0x4000004AU, 0.0),
      ] {
      assert_true(
        dispatcher.dispatch(
          input_test_event(@sdl_sys.EVENT_KEY_DOWN, 1U, keycode~),
        ),
      )
      assert_eq(offset.get(), expected)
    }
    assert_eq(queries.val, 6)
  }
}

///|
test "SDL Tab supplies host size and reveals a focused child before the first paint" {
  let offset = @reactive.signal(0.0)
  let root = input_test_root(fn() {
    @view.scroll_view(
      @view.column([
        @view.fill_box(100.0),
        @controls.button(
          "button",
          style=@controls.ButtonStyle().surface(@style.BoxStyle().height(30.0)),
        ),
      ]),
      offset~,
    )
  })
  defer root.dispose()
  let get_geometry : () -> InputGeometry raise = fn() {
    {
      window_size: Size(width=50.0, height=25.0),
      logical_size: Size(width=100.0, height=50.0),
    }
  }
  let dispatcher = EventDispatcher(root, window_id=1U, geometry=get_geometry)
  assert_true(
    dispatcher.dispatch(
      input_test_event(@sdl_sys.EVENT_KEY_DOWN, 1U, keycode=0x09U),
    ),
  )
  assert_eq(offset.get(), 80.0)
  assert_eq(root.frame_stats().paint_count, 0)
}
