///|
fn raster_test_memory(bytes : Bytes) -> @backend.RasterMemory = "%identity"

///|
fn raster_pixel(bytes : Bytes, width : Int32, x : Int32, y : Int32) -> Bytes {
  let offset = (y * width + x) * 4
  bytes[offset:offset + 4].to_owned()
}

///|
test "raster scale preserves logical geometry while Skia draws full resolution images and text" {
  let image = @foundation.Image(
    width=2,
    height=1,
    b"\x00\x00\xff\xff\xff\x00\x00\xff",
  )
  let renderer = Renderer()
  defer renderer.dispose()
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.image(image, style=@view.ImageStyle().width(40.0).height(20.0)),
          @view.text(
            "HiDPI",
            style=@view.TextStyle().color(@foundation.Color::black()),
          ),
        ],
        style=@view.FlexStyle()
          .padding(@foundation.Insets::all(8.0))
          .spacing(4.0)
          .align_items(Start),
      )
    },
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer root.dispose()
  let logical_tree = Ref(root.snapshot().map(snapshot => snapshot.tree))
  let base_ink_height = Ref(0)
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (160.0 * scale).to_int()
    let height = (80.0 * scale).to_int()
    let pixels = Bytes::make(width * height * 4, b'\x00')
    let target = @backend.RasterTarget(
      memory=raster_test_memory(pixels),
      width~,
      height~,
      row_bytes=width * 4,
      format=Bgra8888Premultiplied,
      scale~,
    )
    assert_eq(target.logical_size(), Size(width=160.0, height=80.0))
    @backend.Renderer::render(
      renderer,
      root,
      target,
      @foundation.Color::white(),
    )
    let tree = root.snapshot().unwrap().tree
    match logical_tree.val {
      Some(expected) => assert_eq(tree, expected)
      None => logical_tree.val = Some(tree)
    }
    assert_eq(
      raster_pixel(
        pixels,
        width,
        (12.0 * scale).to_int(),
        (12.0 * scale).to_int(),
      ),
      b"\x00\x00\xff\xff",
    )
    assert_eq(
      raster_pixel(
        pixels,
        width,
        (44.0 * scale).to_int(),
        (12.0 * scale).to_int(),
      ),
      b"\xff\x00\x00\xff",
    )
    assert_eq(
      raster_pixel(
        pixels,
        width,
        (55.0 * scale).to_int(),
        (12.0 * scale).to_int(),
      ),
      b"\xff\xff\xff\xff",
    )
    let mut first_ink = height
    let mut last_ink = -1
    for y in (32.0 * scale).to_int()..<height {
      for x in 0..<width {
        let offset = (y * width + x) * 4
        if pixels[offset] < 100 &&
          pixels[offset + 1] < 100 &&
          pixels[offset + 2] < 100 {
          first_ink = first_ink.min(y)
          last_ink = last_ink.max(y)
        }
      }
    }
    let ink_height = last_ink - first_ink + 1
    assert_true(ink_height > 0)
    if scale == 1.0 {
      base_ink_height.val = ink_height
    } else {
      assert_true(
        (ink_height.to_double() - base_ink_height.val.to_double() * scale).abs() <=
        3.0,
      )
    }
  }
}

///|
test "raster scale transforms clips together with paint" {
  let renderer = Renderer()
  defer renderer.dispose()
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.element(
            style=@style.BoxStyle().width(20.0).height(10.0),
            painter=@view.Painter(fn(context, frame) {
              context.fill_box(
                @foundation.Rect(
                  x=frame.origin.x,
                  y=frame.origin.y,
                  width=100.0,
                  height=100.0,
                ),
                @foundation.Color::black(),
                0.0,
              )
            }),
          ).clip(),
        ],
        style=@view.FlexStyle()
          .padding(@foundation.Insets::all(8.0))
          .align_items(Start),
      )
    },
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer root.dispose()
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (80.0 * scale).to_int()
    let pixels = Bytes::make(width * width * 4, b'\x00')
    @backend.Renderer::render(
      renderer,
      root,
      @backend.RasterTarget(
        memory=raster_test_memory(pixels),
        width~,
        height=width,
        row_bytes=width * 4,
        format=Bgra8888Premultiplied,
        scale~,
      ),
      @foundation.Color::white(),
    )
    assert_eq(
      raster_pixel(
        pixels,
        width,
        (10.0 * scale).to_int(),
        (10.0 * scale).to_int(),
      ),
      b"\x00\x00\x00\xff",
    )
    assert_eq(
      raster_pixel(
        pixels,
        width,
        (30.0 * scale).to_int(),
        (10.0 * scale).to_int(),
      ),
      b"\xff\xff\xff\xff",
    )
    assert_eq(
      raster_pixel(
        pixels,
        width,
        (10.0 * scale).to_int(),
        (20.0 * scale).to_int(),
      ),
      b"\xff\xff\xff\xff",
    )
  }
}

///|
test "raster targets reject zero negative and nonfinite scales" {
  let pixels = Bytes::make(16, b'\x00')
  for
    scale in [
      0.0, -1.0, @double.infinity, @double.neg_infinity, @double.not_a_number,
    ] {
    let rejected = try {
      ignore(
        @backend.RasterTarget(
          memory=raster_test_memory(pixels),
          width=2,
          height=2,
          row_bytes=8,
          format=Bgra8888Premultiplied,
          scale~,
        ),
      )
      false
    } catch {
      @backend.InvalidRasterScale(..) => true
      _ => false
    }
    assert_true(rejected)
  }
}
