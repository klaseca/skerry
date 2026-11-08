///|
fn input_test_root(builder : () -> @view.View) -> @runtime.UiRoot {
  @runtime.mount(
    builder,
    text_layout_system=@text.TextLayoutSystem::from_metrics(
      TextMetricsProvider(measure=fn(input) {
        let carets = [0.0]
        let mut width = 0.0
        for _ in input.text {
          width += 10.0
          carets.push(width)
        }
        TextMetrics(
          width~,
          line_height=20.0,
          baseline=16.0,
          caret_positions=carets,
        )
      }),
    ),
  )
}

///|
fn write_event_uint(
  bytes : Array[Byte],
  offset : Int32,
  value : UInt32,
) -> Unit {
  for i in 0..<4 {
    bytes[offset + i] = (value >> (8 * i)).to_byte()
  }
}

///|
fn input_test_event(
  event_type : UInt32,
  window_id : UInt32,
  button~ : Int32 = 1,
  keycode~ : UInt32 = 0,
  point? : @foundation.Point,
) -> @sdl_sys.Event {
  let bytes = @sdl_sys.Event().as_bytes().to_array()
  // SDL 3 event structs share type/reserved/timestamp/windowID at these offsets.
  // These fixtures target the supported little-endian desktop platforms.
  write_event_uint(bytes, 0, event_type)
  write_event_uint(bytes, 16, window_id)
  bytes[24] = button.to_byte()
  write_event_uint(bytes, 28, keycode)
  if point is Some(point) {
    // Mouse button and motion structs store their float x/y at the same offsets.
    write_event_uint(
      bytes,
      28,
      Float::from_double(point.x).reinterpret_as_uint(),
    )
    write_event_uint(
      bytes,
      32,
      Float::from_double(point.y).reinterpret_as_uint(),
    )
  }
  @sdl_sys.Event::from_bytes(Bytes::from_array(bytes))
}

///|
test "SDL focus loss cancels and blurs only its host window" {
  let cancelled = Ref(0)
  let blurred = Ref(0)
  let root = input_test_root(fn() {
    @controls.text_input(on_pointer_cancel=fn() { cancelled.val += 1 }, on_blur=fn() {
      blurred.val += 1
    })
  })
  defer root.dispose()
  let size = @foundation.Size(width=180.0, height=80.0)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  let geometry_queries = Ref(0)
  let get_geometry : () -> InputGeometry raise = () => {
    geometry_queries.val += 1
    { window_size: size, logical_size: size, }
  }
  assert_true(
    dispatch_event(
      root,
      input_test_event(@sdl_sys.EVENT_WINDOW_FOCUS_LOST, 2),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  assert_eq(cancelled.val, 0)
  assert_eq(blurred.val, 0)
  assert_true(root.text_input("before blur"))
  assert_true(
    dispatch_event(
      root,
      input_test_event(@sdl_sys.EVENT_WINDOW_FOCUS_LOST, 1),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  assert_eq(cancelled.val, 1)
  assert_eq(blurred.val, 1)
  assert_false(root.text_input("after blur"))
  assert_true(
    dispatch_event(
      root,
      input_test_event(@sdl_sys.EVENT_WINDOW_FOCUS_LOST, 1),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  assert_eq(cancelled.val, 1)
  assert_eq(blurred.val, 1)
  assert_eq(geometry_queries.val, 0)
}

///|
test "SDL primary pointer keyboard and close events respect window routing" {
  let clicks = Ref(0)
  let root = input_test_root(fn() {
    @controls.button("Button", on_click=fn() { clicks.val += 1 })
  })
  defer root.dispose()
  let geometry_queries = Ref(0)
  let get_geometry : () -> InputGeometry raise = () => {
    geometry_queries.val += 1
    let size = @foundation.Size(width=180.0, height=80.0)
    { window_size: size, logical_size: size, }
  }
  let down = input_test_event(@sdl_sys.EVENT_MOUSE_BUTTON_DOWN, 1)
  let up = input_test_event(@sdl_sys.EVENT_MOUSE_BUTTON_UP, 1)
  let foreign = input_test_event(@sdl_sys.EVENT_MOUSE_BUTTON_DOWN, 2)
  assert_true(dispatch_event(root, foreign, window_id=1, geometry=get_geometry))
  let secondary = input_test_event(
    @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
    1,
    button=3,
  )
  assert_true(
    dispatch_event(root, secondary, window_id=1, geometry=get_geometry),
  )
  assert_eq(geometry_queries.val, 0)
  assert_true(dispatch_event(root, up, window_id=1, geometry=get_geometry))
  assert_eq(clicks.val, 0)
  assert_true(dispatch_event(root, down, window_id=1, geometry=get_geometry))
  let secondary_up = input_test_event(
    @sdl_sys.EVENT_MOUSE_BUTTON_UP,
    1,
    button=3,
  )
  assert_true(
    dispatch_event(root, secondary_up, window_id=1, geometry=get_geometry),
  )
  assert_eq(clicks.val, 0)
  assert_true(dispatch_event(root, up, window_id=1, geometry=get_geometry))
  assert_true(dispatch_event(root, up, window_id=1, geometry=get_geometry))
  assert_eq(clicks.val, 1)
  let key = input_test_event(@sdl_sys.EVENT_KEY_DOWN, 2, keycode=0x0D)
  assert_true(dispatch_event(root, key, window_id=1, geometry=get_geometry))
  assert_eq(clicks.val, 1)
  assert_true(
    dispatch_event(
      root,
      input_test_event(@sdl_sys.EVENT_KEY_DOWN, 1, keycode=0x0D),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  assert_eq(clicks.val, 2)
  assert_true(
    dispatch_event(
      root,
      input_test_event(@sdl_sys.EVENT_WINDOW_CLOSE_REQUESTED, 2),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  assert_false(
    dispatch_event(
      root,
      input_test_event(@sdl_sys.EVENT_WINDOW_CLOSE_REQUESTED, 1),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  assert_false(root.key_down(KeyEvent(key=KeyEnter)))
}

///|
fn input_test_pointer(
  root : @runtime.UiRoot,
  geometry : InputGeometry,
  event_type : UInt32,
  x : Double,
  y : Double,
) -> Unit raise {
  assert_true(
    dispatch_event(
      root,
      input_test_event(event_type, 1, point=Point(x~, y~)),
      window_id=1,
      geometry=() => geometry,
    ),
  )
}

///|
test "SDL pointer capture converts native coordinates to the current logical viewport" {
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let clicks = Ref(0)
    let events : Array[@foundation.PointerEvent] = []
    let root = input_test_root(fn() {
      @view.column(
        style=@view.FlexStyle().surface(
          @style.BoxStyle().padding(@foundation.Insets::all(40.0)),
        ),
        [
          @view.interactive(
            on_click=fn() { clicks.val += 1 },
            on_pointer_down=fn(event) { events.push(event) },
            on_pointer_move=fn(event) { events.push(event) },
            on_pointer_up=fn(event) { events.push(event) },
            @view.box(style=@style.BoxStyle().width(80.0).height(32.0)),
          ),
        ],
      )
    })
    defer root.dispose()
    let geometry : InputGeometry = {
      window_size: Size(width=320.0, height=240.0),
      logical_size: Size(width=320.0 * scale, height=240.0 * scale),
    }
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
      100.0 / scale,
      60.0 / scale,
    )
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_MOTION,
      130.0 / scale,
      70.0 / scale,
    )
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_UP,
      100.0 / scale,
      60.0 / scale,
    )
    assert_eq(clicks.val, 1)
    assert_eq(events.length(), 3)
    assert_eq(events[0].phase, PointerDown)
    assert_eq(events[1].phase, PointerMove)
    assert_eq(events[2].phase, PointerUp)
    for i in 0..<3 {
      let expected_x = if i == 1 { 90.0 } else { 60.0 }
      let expected_y = if i == 1 { 30.0 } else { 20.0 }
      assert_true((events[i].position.x - expected_x).abs() < 0.0001)
      assert_true((events[i].position.y - expected_y).abs() < 0.0001)
    }
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
      100.0 / scale,
      60.0 / scale,
    )
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_UP,
      130.0 / scale,
      90.0 / scale,
    )
    assert_eq(clicks.val, 1)
    let event_count = events.length()
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
      -10.0 / scale,
      60.0 / scale,
    )
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_UP,
      100.0 / scale,
      60.0 / scale,
    )
    assert_eq(clicks.val, 1)
    assert_eq(events.length(), event_count)
  }
}

///|
test "SDL text selection and caret use the same coordinates as layout" {
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let value = @reactive.signal("hello world")
    let root = input_test_root(fn() {
      @view.column(
        style=@view.FlexStyle().surface(
          @style.BoxStyle().padding(@foundation.Insets::all(40.0)),
        ),
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
      )
    })
    defer root.dispose()
    let geometry : InputGeometry = {
      window_size: Size(width=320.0, height=240.0),
      logical_size: Size(width=320.0 * scale, height=240.0 * scale),
    }
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
      42.0 / scale,
      50.0 / scale,
    )
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_MOTION,
      90.0 / scale,
      50.0 / scale,
    )
    assert_eq(root.copy_text(), Some("hello"), msg="pixel density \{scale}")
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_UP,
      100.0 / scale,
      50.0 / scale,
    )
    assert_eq(root.copy_text(), Some("hello "), msg="pixel density \{scale}")
    assert_true(root.text_input("x"))
    assert_eq(value.get(), "xworld")
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
      60.0 / scale,
      50.0 / scale,
    )
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_UP,
      60.0 / scale,
      50.0 / scale,
    )
    assert_true(root.text_input("!"))
    assert_eq(value.get(), "xw!orld")
  }
}

///|
test "SDL pointer input follows current geometry during a captured session" {
  let clicks = Ref(0)
  let cancelled = Ref(0)
  let root = input_test_root(fn() {
    @view.interactive(
      on_click=fn() { clicks.val += 1 },
      on_pointer_cancel=fn() { cancelled.val += 1 },
      @view.fill_box(40.0),
    )
  })
  defer root.dispose()
  let current = Ref(InputGeometry::{
    window_size: Size(width=100.0, height=100.0),
    logical_size: Size(width=200.0, height=200.0),
  })
  let queries = Ref(0)
  let get_geometry : () -> InputGeometry raise = () => {
    queries.val += 1
    current.val
  }
  assert_true(
    dispatch_event(
      root,
      input_test_event(
        @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
        1,
        point=Point(x=90.0, y=15.0),
      ),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  current.val = {
    window_size: Size(width=120.0, height=100.0),
    logical_size: Size(width=180.0, height=200.0),
  }
  assert_true(
    dispatch_event(
      root,
      input_test_event(
        @sdl_sys.EVENT_MOUSE_BUTTON_UP,
        1,
        point=Point(x=115.0, y=15.0),
      ),
      window_id=1,
      geometry=get_geometry,
    ),
  )
  assert_eq(clicks.val, 1)
  assert_eq(cancelled.val, 0)
  assert_eq(queries.val, 2)
  // Keep x outside the current logical viewport after conversion; capture still gets up,
  // but release must not activate the stretched control.
  input_test_pointer(
    root,
    current.val,
    @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
    115.0,
    15.0,
  )
  input_test_pointer(
    root,
    current.val,
    @sdl_sys.EVENT_MOUSE_BUTTON_UP,
    121.0,
    15.0,
  )
  assert_eq(clicks.val, 1)
}

///|
test "SDL pointer input cancels capture when its surface has no extent" {
  let clicks = Ref(0)
  let cancelled = Ref(0)
  let root = input_test_root(fn() {
    @view.interactive(
      on_click=fn() { clicks.val += 1 },
      on_pointer_cancel=fn() { cancelled.val += 1 },
      @view.box(style=@style.BoxStyle().width(80.0).height(32.0)),
    )
  })
  defer root.dispose()
  let size = @foundation.Size(width=180.0, height=80.0)
  let valid : InputGeometry = { window_size: size, logical_size: size, }
  let invalid : Array[InputGeometry] = [
    { window_size: Size(width=0.0, height=80.0), logical_size: size, },
    { window_size: Size(width=180.0, height=0.0), logical_size: size, },
    { window_size: size, logical_size: Size(width=0.0, height=80.0), },
    { window_size: size, logical_size: Size(width=180.0, height=0.0), },
  ]
  for geometry in invalid {
    input_test_pointer(
      root,
      valid,
      @sdl_sys.EVENT_MOUSE_BUTTON_DOWN,
      10.0,
      10.0,
    )
    input_test_pointer(root, geometry, @sdl_sys.EVENT_MOUSE_MOTION, 10.0, 10.0)
    input_test_pointer(
      root,
      geometry,
      @sdl_sys.EVENT_MOUSE_BUTTON_UP,
      10.0,
      10.0,
    )
    input_test_pointer(root, valid, @sdl_sys.EVENT_MOUSE_BUTTON_UP, 10.0, 10.0)
    assert_eq(clicks.val, 0)
  }
  assert_eq(cancelled.val, invalid.length())
}
