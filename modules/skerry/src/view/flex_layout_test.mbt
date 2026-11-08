///|
test "row grow distributes free space after preferred widths padding and spacing on resize" {
  let view = @view.row(
    [
      @view.box(style=@style.BoxStyle().width(20.0).height(10.0).grow(1.0)),
      @view.box(style=@style.BoxStyle().width(40.0).height(10.0).grow(3.0)),
    ],
    style=@view.FlexStyle().padding(@foundation.Insets::all(10.0)).spacing(10.0),
  )
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  for
    (width, first, second) in [
      (150.0, 35.0, 85.0),
      (230.0, 55.0, 145.0),
      (350.0, 85.0, 235.0),
    ] {
    let layout = state.layout(view, size=Size(width~, height=40.0))
    assert_eq(layout.children[0].x, 10.0)
    assert_eq(layout.children[0].width, first)
    assert_eq(layout.children[1].x, 20.0 + first)
    assert_eq(layout.children[1].width, second)
  }
}

///|
test "column grow uses the vertical axis and preserves a fixed sibling" {
  let view = @view.column([
    @view.box(style=@style.BoxStyle().height(10.0).grow(1.0)),
    @view.box(style=@style.BoxStyle().height(30.0).grow(3.0)),
    @view.box(style=@style.BoxStyle().height(20.0).shrink(0.0)),
  ])
  let layout = view.layout(
    size=Size(width=100.0, height=160.0),
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(layout.children.map(child => child.height), [35.0, 105.0, 20.0])
  assert_eq(layout.children.map(child => child.y), [0.0, 35.0, 140.0])
}

///|
test "grow and shrink redistribute remaining space when a sibling reaches its bound" {
  let grow = @view.row([
    @view.box(style=@style.BoxStyle().width(20.0).grow(1.0).max_width(60.0)),
    @view.box(style=@style.BoxStyle().width(20.0).grow(1.0)),
  ])
  let shrink = @view.row([
    @view.box(style=@style.BoxStyle().width(100.0).shrink(1.0).min_width(80.0)),
    @view.box(style=@style.BoxStyle().width(200.0).shrink(1.0).min_width(0.0)),
  ])
  let system = test_text_layout_system()
  let size = @foundation.Size(width=200.0, height=20.0)
  assert_eq(
    grow.layout(size~, text_layout_system=system).children.map(child => {
      child.width
    }),
    [60.0, 140.0],
  )
  assert_eq(
    shrink.layout(size~, text_layout_system=system).children.map(child => {
      child.width
    }),
    [80.0, 120.0],
  )
}

///|
test "shrink is weighted by preferred size and zero keeps a control fixed" {
  let view = @view.row([
    @view.box(style=@style.BoxStyle().width(100.0).shrink(2.0).min_width(0.0)),
    @view.box(style=@style.BoxStyle().width(200.0).shrink(1.0).min_width(0.0)),
  ])
  let layout = view.layout(
    size=Size(width=200.0, height=32.0),
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(layout.children.map(child => child.width), [50.0, 150.0])
  let fixed = @view.row([
    @controls.text_input(
      style=@controls.TextInputStyle().surface(
        @style.BoxStyle().width(180.0).height(32.0).min_width(0.0),
      ),
    ),
    @controls.button(
      "Run",
      style=@controls.ButtonStyle().surface(
        @style.BoxStyle().width(120.0).height(32.0).shrink(0.0),
      ),
    ),
  ])
  let layout = fixed.layout(
    size=Size(width=200.0, height=32.0),
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(layout.children.map(child => child.width), [80.0, 120.0])
}

///|
test "outer bounds apply to all styled built-ins" {
  let style = @style.BoxStyle()
    .width(200.0)
    .height(100.0)
    .min_width(40.0)
    .max_width(80.0)
    .min_height(20.0)
    .max_height(60.0)
    .padding(@foundation.Insets::all(5.0))
    .shrink(0.0)
  for
    child in [
      @view.box(style~),
      @view.fill_box(100.0, style~),
      @view.text("ABC", style=@view.TextStyle().frame(style)),
      @controls.button("ABC", style=@controls.ButtonStyle().surface(style)),
      @controls.text_input(style=@controls.TextInputStyle().surface(style)),
      @controls.checkbox(
        label="ABC",
        style=@controls.CheckboxStyle().frame(style),
      ),
      @controls.radio(label="ABC", style=@controls.RadioStyle().frame(style)),
      @view.row([], style=@view.FlexStyle().surface(style)),
      @view.column([], style=@view.FlexStyle().surface(style)),
      @view.scroll_view(
        @view.box(style=@style.BoxStyle().height(200.0)),
        style~,
      ),
    ] {
    let view = @view.column([child])
    let layout = view.layout(
      size=Size(width=300.0, height=150.0),
      text_layout_system=test_text_layout_system(),
    )
    assert_eq(layout.children[0].width, 80.0)
    assert_eq(layout.children[0].height, 60.0)
  }
}

///|
test "minimum bounds win over maximum bounds and may overflow the parent" {
  let view = @view.column([
    @view.box(
      style=@style.BoxStyle()
        .width(10.0)
        .height(10.0)
        .min_width(80.0)
        .max_width(50.0)
        .min_height(40.0)
        .max_height(20.0),
    ),
  ])
  let layout = view.layout(
    size=Size(width=60.0, height=30.0),
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(layout.children[0].width, 80.0)
  assert_eq(layout.children[0].height, 40.0)
}

///|
test "host root allocation overrides root bounds at initial layout and resize" {
  let view = @view.column(
    [],
    style=@view.FlexStyle().surface(
      @style.BoxStyle()
      .min_width(200.0)
      .max_width(240.0)
      .min_height(200.0)
      .max_height(240.0),
    ),
  )
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  for
    size in [
      @foundation.Size(width=100.0, height=80.0),
      Size(width=300.0, height=180.0),
    ] {
    let layout = state.layout(view, size~)
    assert_eq(layout.width, size.width)
    assert_eq(layout.height, size.height)
  }
}

///|
test "flex widths reflow text and keep sibling paint and input positions consistent on resize" {
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.row([
          @view.text(
            "abcdefghij",
            style=@view.TextStyle().frame(
              @style.BoxStyle()
              .grow(1.0)
              .min_width(0.0)
              .max_width(60.0)
              .font(@foundation.FontSpec::default().size(10.0)),
            ),
          ),
          @controls.button(
            "Go",
            on_click=fn() { clicks.val += 1 },
            style=@controls.ButtonStyle().surface(
              @style.BoxStyle()
              .width(40.0)
              .height(12.5)
              .shrink(0.0)
              .font(@foundation.FontSpec::default().size(10.0)),
            ),
          ),
        ]),
        @controls.button(
          "Next",
          style=@controls.ButtonStyle().surface(@style.BoxStyle().height(10.0)),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  for
    (width, height, text_width, lines) in [
      (70.0, 25.0, 30.0, ["abcde", "fghij"]),
      (100.0, 12.5, 60.0, ["abcdefghij"]),
      (160.0, 12.5, 60.0, ["abcdefghij"]),
    ] {
    let size = @foundation.Size(width~, height=100.0)
    assert_true(root.click_at(size~, point=Point(x=text_width + 5.0, y=5.0)))
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    let snapshot = root.snapshot().unwrap().tree
    assert_eq(snapshot.nodes[1].frame.size.height, height)
    assert_eq(snapshot.nodes[2].frame.size.width, text_width)
    assert_eq(snapshot.nodes[4].frame.origin.y, height)
    assert_eq(
      recorder.runs
      .filter(run => run.text != "Go" && run.text != "Next")
      .map(run => run.text),
      lines,
    )
    assert_eq(
      snapshot.nodes[2].specified_style.unwrap().layout.flex.grow,
      Some(1.0),
    )
  }
  assert_eq(clicks.val, 3)
}

///|
test "growing bounded ScrollView fills remaining height and preserves content scroll and hit geometry" {
  let offset = @reactive.signal(0.0)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button(
          "Header",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().height(30.0).shrink(0.0),
          ),
        ),
        @view.scroll_view(
          @view.column(
            Array::makei(8, i => {
              @controls.button(
                "Row \{i}",
                on_click=fn() { clicks.val += 1 },
                style=@controls.ButtonStyle().surface(
                  @style.BoxStyle().height(20.0).shrink(0.0),
                ),
              )
            }),
          ),
          offset~,
          style=@style.BoxStyle().grow(1.0).min_height(0.0).max_height(100.0),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  let mut viewport_id = None
  for
    (height, viewport_height, maximum) in [
      (90.0, 60.0, 100.0),
      (140.0, 100.0, 60.0),
      (200.0, 100.0, 60.0),
    ] {
    let size = @foundation.Size(width=100.0, height~)
    offset.set(0.0)
    assert_true(
      root.scroll_at(
        size~,
        point=Point(x=10.0, y=40.0),
        delta=Point(x=0.0, y=200.0),
      ),
    )
    root.paint(recorder, size~)
    let viewport = root.snapshot().unwrap().tree.nodes[2]
    if viewport_id is Some(id) {
      assert_eq(viewport.id, id)
    } else {
      viewport_id = Some(viewport.id)
    }
    assert_eq(viewport.frame.origin.y, 30.0)
    assert_eq(viewport.frame.size.height, viewport_height)
    assert_eq(viewport.scroll.unwrap().content_size.height, 160.0)
    assert_eq(viewport.scroll.unwrap().max_offset, maximum)
    assert_eq(viewport.scroll.unwrap().offset, maximum)
    assert_eq(
      viewport.specified_style.unwrap().layout.layout.max_height,
      Some(100.0),
    )
    assert_true(
      root.click_at(size~, point=Point(x=10.0, y=30.0 + viewport_height - 10.0)),
    )
  }
  assert_eq(clicks.val, 3)
}
