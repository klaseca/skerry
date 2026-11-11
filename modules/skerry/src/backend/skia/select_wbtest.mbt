///|
test "select options share edges and paint without seams at fractional scales" {
  let renderer = Renderer()
  defer renderer.dispose()
  let background = @foundation.Color::rgb(r=32, g=40, b=48)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.select(
            ["One", "Two", "Three", "Four", "Five", "Six"].map(fn(value) {
              @controls.SelectOption(value, label=value)
            }),
            style=@controls.SelectStyle()
              .surface(@style.BoxStyle().width(220.0))
              .list(@style.BoxStyle().max_height(150.0))
              .option(
                @controls.ButtonStyle().surface(
                  @style.BoxStyle().height(37.4).background(background),
                ),
              ),
          ),
        ],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer root.dispose()
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyEnter)))
  root.focus_lost()
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (300.0 * scale).to_int()
    let height = (300.0 * scale).to_int()
    let pixels = Bytes::new(width * height * 4)
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
    let rows = root.snapshot().unwrap().tree.nodes
      .iter()
      .filter(node => node.component_name == "SelectOption")
      .to_array()
    for index in 1..<3 {
      let edge = rows[index].frame.origin.y
      assert_true(
        (edge -
        rows[index - 1].frame.origin.y -
        rows[index - 1].frame.size.height).abs() <
        0.001,
      )
      let pixel = raster_pixel(
        pixels,
        width,
        ((rows[index].frame.origin.x + 6.0) * scale).to_int(),
        (edge * scale).to_int(),
      )
      assert_eq(pixel, b"\x30\x28\x20\xff")
    }
  }
}

///|
test "select arrow and selection check render as native geometry at fractional scales" {
  let renderer = Renderer()
  defer renderer.dispose()
  let black = @foundation.Color::black()
  let white = @foundation.Color::white()
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.select(
            [0, 1].map(fn(option) { @controls.SelectOption(option, label="") }),
            selected=@reactive.signal(Some(0)),
            placeholder="",
            style=@controls.SelectStyle()
              .surface(
                @style.BoxStyle()
                .width(200.0)
                .height(40.0)
                .background(white)
                .stroke(white),
              )
              .label(@view.TextStyle().color(black))
              .option(
                @controls.ButtonStyle()
                .surface(@style.BoxStyle().height(36.0).background(white))
                .label(@view.TextStyle().color(black)),
              ),
          ),
        ],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer root.dispose()
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyEnter)))
  root.focus_lost()
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (240.0 * scale).to_int()
    let height = (200.0 * scale).to_int()
    let pixels = Bytes::new(width * height * 4)
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
      white,
    )
    let nodes = root.snapshot().unwrap().tree.nodes
    let field = nodes
      .iter()
      .filter(node => node.component_name == "Select")
      .to_array()[0]
    let selected = nodes
      .iter()
      .filter(node => node.component_name == "SelectOption")
      .to_array()[0]
    for node in [field, selected] {
      let inner = node.frame.inset(node.padding)
      let mut ink = 0
      for
        y in ((inner.origin.y + inner.size.height * 0.5 - 6.0) * scale).to_int()..<((
          inner.origin.y + inner.size.height * 0.5 + 6.0
        ) *
        scale).to_int() {
        for
          x in ((inner.origin.x + inner.size.width - 20.0) * scale).to_int()..<((
            inner.origin.x + inner.size.width
          ) *
          scale).to_int() {
          let pixel = (y * width + x) * 4
          if pixels[pixel] < 100 &&
            pixels[pixel + 1] < 100 &&
            pixels[pixel + 2] < 100 {
            ink += 1
          }
        }
      }
      assert_true(ink > 8)
    }
  }
}
