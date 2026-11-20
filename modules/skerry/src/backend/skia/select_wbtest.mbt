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
                  @style.BoxStyle()
                  .height(37.4)
                  .background(background)
                  .radius(0.0),
                ),
              ),
          ),
        ],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    text_layout_system=renderer.text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyEnter)))
  root.focus_lost()
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (300.0 * scale).to_int()
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
      assert_eq(
        pixel,
        b"\x30\x28\x20\xff",
        msg="scale=\{scale} row=\{index} edge=\{edge} row_frame=\{Repr(rows[index].frame)} palette=\{Repr(rows[index].computed_style)}",
      )
    }
  }
}

///|
test "select list padding protects rounded corners and border throughout scrolling" {
  let renderer = Renderer()
  defer renderer.dispose()
  let selected = @reactive.signal(Some(0))
  let blue = @foundation.Color::rgb(r=0, g=0, b=255)
  let white = @foundation.Color::white()
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.select(
            Array::makei(10, i => @controls.SelectOption(i, label="")),
            selected~,
            style=@controls.SelectStyle()
              .surface(@style.BoxStyle().width(160.0).height(40.0))
              .list(
                @style.BoxStyle()
                .max_height(120.0)
                .radius(6.0)
                .background(white)
                .stroke(@foundation.Color::rgb(r=255, g=0, b=0)),
              )
              .option(
                @controls.ButtonStyle().surface(@style.BoxStyle().height(40.0)),
              )
              .selected(
                @controls.ButtonStyle().surface(
                  @style.BoxStyle().background(blue),
                ),
              ),
          ),
        ],
        style=@view.FlexStyle()
          .padding(@foundation.Insets::all(20.0))
          .align_items(Start),
      )
    },
    text_layout_system=renderer.text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyEnter)))
  for bottom in [false, true] {
    if bottom {
      assert_true(root.key_down(@foundation.KeyEvent(key=KeyEnd)))
      selected.set(Some(9))
    }
    for scale in [1.0, 1.25, 1.5, 2.0] {
      let width = (240.0 * scale).to_int()
      let height = (240.0 * scale).to_int()
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
        @foundation.Color::rgb(r=255, g=0, b=255),
      )
      let nodes = root.snapshot().unwrap().tree.nodes
      let list = nodes.iter().filter(node => node.scroll is Some(_)).to_array()[0]
      let rows = nodes
        .iter()
        .filter(node => node.component_name == "SelectOption")
        .to_array()
      let frame = list.frame
      let bar = list.scroll.unwrap().scrollbar.unwrap()
      assert_eq(
        bar.track.origin.x + bar.track.size.width,
        frame.origin.x + frame.size.width,
      )
      let track_y = ((bar.track.origin.y + bar.track.size.height * 0.5) * scale).to_int()
      let edge = raster_pixel(
        pixels,
        width,
        ((frame.origin.x + frame.size.width - 1.0) * scale).to_int(),
        track_y,
      )
      assert_eq(
        edge,
        raster_pixel(
          pixels,
          width,
          ((bar.track.origin.x + 1.0) * scale).to_int(),
          track_y,
        ),
      )
      assert_true(edge != b"\xff\xff\xff\xff")
      for x in [frame.origin.x + 0.5, frame.origin.x + frame.size.width - 0.5] {
        for
          y in [frame.origin.y + 0.5, frame.origin.y + frame.size.height - 0.5] {
          assert_eq(
            raster_pixel(
              pixels,
              width,
              (x * scale).to_int(),
              (y * scale).to_int(),
            ),
            b"\xff\x00\xff\xff",
          )
        }
      }
      for y in [frame.origin.y + 2.0, frame.origin.y + frame.size.height - 2.0] {
        assert_eq(
          raster_pixel(
            pixels,
            width,
            ((frame.origin.x + 40.0) * scale).to_int(),
            (y * scale).to_int(),
          ),
          b"\xff\xff\xff\xff",
        )
      }
      let active = rows[if bottom { 9 } else { 0 }]
      assert_true(active.state.focused)
      assert_eq(active.computed_style.unwrap().stroke_color, None)
      for
        x in [
          active.frame.origin.x + 1.0,
          active.frame.origin.x + active.frame.size.width - 2.0,
        ] {
        let y = active.frame.origin.y + active.frame.size.height * 0.5
        assert_eq(
          raster_pixel(
            pixels,
            width,
            (x * scale).to_int(),
            (y * scale).to_int(),
          ),
          b"\xff\x00\x00\xff",
        )
      }
      assert_true(active.frame.origin.y >= list.content.origin.y)
      assert_true(
        active.frame.origin.y + active.frame.size.height <=
        list.content.origin.y + list.content.size.height + 0.01,
      )
      if bottom {
        assert_true(list.scroll.unwrap().offset > 0.0)
      }
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
    text_layout_system=renderer.text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyEnter)))
  root.focus_lost()
  for scale in [1.0, 1.25, 1.5, 2.0] {
    let width = (240.0 * scale).to_int()
    let height = (200.0 * scale).to_int()
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
