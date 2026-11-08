///|
#derive(Eq, Debug, Default)
pub struct SimpleCardStyle {
  surface : @view.FlexStyle
}

///|
fn SimpleCardStyle::SimpleCardStyle() -> SimpleCardStyle {
  Default::default()
}

///|
fn SimpleCardStyle::surface(
  self : SimpleCardStyle,
  value : @view.FlexStyle,
) -> SimpleCardStyle {
  { surface: self.surface.merge(value), }
}

///|
impl @style.StyleSpec for SimpleCardStyle with fn merge(self, other) {
  { surface: self.surface.merge(other.surface), }
}

///|
pub extend SimpleCardStyle with Eq::{equal, not_equal}

///|
pub extend SimpleCardStyle with Debug::{to_repr}

///|
pub extend SimpleCardStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
fn styled_card(children : Array[@view.View]) -> @view.View {
  @view.column(children, style=SimpleCardStyle().select(s => s.surface))
}

///|
test "a concrete composition contract preserves the original node identity and base role" {
  let original = styled_card([])
  let tagged = original
  assert_eq(original.node_id_at_path([]), tagged.node_id_at_path([]))
  let root = @runtime.mount(
    fn() { tagged },
    theme=Theme(
      styles=@style.Styles()
        .add(
          @view.FlexStyle().radius(4.0).background(@foundation.Color::black()),
        )
        .add(SimpleCardStyle().surface(@view.FlexStyle().radius(12.0))),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(StyleRecorder(), size=Size(width=200.0, height=100.0))
  let node = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(node.component_name, "Column")
  assert_eq(node.id, original.node_id_at_path([]).unwrap())
  assert_eq(node.computed_style.unwrap().radius, Some(12.0))
  assert_true(node.style_type is Some(_))
}

///|
test "radio group consumes flex defaults while retaining its logical role" {
  let selected = @reactive.signal(1)
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(selected, [1, 2], label=fn(_value) { "Option" })
    },
    theme=Theme(
      styles=@style.Styles()
        .add(
          @view.FlexStyle().surface(
            @style.BoxStyle().radius(4.0).background(@foundation.Color::black()),
          ),
        )
        .add(
          @view.FlexStyle().padding(@foundation.Insets::all(12.0)).spacing(8.0),
        ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(StyleRecorder(), size=Size(width=200.0, height=100.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes.length(), 3)
  let group = nodes[0]
  assert_eq(group.component_name, "Column")
  assert_eq(group.components[0].name, "RadioGroup")
  assert_eq(group.padding, @foundation.Insets::all(12.0))
  assert_eq(group.computed_style.unwrap().spacing, Some(8.0))
  assert_eq(group.computed_style.unwrap().radius, Some(4.0))
}

///|
test "custom card metrics typography and paint update without rebuilding or losing selection" {
  let value = @reactive.signal("abc")
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      @view.column([
        styled_card([@view.text("Title"), @controls.text_input(value~)]),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=240.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  let original = root.snapshot().unwrap().tree.nodes
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  let font = @foundation.FontSpec::default().size(20.0)
  let background = @foundation.Color::accent()
  root.set_theme(
    Theme(
      styles=@style.Styles().add(
        SimpleCardStyle().surface(
          @view.FlexStyle()
          .width(220.0)
          .height(130.0)
          .padding(@foundation.Insets::all(12.0))
          .spacing(6.0)
          .font(font)
          .background(background)
          .radius(9.0)
          .shrink(0.0),
        ),
      ),
    ),
  )
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let changed = root.snapshot().unwrap().tree.nodes
  assert_eq(changed[1].frame.size, Size(width=220.0, height=130.0))
  assert_eq(changed[1].padding, @foundation.Insets::all(12.0))
  assert_eq(changed[1].computed_style.unwrap().spacing, Some(6.0))
  assert_eq(changed[1].computed_style.unwrap().background, Some(background))
  assert_eq(changed[2].computed_style.unwrap().font, Some(font))
  assert_eq(changed[2].frame.origin.x, changed[1].content.origin.x)
  assert_eq(
    changed[3].frame.origin.y,
    changed[2].frame.origin.y + changed[2].frame.size.height + 6.0,
  )
  assert_eq(root.copy_text(), Some("abc"))
  for i in 0..<original.length() {
    assert_eq(changed[i].id, original[i].id)
  }
  root.set_theme(Theme())
  root.paint(renderer, size~)
  let restored = root.snapshot().unwrap().tree.nodes
  assert_eq(restored[1].padding, original[1].padding)
  assert_eq(restored[1].frame, original[1].frame)
  assert_eq(root.copy_text(), Some("abc"))
  assert_eq(value.get(), "abc")
  assert_eq(builds.val, 1)
}

///|
test "declaration order controls repeated typed layers and only effective metrics invalidate layout" {
  let root = @runtime.mount(
    fn() { @view.column([@controls.button("one"), @controls.button("two")]) },
    theme=Theme(
      styles=@style.Styles()
        .add(@controls.ButtonStyle().surface(@style.BoxStyle().width(90.0)))
        .add(@controls.ButtonStyle().surface(@style.BoxStyle().width(120.0))),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=180.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  let count = root.frame_stats().layout_count
  root.set_theme(
    Theme(
      styles=@style.Styles()
        .add(@controls.ButtonStyle().surface(@style.BoxStyle().width(160.0)))
        .add(
          @controls.ButtonStyle().surface(
            @style.BoxStyle()
            .width(120.0)
            .background(@foundation.Color::black()),
          ),
        )
        .add(@view.TextStyle().width(500.0)),
    ),
  )
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, count)
  for index in [1, 2] {
    assert_eq(
      root.snapshot().unwrap().tree.nodes[index].frame.size.width,
      120.0,
    )
  }
  root.set_theme(
    Theme(
      styles=@style.Styles()
        .add(@controls.ButtonStyle().surface(@style.BoxStyle().width(120.0)))
        .add(@controls.ButtonStyle().surface(@style.BoxStyle().width(160.0))),
    ),
  )
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  for index in [1, 2] {
    assert_eq(
      root.snapshot().unwrap().tree.nodes[index].frame.size.width,
      160.0,
    )
  }
}

///|
test "scoped custom component defaults distinguish paint changes from metrics and isolate siblings" {
  let scoped = @reactive.signal(
    @style.Theme(
      styles=@style.Styles().add(
        SimpleCardStyle().surface(@view.FlexStyle().height(60.0)),
      ),
    ),
  )
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.style_scope(light_theme=scoped, inherit_styles=false, fn() {
          styled_card([@view.text("Inside")])
        }),
        styled_card([@view.text("Outside")]),
      ])
    },
    theme=Theme(
      styles=@style.Styles().add(
        SimpleCardStyle().surface(@view.FlexStyle().height(80.0)),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=240.0, height=240.0)
  root.paint(renderer, size~)
  let count = root.frame_stats().layout_count
  scoped.set(
    Theme(
      styles=@style.Styles().add(
        SimpleCardStyle().surface(
          @view.FlexStyle().height(60.0).background(@foundation.Color::black()),
        ),
      ),
    ),
  )
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, count)
  scoped.set(
    Theme(
      styles=@style.Styles().add(
        SimpleCardStyle().surface(@view.FlexStyle().height(100.0)),
      ),
    ),
  )
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].frame.size.height, 100.0)
  assert_eq(nodes[3].frame.size.height, 80.0)
}

///|
test "choice controls resolve custom disabled declarations through the shared painter" {
  let color = @foundation.Color::accent()
  let white = @foundation.Color::white()
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.checkbox(label="check", disabled=true),
        @controls.radio(label="radio", disabled=true),
      ])
    },
    theme=Theme(
      styles=@style.Styles()
        .add(
          @controls.CheckboxStyle().frame(
            @style.BoxStyle()
            .color(color)
            .padding(@foundation.Insets::all(20.0))
            .disabled(@style.Appearance().background(white)),
          ),
        )
        .add(
          @controls.RadioStyle().frame(
            @style.BoxStyle()
            .color(color)
            .padding(@foundation.Insets::all(20.0))
            .disabled(@style.Appearance().background(white)),
          ),
        ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=240.0, height=100.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  for index in [1, 2] {
    let computed = nodes[index].computed_style.unwrap()
    assert_eq(computed.color, Some({ ..color, a: color.a * 0.45, }))
    assert_eq(computed.background, Some(white))
    assert_eq(nodes[index].padding, @foundation.Insets::all(20.0))
    assert_eq(computed.radius, Some(renderer.fills[index - 1].1))
  }
}

///|
test "text typees resolve supported paint fields and direct fonts before ancestor fonts" {
  let font = @foundation.FontSpec::default().size(18.0)
  let color = @foundation.Color::accent()
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.text("one"),
          @view.text(
            "two",
            style=@view.TextStyle().frame(@style.BoxStyle().align(TextCenter)),
          ),
        ],
        style=@view.FlexStyle().surface(@style.BoxStyle().font(font.size(30.0))),
      )
    },
    theme=Theme(
      styles=@style.Styles()
        .add(
          @view.TextStyle().frame(@style.BoxStyle().font(font).align(TextEnd)),
        )
        .add(@view.TextStyle().color(color)),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=240.0, height=100.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].computed_style.unwrap().font, Some(font))
  assert_eq(nodes[1].computed_style.unwrap().color, Some(color))
  assert_eq(nodes[1].computed_style.unwrap().align, Some(TextEnd))
  assert_eq(nodes[2].computed_style.unwrap().align, Some(TextCenter))
  assert_eq(renderer.text[0].font, font)
  assert_eq(renderer.text[0].color, color)
}

///|
test "custom input type metrics are used by pointer input before painting" {
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
test "structural changes refresh the actual set of layout style dependencies" {
  let visible = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @view.show(() => visible.get(), fn() { @controls.button("Visible") })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=240.0, height=100.0)
  root.paint(renderer, size~)
  root.set_theme(
    Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().width(100.0)),
      ),
    ),
  )
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  visible.set(true)
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 100.0)
  root.set_theme(
    Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().width(180.0)),
      ),
    ),
  )
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  visible.set(false)
  root.paint(renderer, size~)
  root.set_theme(
    Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().width(220.0)),
      ),
    ),
  )
  assert_eq(root.dirty(), NeedsPaint)
}

///|
test "later type normal appearance overrides earlier hover and local appearance wins" {
  let red = @foundation.Color::rgb(r=180, g=20, b=30)
  let blue = @foundation.Color::rgb(r=20, g=40, b=180)
  let local_color = @foundation.Color::white()
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("theme"),
        @controls.button(
          "local",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().background(local_color),
          ),
        ),
      ])
    },
    theme=Theme(
      styles=@style.Styles()
        .add(
          @controls.ButtonStyle().surface(
            @style.BoxStyle().hovered(@style.Appearance().background(red)),
          ),
        )
        .add(
          @controls.ButtonStyle().surface(@style.BoxStyle().background(blue)),
        ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=240.0, height=120.0)
  root.paint(renderer, size~)
  ignore(root.pointer_move(size~, point=Point(x=5.0, y=5.0)))
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[1].computed_style.unwrap().background,
    Some(blue),
  )
  ignore(root.pointer_move(size~, point=Point(x=5.0, y=45.0)))
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[2].computed_style.unwrap().background,
    Some(local_color),
  )
}
