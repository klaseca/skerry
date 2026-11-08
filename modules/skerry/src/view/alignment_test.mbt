///|
fn aligned_container(
  horizontal : Bool,
  children : Array[@view.View],
  style : @view.FlexStyle,
) -> @view.View {
  if horizontal {
    @view.row(children, style~)
  } else {
    @view.column(children, style~)
  }
}

///|
test "main axis placement includes padding and fixed spacing on both axes" {
  for horizontal in [true, false] {
    for
      (alignment, first, second) in [
        (@style.JustifyContent::Start, 10.0, 40.0),
        (Center, 55.0, 85.0),
        (End, 100.0, 130.0),
        (SpaceBetween, 10.0, 130.0),
        (SpaceAround, 32.5, 107.5),
        (SpaceEvenly, 40.0, 100.0),
      ] {
      let children = if horizontal {
        [
          @view.box(
            style=@style.BoxStyle().width(20.0).height(10.0).shrink(0.0),
          ),
          @view.box(
            style=@style.BoxStyle().width(40.0).height(10.0).shrink(0.0),
          ),
        ]
      } else {
        [
          @view.box(
            style=@style.BoxStyle().height(20.0).width(10.0).shrink(0.0),
          ),
          @view.box(
            style=@style.BoxStyle().height(40.0).width(10.0).shrink(0.0),
          ),
        ]
      }
      let view = aligned_container(
        horizontal,
        children,
        @view.FlexStyle()
        .justify_content(alignment)
        .spacing(10.0)
        .padding(@foundation.Insets::all(10.0)),
      )
      let size = if horizontal {
        @foundation.Size(width=180.0, height=80.0)
      } else {
        Size(width=80.0, height=180.0)
      }
      let layout = view.layout(
        size~,
        text_layout_system=test_text_layout_system(),
      )
      let positions = layout.children.map(child => {
        if horizontal {
          child.x
        } else {
          child.y
        }
      })
      assert_eq(positions, [first, second])
    }
  }
}

///|
test "distributed main alignment handles one child and an empty container" {
  for horizontal in [true, false] {
    for
      (alignment, position) in [
        (@style.JustifyContent::Start, 10.0),
        (Center, 40.0),
        (End, 70.0),
        (SpaceBetween, 10.0),
        (SpaceAround, 40.0),
        (SpaceEvenly, 40.0),
      ] {
      let child = @view.box(
        style=@style.BoxStyle().width(20.0).height(20.0).shrink(0.0),
      )
      let style = @view.FlexStyle()
        .justify_content(alignment)
        .padding(@foundation.Insets::all(10.0))
      let size = @foundation.Size(width=100.0, height=100.0)
      let layout = aligned_container(horizontal, [child], style).layout(
        size~,
        text_layout_system=test_text_layout_system(),
      )
      assert_eq(
        if horizontal {
          layout.children[0].x
        } else {
          layout.children[0].y
        },
        position,
      )
      let empty = aligned_container(horizontal, [], style).layout(
        size~,
        text_layout_system=test_text_layout_system(),
      )
      assert_true(empty.children.is_empty())
    }
  }
}

///|
test "cross axis alignment uses preferred size or stretches within bounds" {
  for horizontal in [true, false] {
    for
      (alignment, position, cross_size) in [
        (@style.AlignItems::Start, 10.0, 10.0),
        (Center, 35.0, 10.0),
        (End, 60.0, 10.0),
        (Stretch, 10.0, 40.0),
      ] {
      let child_style = if horizontal {
        @style.BoxStyle().width(20.0).height(10.0).max_height(40.0)
      } else {
        @style.BoxStyle().height(20.0).width(10.0).max_width(40.0)
      }
      let view = aligned_container(
        horizontal,
        [@view.box(style=child_style)],
        @view.FlexStyle()
        .align_items(alignment)
        .padding(@foundation.Insets::all(10.0)),
      )
      let size = if horizontal {
        @foundation.Size(width=180.0, height=80.0)
      } else {
        Size(width=80.0, height=180.0)
      }
      let child = view.layout(
          size~,
          text_layout_system=test_text_layout_system(),
        ).children[0]
      assert_eq(if horizontal { child.y } else { child.x }, position)
      assert_eq(if horizontal { child.height } else { child.width }, cross_size)
    }
  }
}

///|
test "align self overrides the parent and Auto restores inheritance on both axes" {
  for horizontal in [true, false] {
    for
      (alignment, position, cross_size) in [
        (@style.AlignSelf::Auto, 35.0, 10.0),
        (Start, 10.0, 10.0),
        (Center, 35.0, 10.0),
        (End, 60.0, 10.0),
        (Stretch, 10.0, 60.0),
      ] {
      let inherited = @style.BoxStyle()
        .width(10.0)
        .height(10.0)
        .align_self(End)
        .merge(@style.BoxStyle().align_self(alignment))
      let view = aligned_container(
        horizontal,
        [@view.box(style=inherited)],
        @view.FlexStyle()
        .align_items(Center)
        .padding(@foundation.Insets::all(10.0)),
      )
      let size = if horizontal {
        @foundation.Size(width=180.0, height=80.0)
      } else {
        Size(width=80.0, height=180.0)
      }
      let child = view.layout(
          size~,
          text_layout_system=test_text_layout_system(),
        ).children[0]
      assert_eq(if horizontal { child.y } else { child.x }, position)
      assert_eq(if horizontal { child.height } else { child.width }, cross_size)
    }
  }
}

///|
test "stretch preserves explicitly sized controls and containers" {
  for horizontal in [true, false] {
    for
      child in [
        @controls.button(
          "X",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(30.0).height(20.0),
          ),
        ),
        @view.row(
          [],
          style=@view.FlexStyle().surface(
            @style.BoxStyle().width(30.0).height(20.0),
          ),
        ),
      ] {
      let view = aligned_container(
        horizontal,
        [child],
        @view.FlexStyle().align_items(Stretch),
      )
      let layout = view.layout(
        size=Size(width=120.0, height=100.0),
        text_layout_system=test_text_layout_system(),
      )
      assert_eq(layout.children[0].width, 30.0)
      assert_eq(layout.children[0].height, 20.0)
    }
  }
}

///|
test "main alignment uses free space left after grow limits and shrink" {
  for horizontal in [true, false] {
    for
      (main_size, first_size, second_position) in [
        (100.0, 30.0, 40.0),
        (160.0, 40.0, 100.0),
      ] {
      let first = if horizontal {
        @view.box(style=@style.BoxStyle().width(20.0).grow(1.0).max_width(40.0))
      } else {
        @view.box(
          style=@style.BoxStyle().height(20.0).grow(1.0).max_height(40.0),
        )
      }
      let second = if horizontal {
        @view.box(style=@style.BoxStyle().width(60.0).shrink(0.0))
      } else {
        @view.box(style=@style.BoxStyle().height(60.0).shrink(0.0))
      }
      let view = aligned_container(
        horizontal,
        [first, second],
        @view.FlexStyle().spacing(10.0).justify_content(SpaceBetween),
      )
      let size = if horizontal {
        @foundation.Size(width=main_size, height=30.0)
      } else {
        Size(width=30.0, height=main_size)
      }
      let layout = view.layout(
        size~,
        text_layout_system=test_text_layout_system(),
      )
      assert_eq(
        if horizontal {
          layout.children[0].width
        } else {
          layout.children[0].height
        },
        first_size,
      )
      assert_eq(
        if horizontal {
          layout.children[1].x
        } else {
          layout.children[1].y
        },
        second_position,
      )
    }
    let first = if horizontal {
      @view.box(style=@style.BoxStyle().width(100.0).min_width(0.0))
    } else {
      @view.box(style=@style.BoxStyle().height(100.0).min_height(0.0))
    }
    let second = if horizontal {
      @view.box(style=@style.BoxStyle().width(100.0).min_width(0.0))
    } else {
      @view.box(style=@style.BoxStyle().height(100.0).min_height(0.0))
    }
    let view = aligned_container(
      horizontal,
      [first, second],
      @view.FlexStyle().justify_content(End),
    )
    let layout = view.layout(
      size=Size(width=100.0, height=100.0),
      text_layout_system=test_text_layout_system(),
    )
    assert_eq(
      if horizontal {
        layout.children[0].x
      } else {
        layout.children[0].y
      },
      0.0,
    )
    assert_eq(
      if horizontal {
        layout.children[1].x
      } else {
        layout.children[1].y
      },
      50.0,
    )
  }
}

///|
test "cross alignment follows wrapped text height before paint and after resize" {
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.row(
          [
            @view.text(
              "abcdefghij",
              style=@view.TextStyle().frame(
                @style.BoxStyle()
                .grow(1.0)
                .min_width(0.0)
                .font(@foundation.FontSpec::default().size(10.0)),
              ),
            ),
            @controls.button(
              "X",
              on_click=fn() { clicks.val += 1 },
              style=@controls.ButtonStyle().surface(
                @style.BoxStyle()
                .width(40.0)
                .height(10.0)
                .shrink(0.0)
                .padding(@foundation.Insets::all(0.0))
                .font(@foundation.FontSpec::default().size(8.0)),
              ),
            ),
          ],
          style=@view.FlexStyle().align_items(Center),
        ),
        @view.box(style=@style.BoxStyle().height(10.0)),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  for (width, row_height, button_y) in [(70.0, 25.0, 7.5), (100.0, 12.5, 1.25)] {
    let size = @foundation.Size(width~, height=100.0)
    assert_true(!root.click_at(size~, point=Point(x=width - 35.0, y=0.0)))
    assert_true(
      root.click_at(size~, point=Point(x=width - 35.0, y=button_y + 1.0)),
    )
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    let snapshot = root.snapshot().unwrap().tree.nodes
    assert_eq(snapshot[1].frame.size.height, row_height)
    assert_eq(snapshot[3].frame.origin.y, button_y)
    assert_eq(snapshot[4].frame.origin.y, row_height)
  }
  assert_eq(clicks.val, 2)
}

///|
test "aligned paint input and snapshots agree through resize and preserve identity" {
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.row(
        [
          @controls.button(
            "X",
            on_click=fn() { clicks.val += 1 },
            style=@controls.ButtonStyle().surface(
              @style.BoxStyle().width(30.0).height(20.0).shrink(0.0),
            ),
          ),
        ],
        style=@view.FlexStyle()
          .justify_content(End)
          .align_items(Center)
          .padding(@foundation.Insets::all(10.0)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  let mut id = None
  for
    size in [
      @foundation.Size(width=100.0, height=80.0),
      Size(width=160.0, height=100.0),
    ] {
    let x = size.width - 10.0 - 30.0
    let y = (size.height - 20.0) / 2.0
    assert_true(!root.click_at(size~, point=Point(x=5.0, y=5.0)))
    assert_true(root.click_at(size~, point=Point(x=x + 5.0, y=y + 5.0)))
    root.paint(recorder, size~)
    let button = root.snapshot().unwrap().tree.nodes[1]
    if id is Some(previous) {
      assert_eq(button.id, previous)
    } else {
      id = Some(button.id)
    }
    assert_eq(button.frame, Rect(x~, y~, width=30.0, height=20.0))
    assert_true(recorder.fills.any(fill => fill.0 == button.frame))
    let specified = root.snapshot().unwrap().tree.nodes[0].specified_style.unwrap()
    assert_eq(
      (specified.get() : @view.FlexStyle?).unwrap().justify_content,
      Some(End),
    )
    assert_eq(
      (specified.get() : @view.FlexStyle?).unwrap().align_items,
      Some(Center),
    )
  }
  assert_eq(clicks.val, 2)
}

///|
test "aligned ScrollView child and content retain scroll extent and pointer coordinates" {
  let offset = @reactive.signal(0.0)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.scroll_view(
          @view.column(
            Array::makei(8, _ => {
              @controls.button(
                "X",
                on_click=fn() { clicks.val += 1 },
                style=@controls.ButtonStyle().surface(
                  @style.BoxStyle().width(30.0).height(20.0).shrink(0.0),
                ),
              )
            }),
            style=@view.FlexStyle().align_items(Center),
          ),
          offset~,
          style=@style.BoxStyle().width(80.0).height(60.0).align_self(End),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  let size = @foundation.Size(width=140.0, height=120.0)
  assert_true(
    root.scroll_at(
      size~,
      point=Point(x=70.0, y=10.0),
      delta=Point(x=0.0, y=200.0),
    ),
  )
  root.paint(recorder, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].frame.origin.x, 60.0)
  assert_eq(nodes[1].scroll.unwrap().content_size.height, 160.0)
  assert_eq(nodes[1].scroll.unwrap().max_offset, 100.0)
  assert_eq(nodes[2].frame.origin.y, -100.0)
  assert_true(!root.click_at(size~, point=Point(x=65.0, y=50.0)))
  assert_true(root.click_at(size~, point=Point(x=90.0, y=50.0)))
  assert_eq(clicks.val, 1)
}
