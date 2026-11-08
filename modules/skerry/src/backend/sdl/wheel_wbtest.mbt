///|
fn wheel_test_event(
  window_id : UInt32,
  x : Double,
  y : Double,
  point : @foundation.Point,
  flipped~ : Bool = false,
) -> @sdl_sys.Event {
  let bytes = @sdl_sys.Event().as_bytes().to_array()
  write_event_uint(bytes, 0, @sdl_sys.EVENT_MOUSE_WHEEL)
  write_event_uint(bytes, 16, window_id)
  write_event_uint(bytes, 24, Float::from_double(x).reinterpret_as_uint())
  write_event_uint(bytes, 28, Float::from_double(y).reinterpret_as_uint())
  write_event_uint(
    bytes,
    32,
    if flipped {
      @sdl_sys.MOUSEWHEEL_FLIPPED
    } else {
      @sdl_sys.MOUSEWHEEL_NORMAL
    },
  )
  write_event_uint(bytes, 36, Float::from_double(point.x).reinterpret_as_uint())
  write_event_uint(bytes, 40, Float::from_double(point.y).reinterpret_as_uint())
  @sdl_sys.Event::from_bytes(Bytes::from_array(bytes))
}

///|
test "SDL wheel routes fractional and flipped deltas to the correct scaled viewport" {
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let offset = @reactive.signal(0.0)
    let root = input_test_root(fn() {
      @view.column([
        @view.fill_box(40.0),
        @view.scroll_view(
          @view.column([@view.fill_box(300.0)]),
          offset~,
          style=@style.BoxStyle().height(60.0),
        ),
      ])
    })
    defer root.dispose()
    let queries = Ref(0)
    let get_geometry : () -> InputGeometry raise = fn() {
      queries.val += 1
      {
        window_size: Size(width=100.0 / scale, height=120.0 / scale),
        logical_size: Size(width=100.0, height=120.0),
      }
    }
    let point = @foundation.Point(x=10.0 / scale, y=50.0 / scale)
    assert_true(
      dispatch_event(
        root,
        wheel_test_event(2U, 0.0, -0.25, point),
        window_id=1U,
        geometry=get_geometry,
      ),
    )
    assert_eq(queries.val, 0)
    assert_eq(offset.get(), 0.0)
    assert_true(
      dispatch_event(
        root,
        wheel_test_event(1U, 0.0, -0.25, point),
        window_id=1U,
        geometry=get_geometry,
      ),
    )
    assert_eq(offset.get(), 10.0)
    assert_true(
      dispatch_event(
        root,
        wheel_test_event(1U, 0.0, 0.5, point, flipped=true),
        window_id=1U,
        geometry=get_geometry,
      ),
    )
    assert_eq(offset.get(), 30.0)
    assert_true(
      dispatch_event(
        root,
        wheel_test_event(1U, 0.0, -10.0, point),
        window_id=1U,
        geometry=get_geometry,
      ),
    )
    assert_eq(offset.get(), 240.0)
  }
}

///|
test "SDL horizontal wheel and invalid dimensions do not use vertical steps" {
  let offset = @reactive.signal(0.0)
  let root = input_test_root(fn() {
    @view.scroll_view(
      @view.row([@view.box(style=@style.BoxStyle().width(300.0).height(20.0))]),
      axis=Horizontal,
      offset~,
    )
  })
  defer root.dispose()
  let event = wheel_test_event(1U, 0.5, 0.0, Point(x=5.0, y=5.0))
  let valid : () -> InputGeometry raise = fn() {
    {
      window_size: Size(width=100.0, height=50.0),
      logical_size: Size(width=100.0, height=50.0),
    }
  }
  assert_true(dispatch_event(root, event, window_id=1U, geometry=valid))
  assert_eq(offset.get(), 20.0)
  let invalid : () -> InputGeometry raise = fn() {
    {
      window_size: Size(width=0.0, height=50.0),
      logical_size: Size(width=100.0, height=50.0),
    }
  }
  assert_true(dispatch_event(root, event, window_id=1U, geometry=invalid))
  assert_eq(offset.get(), 20.0)
}
