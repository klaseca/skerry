///|
test "row layout places children by measured width and spacing" {
  let view : @view.View = @view.row(
    [
      @view.box(style=@style.BoxStyle().width(10.0).height(20.0)),
      @view.box(style=@style.BoxStyle().width(30.0).height(10.0)),
    ],
    style=@view.FlexStyle().spacing(5.0),
  )
  let layout = view.layout(
    size=Size(width=100.0, height=20.0),
    text_layout_system=test_text_layout_system(),
  )
  inspect(layout.children.length(), content="2")
  inspect(layout.children[0].width, content="10")
  inspect(layout.children[1].x, content="15")
  inspect(layout.children[1].height, content="20")
}

///|
test "row and column apply frame size padding spacing and background" {
  let color = @foundation.Color::accent()
  let padding : @foundation.Insets = {
    top: 3.0,
    right: 7.0,
    bottom: 5.0,
    left: 11.0,
  }
  for horizontal in [true, false] {
    let style = @view.FlexStyle()
      .width(120.0)
      .height(60.0)
      .padding(padding)
      .spacing(4.0)
      .background(color)
      .radius(6.0)
    let children = [
      @view.box(style=@style.BoxStyle().width(20.0).height(10.0)),
      @view.box(style=@style.BoxStyle().width(30.0).height(15.0)),
    ]
    let container = if horizontal {
      @view.row(children, style~)
    } else {
      @view.column(children, style~)
    }
    let view = @view.column([container])
    let size = @foundation.Size(width=200.0, height=150.0)
    let layout = view.layout(
      size~,
      text_layout_system=test_text_layout_system(),
    )
    let child = layout.children[0]
    assert_eq((child.width, child.height), (120.0, 60.0))
    assert_eq((child.children[0].x, child.children[0].y), (11.0, 3.0))
    assert_eq(
      (child.children[1].x, child.children[1].y),
      if horizontal {
        (35.0, 3.0)
      } else {
        (11.0, 17.0)
      },
    )
    let root = @runtime.mount(
      fn() { view },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    assert_eq(
      recorder.fills[0],
      (Rect(x=0.0, y=0.0, width=120.0, height=60.0), color, 6.0),
    )
  }
}

///|
test "button and text input include padding once in their natural size" {
  let style = @style.BoxStyle().font(@foundation.FontSpec::default().size(10.0))
  let controls = [
    @controls.button("a", style=@controls.ButtonStyle().surface(style)),
    @controls.text_input(
      value=@reactive.signal("a"),
      style=@controls.TextInputStyle().surface(style),
    ),
    @controls.button(
      "a",
      style=@controls.ButtonStyle().surface(
        style.padding(@foundation.Insets::all(0.0)),
      ),
    ),
  ]
  let size = @foundation.Size(width=200.0, height=150.0)
  let column = @view.column(controls).layout(
    size~,
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(column.children.map(child => child.height), [28.5, 28.5, 12.5])
  let row = @view.row(controls).layout(
    size~,
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(row.children.map(child => child.width), [30.0, 26.0, 6.0])
}

///|
test "control dimensions include their padding" {
  let style = @style.BoxStyle()
    .width(80.0)
    .height(36.0)
    .padding(@foundation.Insets::symmetric(horizontal=9.0, vertical=5.0))
  let view = @view.column([
    @controls.button("Run", style=@controls.ButtonStyle().surface(style)),
    @controls.text_input(
      placeholder="Name",
      style=@controls.TextInputStyle().surface(style),
    ),
  ])
  let size = @foundation.Size(width=200.0, height=150.0)
  let layout = view.layout(size~, text_layout_system=test_text_layout_system())
  assert_eq(layout.children.map(child => (child.width, child.height)), [
    (80.0, 36.0),
    (80.0, 36.0),
  ])
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  root.paint(recorder, size~)
  assert_eq(recorder.fills[0].0.size, Size(width=80.0, height=36.0))
  assert_eq(recorder.fills[1].0.size, Size(width=80.0, height=36.0))
  assert_eq(recorder.runs[1].frame.origin.x, 9.0)
}

///|
test "button layout and paint wrap using the padded content width" {
  let font = @foundation.FontSpec::default().size(10.0)
  let text = "abcdef"
  let style = @style.BoxStyle()
    .font(font)
    .width(32.0)
    .padding(@foundation.Insets::symmetric(horizontal=10.0, vertical=4.0))
  let view = @view.column([
    @controls.button(text, style=@controls.ButtonStyle().surface(style)),
  ])
  let size = @foundation.Size(width=200.0, height=150.0)
  let layout = view.layout(size~, text_layout_system=test_text_layout_system())
  assert_eq((layout.children[0].width, layout.children[0].height), (32.0, 45.5))
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["ab", "cd", "ef"])
  assert_eq(recorder.runs.map(run => run.frame.origin.y), [4.0, 16.5, 29.0])
}

///|
test "button wrapping follows parent width through resize and hit testing" {
  let style = @style.BoxStyle()
    .font(@foundation.FontSpec::default().size(10.0))
    .padding(@foundation.Insets::symmetric(horizontal=10.0, vertical=4.0))
  let clicks : Array[String] = []
  let view = @view.column([
    @controls.button("abcdef", style=@controls.ButtonStyle().surface(style), on_click=fn() {
      clicks.push("button")
    }),
    @view.interactive(
      @view.box(style=@style.BoxStyle().width(20.0).height(10.0)),
      on_click=fn() { clicks.push("next") },
    ),
  ])
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  for
    (width, height, lines) in [
      (32.0, 45.5, ["ab", "cd", "ef"]),
      (56.0, 20.5, ["abcdef"]),
      (32.0, 45.5, ["ab", "cd", "ef"]),
    ] {
    let size = @foundation.Size(width~, height=150.0)
    let layout = state.layout(view, size~)
    assert_eq(
      (layout.children[0].width, layout.children[0].height),
      (width, height),
    )
    assert_eq(layout.children[1].y, height)
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    assert_eq(recorder.runs.map(run => run.text), lines)
    assert_eq(recorder.fills[0].0.size.height, height)
    assert_eq(recorder.runs.last().unwrap().frame.origin.y + 12.5 + 4.0, height)
    assert_true(root.click_at(size~, point=Point(x=10.0, y=height - 1.0)))
    assert_true(root.click_at(size~, point=Point(x=10.0, y=height + 5.0)))
    assert_true(!root.click_at(size~, point=Point(x=10.0, y=height + 11.0)))
  }
  assert_eq(clicks, ["button", "next", "button", "next", "button", "next"])
}

///|
test "wrapped text reflows through nested rows and columns" {
  let style = @style.BoxStyle()
    .font(@foundation.FontSpec::default().size(10.0))
    .padding(@foundation.Insets::all(0.0))
  for button in [false, true] {
    let leaf = if button {
      @controls.button(
        "hello moonbit ui",
        style=@controls.ButtonStyle().surface(style),
      )
    } else {
      @view.text("hello moonbit ui", style=@view.TextStyle().frame(style))
    }
    let mut nested = @view.row([
      leaf,
      @view.box(style=@style.BoxStyle().width(20.0).height(10.0)),
    ])
    for _ in 0..<3 {
      nested = @view.column(
        [nested],
        style=@view.FlexStyle().surface(
          @style.BoxStyle().padding(@foundation.Insets::all(2.0)),
        ),
      )
    }
    let view = @view.column([
      nested,
      @view.box(style=@style.BoxStyle().width(10.0).height(10.0)),
    ])
    let state = @view.LayoutState(text_layout_system=test_text_layout_system())
    let root = @runtime.mount(
      fn() { view },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    for
      (width, leaf_width, height, lines) in [
        (76.0, 44.0, 37.5, ["hello m", "oonbit ", "ui"]),
        (144.0, 96.0, 12.5, ["hello moonbit ui"]),
        (76.0, 44.0, 37.5, ["hello m", "oonbit ", "ui"]),
      ] {
      let size = @foundation.Size(width~, height=200.0)
      let layout = state.layout(view, size~)
      assert_eq(layout.children[0].height, height + 12.0)
      assert_eq(layout.children[1].y, height + 12.0)
      let row = layout.children[0].children[0].children[0].children[0]
      assert_eq(row.height, height)
      assert_eq(
        (row.children[0].width, row.children[0].height),
        (leaf_width, height),
      )
      assert_eq(row.children[1].height, height)
      let recorder = text_color_recorder()
      root.paint(recorder, size~)
      assert_eq(recorder.runs.map(run => run.text), lines)
      assert_eq(
        recorder.runs.last().unwrap().frame.origin.y + 12.5,
        height + 6.0,
      )
    }
  }
}

///|
test "wrapped auto height retains row stretching and explicit dimensions" {
  let style = @style.BoxStyle()
    .font(@foundation.FontSpec::default().size(10.0))
    .padding(@foundation.Insets::all(0.0))
  for button in [false, true] {
    let leaf = if button {
      @controls.button(
        "hello moonbit ui",
        style=@controls.ButtonStyle().surface(style),
      )
    } else {
      @view.text("hello moonbit ui", style=@view.TextStyle().frame(style))
    }
    let row = @view.row([
      leaf,
      @view.box(style=@style.BoxStyle().width(20.0).height(10.0)),
    ])
    let layout = row.layout(
      size=Size(width=100.0, height=80.0),
      text_layout_system=test_text_layout_system(),
    )
    assert_eq(layout.children.map(child => child.height), [80.0, 80.0])
  }
  let view = @view.column([
    @view.text(
      "hello moonbit ui",
      style=@view.TextStyle().frame(style.width(44.0).height(18.0)),
    ),
    @controls.button(
      "abcdef",
      style=@controls.ButtonStyle().surface(style.width(12.0).height(25.0)),
    ),
  ])
  let layout = view.layout(
    size=Size(width=100.0, height=150.0),
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(layout.children.map(child => (child.width, child.height)), [
    (44.0, 18.0),
    (12.0, 25.0),
  ])
  assert_eq(layout.children[1].y, 18.0)
}

///|
test "wrapped text preserves explicit line breaks at parent width" {
  let style = @style.BoxStyle().font(@foundation.FontSpec::default().size(10.0))
  let view = @view.column([
    @view.text("aaaaa\nb", style=@view.TextStyle().frame(style)),
    @view.box(style=@style.BoxStyle().width(10.0).height(10.0)),
  ])
  let size = @foundation.Size(width=12.0, height=150.0)
  let layout = view.layout(size~, text_layout_system=test_text_layout_system())
  assert_eq(layout.children[0].height, 50.0)
  assert_eq(layout.children[1].y, 50.0)
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["aa", "aa", "a", "b"])
  assert_eq(recorder.runs.map(run => run.frame.origin.y), [
    0.0, 12.5, 25.0, 37.5,
  ])
}

///|
test "wrapped text measures the width remaining after row shrink" {
  let style = @style.BoxStyle()
    .font(@foundation.FontSpec::default().size(10.0))
    .width(44.0)
  for button in [false, true] {
    let leaf = if button {
      @controls.button(
        "abcdef",
        style=@controls.ButtonStyle().surface(
          style.padding(@foundation.Insets::all(2.0)),
        ),
      )
    } else {
      @view.text("abcdef", style=@view.TextStyle().frame(style))
    }
    let view = @view.column([
      @view.row([
        leaf,
        @view.box(style=@style.BoxStyle().width(20.0).height(10.0)),
      ]),
      @view.box(style=@style.BoxStyle().width(10.0).height(10.0)),
    ])
    let state = @view.LayoutState(text_layout_system=test_text_layout_system())
    let root = @runtime.mount(
      fn() { view },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let padding = if button { 2.0 } else { 0.0 }
    for
      (width, leaf_width, content_height, lines) in [
        (36.0, 16.0, 37.5, ["ab", "cd", "ef"]),
        (100.0, 44.0, 12.5, ["abcdef"]),
        (36.0, 16.0, 37.5, ["ab", "cd", "ef"]),
      ] {
      let size = @foundation.Size(width~, height=150.0)
      let layout = state.layout(view, size~)
      let height = content_height + padding * 2.0
      assert_eq(
        (layout.children[0].children[0].width, layout.children[0].height),
        (leaf_width, height),
      )
      assert_eq(layout.children[1].y, height)
      let recorder = text_color_recorder()
      root.paint(recorder, size~)
      assert_eq(recorder.runs.map(run => run.text), lines)
      assert_eq(
        recorder.runs.last().unwrap().frame.origin.y + 12.5 + padding,
        height,
      )
    }
  }
}

///|
test "wrapped layout respects narrow frame widths and resets on style changes" {
  let font = @foundation.FontSpec::default().size(10.0)
  for width in [0.0, 1.0, 5.0] {
    let view = @view.column([
      @view.text(
        "ab",
        style=@view.TextStyle().frame(@style.BoxStyle().font(font).width(width)),
      ),
      @controls.button(
        "ab",
        style=@controls.ButtonStyle().surface(
          @style.BoxStyle()
          .font(font)
          .width(width)
          .padding(@foundation.Insets::all(0.0)),
        ),
      ),
    ])
    let layout = view.layout(
      size=Size(width=100.0, height=150.0),
      text_layout_system=test_text_layout_system(),
    )
    assert_eq(layout.children.map(child => child.width), [width, width])
    assert_eq(
      layout.children.map(child => child.height),
      if width == 0.0 {
        [12.5, 12.5]
      } else {
        [25.0, 25.0]
      },
    )
  }
  let large = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.for_each(fn() { [large.get()] }, fn(value) { value }, fn(value) {
          let style = if value() {
            @style.BoxStyle()
            .font(font.size(20.0))
            .padding(
              @foundation.Insets::symmetric(horizontal=2.0, vertical=1.0),
            )
          } else {
            @style.BoxStyle()
            .font(font)
            .padding(
              @foundation.Insets::symmetric(horizontal=10.0, vertical=4.0),
            )
          }
          @controls.button(
            "abcdef",
            style=@controls.ButtonStyle().surface(style),
          )
        }),
        @view.box(style=@style.BoxStyle().width(10.0).height(10.0)),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=32.0, height=150.0)
  for (value, height) in [(false, 45.5), (true, 77.0), (false, 45.5)] {
    large.set(value)
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    assert_eq(recorder.fills[0].0.size.height, height)
    assert_eq(recorder.fills[1].0.origin.y, height)
  }
}

///|
test "dynamic wrapped text moves sibling hit testing before paint" {
  let text = @reactive.signal("abcdef")
  let clicks = Ref(0)
  let style = @style.BoxStyle().font(@foundation.FontSpec::default().size(10.0))
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text_of(text, style=@view.TextStyle().frame(style)),
        @view.interactive(
          @view.box(style=@style.BoxStyle().width(10.0).height(10.0)),
          on_click=fn() { clicks.val += 1 },
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=12.0, height=150.0)
  for
    (value, height, lines) in [
      ("abcdef", 37.5, ["ab", "cd", "ef"]),
      ("a", 12.5, ["a"]),
      ("abcdef", 37.5, ["ab", "cd", "ef"]),
    ] {
    text.set(value)
    assert_true(root.click_at(size~, point=Point(x=5.0, y=height + 5.0)))
    assert_true(!root.click_at(size~, point=Point(x=5.0, y=height + 11.0)))
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    assert_eq(recorder.runs.map(run => run.text), lines)
    assert_eq(recorder.fills.last().unwrap().0.origin.y, height)
  }
  assert_eq(clicks.val, 3)
}

///|
test "wrapped auto height handles a zero advance and equal intrinsic widths" {
  let text_layout_system = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      let carets : Array[Double] = [0.0]
      let mut width = 0.0
      for char in input.text {
        if char != '\u0301' {
          width += 6.0
        }
        carets.push(width)
      }
      TextMetrics(
        width~,
        line_height=12.5,
        baseline=10.0,
        caret_positions=carets,
      )
    }),
  )
  let text = "a\u0301"
  let font = @foundation.FontSpec::default().size(10.0)
  let expected = text_layout_system.layout(
    TextLayoutInput(text~, font~, max_width=Some(1.0)),
  )
  assert_eq(expected.size.height, 25.0)
  let style = @style.BoxStyle().font(font).padding(@foundation.Insets::all(0.0))
  let view = @view.column([
    @view.text(text, style=@view.TextStyle().frame(style)),
    @controls.button(text, style=@controls.ButtonStyle().surface(style)),
  ])
  let size = @foundation.Size(width=1.0, height=150.0)
  let layout = view.layout(size~, text_layout_system~)
  assert_eq(layout.children.map(child => child.height), [
    expected.size.height,
    expected.size.height,
  ])
  assert_eq(layout.children[1].y, expected.size.height)
}

///|
test "text input keeps a single line height when its value exceeds the width" {
  let style = @style.BoxStyle()
    .font(@foundation.FontSpec::default().size(10.0))
    .width(32.0)
    .padding(@foundation.Insets::symmetric(horizontal=10.0, vertical=4.0))
  let view = @view.column([
    @controls.text_input(
      value=@reactive.signal("abcdef"),
      style=@controls.TextInputStyle().surface(style),
    ),
    @controls.text_input(
      placeholder="abcdef",
      style=@controls.TextInputStyle().surface(style),
    ),
  ])
  let size = @foundation.Size(width=200.0, height=150.0)
  let layout = view.layout(size~, text_layout_system=test_text_layout_system())
  assert_eq(layout.children.map(child => (child.width, child.height)), [
    (32.0, 20.5),
    (32.0, 20.5),
  ])
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["abcdef", "abcdef"])
  assert_eq(recorder.runs.map(run => run.frame.size.height), [12.5, 12.5])
}

///|
test "checkbox and radio captions wrap at the remaining width during resize" {
  let style = @style.BoxStyle().font(@foundation.FontSpec::default().size(10.0))
  for radio in [false, true] {
    let control = if radio {
      @controls.radio(label="abcdef", style=@controls.RadioStyle().frame(style))
    } else {
      @controls.checkbox(
        label="abcdef",
        style=@controls.CheckboxStyle().frame(style),
      )
    }
    let view = @view.column([
      control,
      @view.interactive(
        @view.box(style=@style.BoxStyle().width(10.0).height(10.0)),
        on_click=fn() { () },
      ),
    ])
    let state = @view.LayoutState(text_layout_system=test_text_layout_system())
    let root = @runtime.mount(
      fn() { view },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    for
      (width, height, lines) in [
        (38.0, 37.5, ["ab", "cd", "ef"]),
        (62.0, 18.0, ["abcdef"]),
        (38.0, 37.5, ["ab", "cd", "ef"]),
      ] {
      let size = @foundation.Size(width~, height=150.0)
      let layout = state.layout(view, size~)
      assert_eq(
        (layout.children[0].width, layout.children[0].height),
        (width, height),
      )
      assert_eq(layout.children[1].y, height)
      let recorder = text_color_recorder()
      root.paint(recorder, size~)
      assert_eq(recorder.runs.map(run => run.text), lines)
      assert_true(recorder.runs.last().unwrap().frame.origin.y + 12.5 <= height)
      assert_true(root.click_at(size~, point=Point(x=5.0, y=height - 1.0)))
      assert_true(root.click_at(size~, point=Point(x=5.0, y=height + 5.0)))
    }
    let empty = if radio {
      @controls.radio(style=@controls.RadioStyle().frame(style))
    } else {
      @controls.checkbox(style=@controls.CheckboxStyle().frame(style))
    }
    let layout = @view.column([empty]).layout(
      size=Size(width=100.0, height=150.0),
      text_layout_system=test_text_layout_system(),
    )
    assert_eq(layout.children[0].height, 18.0)
  }
}
