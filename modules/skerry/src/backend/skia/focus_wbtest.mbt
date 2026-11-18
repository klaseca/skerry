///|
test "focus outline retains an even gap and separate border at fractional scales" {
  let renderer = Renderer()
  defer renderer.dispose()
  let red = @foundation.Color::rgb(r=255, g=0, b=0)
  let blue = @foundation.Color::rgb(r=0, g=0, b=255)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.button(
            "",
            style=@controls.ButtonStyle().surface(
              @style.BoxStyle()
              .width(100.0)
              .height(40.0)
              .background(blue)
              .stroke(red, width=2.0)
              .radius(4.0),
            ),
          ),
        ],
        style=@view.FlexStyle()
          .padding(@foundation.Insets::all(20.0))
          .align_items(Start),
      )
    },
    theme=@style.Theme().token(@style.accent_token, blue),
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer root.dispose()
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (160.0 * scale).to_int()
    let height = (100.0 * scale).to_int()
    let pixels = Bytes::make(width * height * 4, b'\x00')
    @backend.Renderer::render(
      renderer,
      root,
      @backend.RasterTarget(
        memory=raster_test_memory(pixels),
        width~,
        height~,
        row_bytes=width * 4,
        format=Bgra8888Premultiplied,
        scale~,
      ),
      @foundation.Color::white(),
    )
    let node = root.snapshot().unwrap().tree.nodes[1]
    assert_eq(
      node.frame,
      @foundation.Rect(x=20.0, y=20.0, width=100.0, height=40.0),
    )
    assert_eq(node.border, @foundation.Insets::all(0.0))
    assert_eq(node.computed_style.unwrap().stroke_width, Some(2.0))
    assert_eq(node.computed_style.unwrap().outline_offset, Some(2.0))
    let pixel = fn(x, y) {
      raster_pixel(pixels, width, (x * scale).to_int(), (y * scale).to_int())
    }
    for
      point in [
        @foundation.Point(x=17.0, y=40.0),
        @foundation.Point(x=123.0, y=40.0),
        @foundation.Point(x=70.0, y=17.0),
        @foundation.Point(x=70.0, y=63.0),
      ] {
      assert_eq(
        pixel(point.x, point.y),
        b"\xff\x00\x00\xff",
        msg="scale=\{scale} outline=\{Repr(point)}",
      )
    }
    // At fractional scales a narrow gap can share a pixel with the antialiased
    // edge of the red border. It must remain light, rather than filled blue.
    let gap = pixel(18.5, 40.0)
    assert_true(
      gap[0] > 150 && gap[1] > 150 && gap[2] > 150,
      msg="scale=\{scale} gap=\{Repr(gap)}",
    )
    assert_eq(
      pixel(20.0, 40.0),
      b"\x00\x00\xff\xff",
      msg="scale=\{scale} border",
    )
    assert_eq(pixel(24.0, 40.0), b"\xff\x00\x00\xff", msg="scale=\{scale} fill")
  }
}
