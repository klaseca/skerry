///|
test "select caches rule families independently from tokens fonts and other families" {
  let calls = Ref(0)
  let style = PanelStyle().select(fn(s) {
    calls.val += 1
    s.title
  })
  let rules = @style.Styles().add(
    PanelStyle().title(@view.TextStyle().color(@foundation.Color::white())),
  )
  let root = @runtime.mount(
    fn() { @view.text("Title", style~) },
    theme=Theme(styles=rules),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=80.0)
  root.paint(StyleRecorder(), size~)
  let initial = calls.val
  root.paint(StyleRecorder(), size~)
  ignore(root.snapshot())
  root.set_theme(Theme(styles=rules, palette=@style.Palette::dark()))
  root.paint(StyleRecorder(), size~)
  root.set_theme(
    Theme(styles=rules, font=@foundation.FontSpec::default().size(24.0)),
  )
  root.paint(StyleRecorder(), size~)
  root.set_theme(
    Theme(
      styles=rules.add(
        @controls.ButtonStyle().surface(@style.BoxStyle().radius(12.0)),
      ),
    ),
  )
  root.paint(StyleRecorder(), size~)
  assert_eq(calls.val, initial)
  root.set_theme(
    Theme(
      styles=@style.Styles().add(
        PanelStyle().title(@view.TextStyle().color(@foundation.Color::black())),
      ),
    ),
  )
  assert_true(calls.val > initial)
  let after = calls.val
  root.paint(StyleRecorder(), size~)
  ignore(root.snapshot())
  assert_eq(calls.val, after)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().color,
    Some(@foundation.Color::black()),
  )
}

///|
test "select tracks signals and separates layout from paint then disposes" {
  let width = @reactive.signal(60.0)
  let dark = @reactive.signal(false)
  let calls = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.box(
            style=PanelStyle().select(fn(_) {
              calls.val += 1
              @style.BoxStyle()
              .width(width.get())
              .height(20.0)
              .background(
                if dark.get() {
                  @foundation.Color::black()
                } else {
                  @foundation.Color::white()
                },
              )
            }),
          ),
        ],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=300.0, height=120.0)
  root.paint(StyleRecorder(), size~)
  let before = root.frame_stats().layout_count
  let id = root.snapshot().unwrap().tree.nodes[1].id
  dark.set(true)
  assert_eq(root.dirty(), NeedsPaint)
  let after_update = calls.val
  root.paint(StyleRecorder(), size~)
  assert_eq(root.frame_stats().layout_count, before)
  assert_eq(calls.val, after_update)
  width.set(110.0)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 110.0)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].id, id)
  root.dispose()
  let disposed_calls = calls.val
  width.set(200.0)
  dark.set(false)
  assert_eq(calls.val, disposed_calls)
}

///|
test "computed concrete style updates multiple projections without rebuilding state" {
  let large = @reactive.signal(false)
  let builds = Ref(0)
  let producers = Ref(0)
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      let style : PanelStyle = @style.SourceStyle::computed(fn() {
        producers.val += 1
        PanelStyle()
        .surface(
          @view.FlexStyle().padding(
            @foundation.Insets::all(if large.get() { 20.0 } else { 8.0 }),
          ),
        )
        .title(
          @view.TextStyle().font(
            @foundation.FontSpec::default().size(
              if large.get() {
                26.0
              } else {
                16.0
              },
            ),
          ),
        )
      })
      panel("Title", @controls.text_input(value~), style~)
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=160.0)
  root.paint(StyleRecorder(), size~)
  let before = root.snapshot().unwrap().tree.nodes
  let old_producers = producers.val
  assert_eq(old_producers, 1)
  large.set(true)
  assert_eq(producers.val, old_producers + 1)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(StyleRecorder(), size~)
  let after = root.snapshot().unwrap().tree.nodes
  assert_eq(after[0].padding, @foundation.Insets::all(20.0))
  assert_eq(
    after[1].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default().size(26.0)),
  )
  for i in 0..<before.length() {
    assert_eq(before[i].id, after[i].id)
  }
  assert_eq(builds.val, 1)
  assert_eq(value.get(), "abc")
}

///|
test "separate projected instances keep independent source state in two roots" {
  let key = @reactive.Context(10.0)
  let change = @reactive.signal(0.0)
  let reads = Ref(0)
  let child = fn() {
    @view.box(
      style=PanelStyle().select(fn(_) {
        reads.val += 1
        @style.BoxStyle().width(key.get() + change.get()).height(20.0)
      }),
    )
  }
  let make = fn(amount) {
    @runtime.mount(
      fn() {
        @view.column([child()], style=@view.FlexStyle().align_items(Start))
      },
      providers=[key.provide(amount)],
      text_layout_system=test_text_layout_system(),
    )
  }
  let first = make(40.0)
  let second = make(90.0)
  defer second.dispose()
  let size = @foundation.Size(width=300.0, height=120.0)
  first.paint(StyleRecorder(), size~)
  second.paint(StyleRecorder(), size~)
  assert_eq(first.snapshot().unwrap().tree.nodes[1].frame.size.width, 40.0)
  assert_eq(second.snapshot().unwrap().tree.nodes[1].frame.size.width, 90.0)
  change.set(5.0)
  first.paint(StyleRecorder(), size~)
  second.paint(StyleRecorder(), size~)
  assert_eq(first.snapshot().unwrap().tree.nodes[1].frame.size.width, 45.0)
  assert_eq(second.snapshot().unwrap().tree.nodes[1].frame.size.width, 95.0)
  first.dispose()
  let count = reads.val
  change.set(7.0)
  assert_eq(reads.val, count + 1)
  second.paint(StyleRecorder(), size~)
  assert_eq(second.snapshot().unwrap().tree.nodes[1].frame.size.width, 97.0)
}

///|
test "late keyed children consume the latest projected theme" {
  let items = @reactive.signal([1])
  let theme = fn(size) {
    @style.Theme(
      styles=@style.Styles().add(
        PanelStyle().title(
          @view.TextStyle().font(@foundation.FontSpec::default().size(size)),
        ),
      ),
    )
  }
  let style = PanelStyle()
  let root = @runtime.mount(
    fn() {
      @view.for_each(fn() { items.get() }, fn(item) { item }, fn(_) {
        @view.text("Item", style=style.select(s => s.title))
      })
    },
    theme=theme(16.0),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=160.0)
  root.paint(StyleRecorder(), size~)
  let id = root.snapshot().unwrap().tree.nodes[1].id
  root.set_theme(theme(24.0))
  items.set([1, 2])
  root.paint(StyleRecorder(), size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].id, id)
  assert_eq(
    nodes[1].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default().size(24.0)),
  )
  assert_eq(
    nodes[2].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default().size(24.0)),
  )
}

///|
test "scoped projected rules update independently from their parent sheet" {
  let size = @reactive.signal(18.0)
  let theme = @reactive.computed(fn() {
    @style.Theme(
      styles=@style.Styles().add(
        PanelStyle().title(
          @view.TextStyle().font(
            @foundation.FontSpec::default().size(size.get()),
          ),
        ),
      ),
    )
  })
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.style_scope(light_theme=theme, fn() {
          @view.text("Scoped", style=PanelStyle().select(s => s.title))
        }),
        @view.text("Outside", style=PanelStyle().select(s => s.title)),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let viewport = @foundation.Size(width=300.0, height=160.0)
  root.paint(StyleRecorder(), size=viewport)
  size.set(27.0)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(StyleRecorder(), size=viewport)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(
    nodes[1].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default().size(27.0)),
  )
  assert_eq(
    nodes[2].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default()),
  )
}

///|
test "numeric style properties accept signals and computeds directly" {
  let width = @reactive.signal(40.0)
  let height = @reactive.computed(fn() { width.get() / 2.0 })
  let gap = @reactive.signal(4.0)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.box(style=@style.BoxStyle().width(width).height(height)),
          @view.text("Text", style=@view.TextStyle().width(width)),
        ],
        style=@view.FlexStyle().align_items(Start).spacing(gap),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=180.0)
  root.paint(StyleRecorder(), size~)
  width.set(100.0)
  gap.set(9.0)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(StyleRecorder(), size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[0].computed_style.unwrap().spacing, Some(9.0))
  assert_eq(nodes[1].frame.size.width, 100.0)
  assert_eq(nodes[1].frame.size.height, 50.0)
  assert_eq(nodes[2].frame.size.width, 100.0)
}

///|
test "typed theme rules switch between static and reactive sources without leaking" {
  let width = @reactive.signal(70.0)
  let calls = Ref(0)
  let dynamic = @style.BoxStyle::computed(fn() {
    calls.val += 1
    @style.BoxStyle().width(width.get())
  })
  let root = @runtime.mount(
    fn() {
      @view.column(
        [@view.box(style=@style.BoxStyle().height(20.0))],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=300.0, height=120.0)
  root.paint(StyleRecorder(), size~)
  root.set_theme(Theme(styles=@style.Styles().add(dynamic)))
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 70.0)
  width.set(95.0)
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 95.0)
  root.set_theme(
    Theme(styles=@style.Styles().add(@style.BoxStyle().width(40.0))),
  )
  root.paint(StyleRecorder(), size~)
  let before = calls.val
  width.set(110.0)
  assert_eq(root.dirty(), Clean)
  assert_eq(calls.val, before)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 40.0)
  root.set_theme(Theme(styles=@style.Styles().add(dynamic)))
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 110.0)
  root.dispose()
  let stopped = calls.val
  width.set(120.0)
  assert_eq(calls.val, stopped)
}

///|
test "nested live label keeps the same state priority as a literal label" {
  let white = @foundation.Color::white()
  let black = @foundation.Color::black()
  let calls = Ref(0)
  let label = @view.TextStyle::computed(fn() {
    calls.val += 1
    @view.TextStyle().color(white)
  })
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button(
          "Live",
          style=@controls.ButtonStyle()
            .label(label)
            .hovered(@style.Appearance().color(black)),
        ),
        @controls.button(
          "Literal",
          style=@controls.ButtonStyle()
            .label(@view.TextStyle().color(white))
            .hovered(@style.Appearance().color(black)),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=300.0, height=160.0)
  root.paint(renderer, size~)
  let before = calls.val
  let nodes = root.snapshot().unwrap().tree.nodes
  ignore(root.pointer_move(size~, point=nodes[1].frame.origin))
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[1].computed_style.unwrap().color,
    Some(white),
  )
  ignore(root.pointer_move(size~, point=nodes[2].frame.origin))
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[2].computed_style.unwrap().color,
    Some(white),
  )
  assert_eq(calls.val, before)
}

///|
test "nested live placeholder and indicator freeze metrics before paint" {
  let value = @reactive.signal(18.0)
  let calls = Ref(0)
  let placeholder = @view.TextStyle::computed(fn() {
    calls.val += 1
    @view.TextStyle()
    .font(@foundation.FontSpec::default().size(value.get()))
    .align(TextEnd)
  })
  let indicator = @style.BoxStyle::computed(fn() {
    @style.BoxStyle().width(value.get()).height(value.get())
  })
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.text_input(
          placeholder="Hint",
          style=@controls.TextInputStyle().placeholder(placeholder),
        ),
        @controls.checkbox(
          label="Check",
          style=@controls.CheckboxStyle().indicator(indicator),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=300.0, height=180.0)
  root.paint(renderer, size~)
  value.set(28.0)
  assert_eq(root.dirty(), NeedsLayout)
  let before = calls.val
  root.paint(renderer, size~)
  ignore(root.snapshot())
  assert_eq(calls.val, before)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(
    nodes[1].computed_style.unwrap().placeholder_font,
    Some(@foundation.FontSpec::default().size(28.0)),
  )
  assert_eq(
    nodes[2].computed_style.unwrap().indicator_size,
    Some(@foundation.Size(width=28.0, height=28.0)),
  )
}

///|
test "equal nested source results leave a painted root clean" {
  let change = @reactive.signal(0)
  let label = @view.TextStyle::computed(fn() {
    ignore(change.get())
    @view.TextStyle().color(@foundation.Color::white())
  })
  let root = @runtime.mount(
    fn() {
      @controls.button("Label", style=@controls.ButtonStyle().label(label))
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(StyleRecorder(), size=@foundation.Size(width=200.0, height=60.0))
  assert_eq(root.dirty(), Clean)
  change.set(1)
  assert_eq(root.dirty(), Clean)
}

///|
test "custom hosts share their layout state's style sheet" {
  let size = @reactive.signal(18.0)
  let input = @view.text("Title", style=PanelStyle().select(s => s.title))
  let state = @view.LayoutState(
    text_layout_system=test_text_layout_system(),
    theme=@style.Theme(
      styles=@style.Styles().add(
        PanelStyle().title(
          @view.TextStyle().font(@foundation.FontSpec::default().size(22.0)),
        ),
      ),
    ),
  )
  let stop = input.mount_reactivity(
    style_sheet=state.style_sheet(),
    mark_layout_dirty=fn() { state.invalidate() },
    mark_paint_dirty=fn() { () },
  )
  defer stop()
  let viewport = @foundation.Size(width=200.0, height=80.0)
  let paint = fn() {
    state.paint(input, StyleRecorder(), size=viewport, focused_path=None)
  }
  paint()
  ignore(
    state.set_theme(
      @style.Theme(
        styles=@style.Styles().add(
          PanelStyle().title(
            @view.TextStyle::computed(fn() {
              @view.TextStyle().font(
                @foundation.FontSpec::default().size(size.get()),
              )
            }),
          ),
        ),
      ),
    ),
  )
  paint()
  let before = state.layout_count()
  size.set(28.0)
  assert_true(state.needs_layout())
  paint()
  assert_true(state.layout_count() > before)
}

///|
test "a prebuilt projected view follows its later visual theme scope" {
  let child = @view.text("Prebuilt", style=PanelStyle().select(s => s.title))
  let font = @reactive.signal(20.0)
  let theme = @reactive.computed(fn() {
    @style.Theme(
      styles=@style.Styles().add(
        PanelStyle().title(
          @view.TextStyle().font(
            @foundation.FontSpec::default().size(font.get()),
          ),
        ),
      ),
    )
  })
  let root = @runtime.mount(
    fn() { @view.style_scope(light_theme=theme, fn() { child }) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=80.0)
  root.paint(StyleRecorder(), size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default().size(20.0)),
  )
  font.set(28.0)
  root.paint(StyleRecorder(), size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default().size(28.0)),
  )
}
