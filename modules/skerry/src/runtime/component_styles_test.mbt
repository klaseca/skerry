///|
test "theme class styles share layout paint fonts and specified style stays local" {
  let font = @foundation.FontSpec::default().size(20.0)
  let input_font = font.size(18.0)
  let theme = @style.Theme(
    styles=@style.Styles()
      .add(
        @controls.ButtonStyle().surface(
          @style.BoxStyle()
          .width(120.0)
          .height(48.0)
          .padding(@foundation.Insets::all(10.0))
          .font(font)
          .radius(12.0),
        ),
      )
      .add(@controls.ButtonStyle().surface(@style.BoxStyle().radius(8.0)))
      .add(
        @controls.TextInputStyle().surface(
          @style.BoxStyle()
          .width(180.0)
          .height(44.0)
          .padding(@foundation.Insets::symmetric(horizontal=20.0, vertical=6.0))
          .font(input_font),
        ),
      ),
  )
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.button("ab"),
          @controls.text_input(value=@reactive.signal("abc")),
          @controls.button(
            "local",
            style=@controls.ButtonStyle().surface(
              @style.BoxStyle()
              .width(100.0)
              .padding(@foundation.Insets::all(0.0))
              .radius(0.0),
            ),
          ),
          @view.text("plain"),
        ],
        style=@view.FlexStyle().surface(@style.BoxStyle().font(font.size(30.0))),
      )
    },
    theme~,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=300.0, height=300.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  let button = nodes[1]
  let input = nodes[2]
  let explicit = nodes[3]
  assert_eq(button.frame.size, Size(width=120.0, height=48.0))
  assert_eq(button.padding, @foundation.Insets::all(10.0))
  assert_eq(button.computed_style.unwrap().font, Some(font))
  assert_eq(button.computed_style.unwrap().radius, Some(8.0))
  assert_eq(button.specified_style.unwrap().layout.layout.width, None)
  assert_eq(input.frame.size, Size(width=180.0, height=44.0))
  assert_eq(input.padding.left, 20.0)
  assert_eq(input.computed_style.unwrap().font, Some(input_font))
  assert_eq(renderer.text[1].frame.origin.x, input.content.origin.x)
  assert_eq(renderer.text[1].font, input_font)
  assert_eq(explicit.frame.size, Size(width=100.0, height=48.0))
  assert_eq(explicit.padding, @foundation.Insets::all(0.0))
  assert_eq(explicit.computed_style.unwrap().radius, Some(0.0))
  assert_eq(nodes[4].computed_style.unwrap().font, Some(font.size(30.0)))
}

///|
test "later normal declarations beat earlier states and local styles win" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=20, g=150, b=50)
  let blue = @foundation.Color::rgb(r=30, g=60, b=180)
  let theme = @style.Theme(
    styles=@style.Styles()
      .add(
        @controls.ButtonStyle().surface(
          @style.BoxStyle()
          .background(red)
          .hovered(@style.Appearance().background(green)),
        ),
      )
      .add(@controls.ButtonStyle().surface(@style.BoxStyle().background(blue))),
  )
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("theme"),
        @controls.button(
          "local",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().background(red),
          ),
        ),
      ])
    },
    theme~,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=120.0)
  root.paint(renderer, size~)
  ignore(root.pointer_move(size~, point=Point(x=5.0, y=5.0)))
  root.paint(renderer, size~)
  let first = root.snapshot().unwrap().tree.nodes[1]
  assert_true(first.state.hovered)
  assert_eq(first.computed_style.unwrap().background, Some(blue))
  ignore(root.pointer_move(size~, point=Point(x=5.0, y=45.0)))
  root.paint(renderer, size~)
  let second = root.snapshot().unwrap().tree.nodes[2]
  assert_true(second.state.hovered)
  assert_eq(second.computed_style.unwrap().background, Some(red))
}

///|
test "disabled class style colors fade once and explicit disabled overrides stay literal" {
  let color = @foundation.Color::accent()
  let white = @foundation.Color::white()
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "disabled",
        disabled=true,
        style=@controls.ButtonStyle().surface(
          @style.BoxStyle().disabled(@style.Appearance().radius(3.0)),
        ),
      )
    },
    theme=Theme(
      styles=@style.Styles()
        .add(
          @controls.ButtonStyle().surface(
            @style.BoxStyle()
            .background(color)
            .hovered(@style.Appearance().background(white))
            .disabled(@style.Appearance().color(white)),
          ),
        )
        .add(@controls.ButtonStyle().surface(@style.BoxStyle().radius(10.0))),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(StyleRecorder(), size=Size(width=120.0, height=50.0))
  let applied = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
  assert_eq(applied.background, Some({ ..color, a: 0.45, }))
  assert_eq(applied.color, Some(white))
  assert_eq(applied.radius, Some(3.0))
}

///|
test "theme metrics update without rebuilding and removed class styles restore defaults" {
  let builds = Ref(0)
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      @view.column([@controls.button("ab"), @controls.text_input(value~)])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=260.0, height=200.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  let theme = @style.Theme(
    styles=@style.Styles()
      .add(
        @controls.ButtonStyle().surface(
          @style.BoxStyle().height(60.0).padding(@foundation.Insets::all(16.0)),
        ),
      )
      .add(
        @controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).padding(@foundation.Insets::all(14.0)),
        ),
      ),
  )
  root.set_theme(theme)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let changed = root.snapshot().unwrap()
  assert_eq(changed.tree.nodes[1].frame.size.height, 60.0)
  assert_eq(changed.tree.nodes[2].frame.size.width, 180.0)
  assert_eq(root.copy_text(), Some("abc"))
  assert_eq(value.get(), "abc")
  for i in 0..<before.tree.nodes.length() {
    assert_eq(before.tree.nodes[i].id, changed.tree.nodes[i].id)
  }
  root.set_theme(Theme())
  root.paint(renderer, size~)
  let restored = root.snapshot().unwrap()
  assert_eq(restored.tree.nodes[1].frame, before.tree.nodes[1].frame)
  assert_eq(restored.tree.nodes[2].frame, before.tree.nodes[2].frame)
  assert_eq(restored.tree.nodes[2].padding, before.tree.nodes[2].padding)
  assert_eq(root.copy_text(), Some("abc"))
  assert_eq(builds.val, 1)
}

///|
test "paint only class styles and shadowed metric declarations retain layout cache" {
  let root = @runtime.mount(
    fn() { @controls.button("ab") },
    theme=Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().width(120.0)),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=60.0)
  root.paint(renderer, size~)
  let before = root.frame_stats()
  root.set_theme(
    Theme(
      styles=@style.Styles()
        .add(@controls.ButtonStyle().surface(@style.BoxStyle().width(300.0)))
        .add(
          @controls.ButtonStyle().surface(
            @style.BoxStyle()
            .width(120.0)
            .background(@foundation.Color::black()),
          ),
        ),
    ),
  )
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  let after = root.frame_stats()
  assert_eq(after.layout_count, before.layout_count)
  assert_eq(after.text_measure_count, before.text_measure_count)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().background,
    Some(@foundation.Color::black()),
  )
}

///|
test "pointer uses updated theme padding and font before the next paint" {
  let value = @reactive.signal("abcd")
  let root = @runtime.mount(
    fn() { @controls.text_input(value~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=220.0, height=80.0)
  root.paint(StyleRecorder(), size~)
  root.set_theme(
    Theme(
      styles=@style.Styles().add(
        @controls.TextInputStyle().surface(
          @style.BoxStyle()
          .padding(@foundation.Insets::all(40.0))
          .font(@foundation.FontSpec::default().size(20.0)),
        ),
      ),
    ),
  )
  assert_true(root.pointer_down(size~, point=Point(x=43.0, y=30.0)))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "Xabcd")
}

///|
test "scoped theme class styles update their subtree without leaking to siblings" {
  let scoped = @reactive.signal(
    @style.Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().height(48.0)),
      ),
    ),
  )
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.style_scope(light_theme=scoped, inherit_styles=false, fn() {
          @controls.button("inside")
        }),
        @controls.button("outside"),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=200.0)
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.height, 48.0)
  scoped.set(
    Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().height(64.0)),
      ),
    ),
  )
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].frame.size.height, 64.0)
  assert_eq(nodes[2].frame.size.height, 36.0)
}

///|
test "app supplied class style themes follow each host and survive another root disposal" {
  let builds = Ref(0)
  let app = @runtime.App(
    light_theme=@style.Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().height(48.0)),
      ),
    ),
    dark_theme=@style.Theme(
      palette=@style.Palette::dark(),
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().height(64.0)),
      ),
    ),
    content=fn() {
      builds.val += 1
      @view.column([@controls.button("themed")])
    },
  )
  let first = app.mount(
    text_layout_system=test_text_layout_system(),
    system_theme=Light,
  )
  defer first.dispose()
  let second = app.mount(
    text_layout_system=test_text_layout_system(),
    system_theme=Dark,
  )
  defer second.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=100.0)
  first.paint(renderer, size~)
  second.paint(renderer, size~)
  assert_eq(first.snapshot().unwrap().tree.nodes[1].frame.size.height, 48.0)
  assert_eq(second.snapshot().unwrap().tree.nodes[1].frame.size.height, 64.0)
  app.set_theme_mode(Dark)
  assert_eq(first.dirty(), NeedsLayout)
  first.paint(renderer, size~)
  assert_eq(first.snapshot().unwrap().tree.nodes[1].frame.size.height, 64.0)
  first.dispose()
  app.set_theme_mode(Light)
  second.paint(renderer, size~)
  assert_eq(second.snapshot().unwrap().tree.nodes[1].frame.size.height, 48.0)
  assert_eq(builds.val, 2)
}
