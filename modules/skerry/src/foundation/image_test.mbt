///|
test "image fitting preserves aspect ratio and resolves cropped source coordinates" {
  let image = @foundation.Image(
    width=200,
    height=100,
    Bytes::new(200 * 100 * 4),
  )
  let frame = @foundation.Rect(x=10.0, y=20.0, width=100.0, height=100.0)
  let contain = image.placement(frame).unwrap()
  assert_eq(
    contain.source,
    @foundation.Rect(x=0.0, y=0.0, width=200.0, height=100.0),
  )
  assert_eq(
    contain.destination,
    @foundation.Rect(x=10.0, y=45.0, width=100.0, height=50.0),
  )
  assert_eq(
    image.placement(frame, alignment=TopLeft).unwrap().destination.origin,
    @foundation.Point(x=10.0, y=20.0),
  )
  let cover = image.placement(frame, fit=Cover).unwrap()
  assert_eq(
    cover.source,
    @foundation.Rect(x=50.0, y=0.0, width=100.0, height=100.0),
  )
  assert_eq(cover.destination, frame)
  assert_eq(
    image.placement(frame, fit=Cover, alignment=CenterRight).unwrap().source.origin,
    @foundation.Point(x=100.0, y=0.0),
  )
  let fill = image.placement(frame, fit=Fill).unwrap()
  assert_eq(fill.source, contain.source)
  assert_eq(fill.destination, frame)
  assert_true(
    image.placement(@foundation.Rect(x=0.0, y=0.0, width=0.0, height=50.0))
    is None,
  )
}

///|
test "image data is shared and identity distinguishes independent resources" {
  let pixels = b"\xff\x00\x00\xff"
  let first = @foundation.Image(width=1, height=1, pixels)
  let second = @foundation.Image(width=1, height=1, pixels)
  assert_eq(first, first)
  assert_false(first == second)
  assert_true(physical_equal(first.pixels(), pixels))
  let map = Map([(first, 1), (second, 2)])
  assert_eq(map.length(), 2)
  assert_eq(map.get(first), Some(1))
  assert_eq(first.size(), @foundation.Size(width=1.0, height=1.0))
}

///|
test "image dimensions reject incomplete and overflowing pixel buffers" {
  for
    (width, height, pixels) in [(0, 1, b""), (1, 1, b""), (2147483647, 2, b"")] {
    let rejected = try {
      ignore(@foundation.Image(width~, height~, pixels))
      false
    } catch {
      @foundation.InvalidImageSize(..) => true
      _ => false
    }
    assert_true(rejected)
  }
}
