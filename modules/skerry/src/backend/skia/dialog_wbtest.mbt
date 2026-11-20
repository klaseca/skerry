///|
test "dialog backdrop composites behind its surface at fractional display scales" {
  let renderer = Renderer()
  defer renderer.dispose()
  let white = @foundation.Color::white()
  let red = @foundation.Color::rgb(r=255, g=0, b=0)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.dialog(
            @controls.button("Open"),
            open=@reactive.signal(true),
            style=@controls.DialogStyle()
              .surface(
                @style.BoxStyle()
                .width(120.0)
                .height(80.0)
                .padding(@foundation.Insets::all(12.0))
                .radius(0.0)
                .background(white)
                .stroke(white, width=0.0),
              )
              .backdrop(
                @style.BoxStyle().background(
                  @foundation.Color::rgba(r=0, g=0, b=0, a=128),
                ),
              ),
            fn(_close) {
              @view.box(
                style=@style.BoxStyle().width(60.0).height(20.0).background(red),
              )
            },
          ),
        ],
        style=@view.FlexStyle().background(
          @foundation.Color::rgb(r=200, g=200, b=200),
        ),
      )
    },
    text_layout_system=renderer.text_layout_system(),
  )
  defer root.dispose()
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (240.0 * scale).to_int()
    let height = (180.0 * scale).to_int()
    let pixels = Bytes::make(width * height * 4, b'\x00')
    renderer.render(
      root,
      @backend.RasterTarget(
        memory=raster_test_memory(pixels),
        width~,
        height~,
        row_bytes=width * 4,
        format=Bgra8888Premultiplied,
        scale~,
      ),
      white,
    )
    let nodes = root.snapshot().unwrap().tree.nodes
    let surface = nodes
      .iter()
      .filter(node => {
        node.components.any(component => component.name == "DialogSurface")
      })
      .to_array()[0]
    let dimmed = raster_pixel(
      pixels,
      width,
      (10.0 * scale).to_int(),
      (150.0 * scale).to_int(),
    )
    assert_eq(dimmed, b"\x64\x64\x64\xff")
    assert_eq(
      raster_pixel(
        pixels,
        width,
        ((surface.frame.origin.x + 4.0) * scale).to_int(),
        ((surface.frame.origin.y + 4.0) * scale).to_int(),
      ),
      b"\xff\xff\xff\xff",
    )
    assert_eq(
      raster_pixel(
        pixels,
        width,
        ((surface.content.origin.x + 20.0) * scale).to_int(),
        ((surface.content.origin.y + 10.0) * scale).to_int(),
      ),
      b"\x00\x00\xff\xff",
    )
  }
}

///|
test "dialog input focus outline uses padding without clipping at fractional scales" {
  let renderer = Renderer()
  defer renderer.dispose()
  let blue = @foundation.Color::rgb(r=0, g=0, b=255)
  for overflowing in [false, true] {
    let root = @runtime.mount(
      fn() {
        @controls.dialog(
          @controls.button("open"),
          open=@reactive.signal(true),
          style=@controls.DialogStyle().surface(
            @style.BoxStyle().width(280.0).height(200.0),
          ),
          fn(_close) {
            @view.column(style=@view.FlexStyle().spacing(8.0), [
              @view.fill_box(if overflowing { 60.0 } else { 0.0 }),
              @controls.text_input(
                style=@controls.TextInputStyle().surface(
                  @style.BoxStyle().height(40.0),
                ),
              ),
              @view.fill_box(if overflowing { 400.0 } else { 0.0 }),
            ])
          },
        )
      },
      theme=@style.Theme().token(@style.accent_token, blue),
      text_layout_system=renderer.text_layout_system(),
    )
    defer root.dispose()
    for scale in [1.0, 1.25, 1.5, 2.0] {
      let width = (400.0 * scale).to_int()
      let height = (300.0 * scale).to_int()
      let pixels = Bytes::make(width * height * 4, b'\x00')
      renderer.render(
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
      let nodes = root.snapshot().unwrap().tree.nodes
      let input = nodes
        .iter()
        .filter(node => node.component_name == "TextInput")
        .to_array()[0]
      assert_true(input.state.focused)
      let frame = input.frame
      let points = [
        @foundation.Point(
          x=frame.origin.x - 3.0,
          y=frame.origin.y + frame.size.height * 0.5,
        ),
        @foundation.Point(
          x=frame.origin.x + frame.size.width + 3.0,
          y=frame.origin.y + frame.size.height * 0.5,
        ),
        @foundation.Point(
          x=frame.origin.x + frame.size.width * 0.5,
          y=frame.origin.y - 3.0,
        ),
        @foundation.Point(
          x=frame.origin.x + frame.size.width * 0.5,
          y=frame.origin.y + frame.size.height + 3.0,
        ),
      ]
      for point in points {
        assert_eq(
          raster_pixel(
            pixels,
            width,
            (point.x * scale).to_int(),
            (point.y * scale).to_int(),
          ),
          b"\xff\x00\x00\xff",
          msg="scale=\{scale} overflowing=\{overflowing} point=\{Repr(point)}",
        )
      }
      let surface = nodes
        .iter()
        .filter(node => node.scroll is Some(_))
        .to_array()[0]
      assert_eq(surface.scroll.unwrap().max_offset > 0.0, overflowing)
      assert_true(
        input.clip.origin.x + input.clip.size.width <=
        surface.frame.origin.x + surface.frame.size.width - 12.0,
      )
    }
  }
}

///|
test "Skia raster text input with and without a dialog at HiDPI" (
  bench : @bench.T,
) {
  let renderer = try! Renderer()
  defer renderer.dispose()
  let pixels = Bytes::make(1600 * 960 * 4, b'\x00')
  let target = @backend.RasterTarget(
    memory=raster_test_memory(pixels),
    width=1600,
    height=960,
    row_bytes=1600 * 4,
    format=Bgra8888Premultiplied,
    scale=2.0,
  )
  for open in [false, true] {
    let root = @runtime.mount(
      fn() {
        @view.column(
          style=@view.FlexStyle().spacing(16.0),
          [
            @controls.text_input(),
            @controls.dialog(
              @controls.button("Open"),
              open=@reactive.signal(open),
              fn(_close) {
                @view.column(style=@view.FlexStyle().spacing(16.0), [
                  @view.text("Edit name"),
                  @controls.text_input(),
                  @controls.button("Save"),
                ])
              },
            ),
            ..Array::makei(20, i => @view.text("Background row \{i}")),
          ],
        )
      },
      text_layout_system=renderer.text_layout_system(),
    )
    defer root.dispose()
    try! renderer.render(root, target, @foundation.Color::white())
    if !open {
      assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
    }
    assert_true(root.text_input("x"))
    assert_true(root.key_down(@foundation.KeyEvent(key=KeyBackspace)))
    bench.bench(name=if open { "dialog" } else { "normal" }, fn() {
      ignore(root.text_input("x"))
      try! renderer.render(root, target, @foundation.Color::white())
      ignore(root.key_down(@foundation.KeyEvent(key=KeyBackspace)))
    })
  }
  bench.keep(pixels)
}
