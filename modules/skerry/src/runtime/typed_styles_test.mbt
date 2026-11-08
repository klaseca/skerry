///|
// This contract lives outside the style/view packages, as an application component would.
#derive(Eq, Debug, Default)
pub struct PanelStyle {
  priv source : @style.StyleSource[PanelStyle]?
  surface : @view.FlexStyle
  title : @view.TextStyle
}

///|
let panel_selections : Ref[Int32] = Ref(0)

///|
test "custom concrete styles theme their parts without rebuilding or inspection callbacks" {
  let value = @reactive.signal("abc")
  let builds = Ref(0)
  let small = @foundation.FontSpec::default().size(18.0)
  let large = small.size(26.0)
  let make_theme = fn(font, color) {
    @style.Theme(
      styles=@style.Styles().add(
        PanelStyle()
        .surface(
          @view.FlexStyle().padding(@foundation.Insets::all(12.0)).spacing(6.0),
        )
        .title(@view.TextStyle().font(font).color(color)),
      ),
    )
  }
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      @view.column([
        panel("Title", @controls.text_input(value~)),
        @view.text("Outside"),
      ])
    },
    theme=make_theme(small, @foundation.Color::black()),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=250.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let after_selection = panel_selections.val
  root.paint(renderer, size~)
  ignore(root.snapshot())
  ignore(root.snapshot())
  assert_eq(panel_selections.val, after_selection)
  assert_eq(before.tree.nodes[2].computed_style.unwrap().font, Some(small))
  assert_eq(
    before.tree.nodes[4].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default()),
  )
  root.set_theme(make_theme(large, @foundation.Color::accent()))
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.tree.nodes[2].computed_style.unwrap().font, Some(large))
  assert_eq(
    after.tree.nodes[2].computed_style.unwrap().color,
    Some(@foundation.Color::accent()),
  )
  assert_eq(
    after.tree.nodes[3].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default()),
  )
  for i in 0..<before.tree.nodes.length() {
    assert_eq(after.tree.nodes[i].id, before.tree.nodes[i].id)
  }
  assert_eq(after.focused_node_id, before.focused_node_id)
  assert_eq(root.copy_text(), Some("abc"))
  assert_eq(builds.val, 1)
  let layouts = root.frame_stats().layout_count
  root.set_theme(make_theme(large, @foundation.Color::white()))
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, layouts)
}

///|
test "a local custom part override is isolated and wins over its theme" {
  let root = @runtime.mount(
    fn() {
      @view.column([
        panel("Local", @view.text("Body"), style={
          source: None,
          surface: FlexStyle(),
          title: @view.TextStyle().color(@foundation.Color::white()),
        }),
        panel("Themed", @view.text("Body")),
      ])
    },
    theme=Theme(
      styles=@style.Styles().add(
        PanelStyle()
        .surface(@view.FlexStyle().radius(7.0))
        .title(@view.TextStyle().color(@foundation.Color::accent())),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(StyleRecorder(), size=Size(width=300.0, height=250.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(
    nodes[2].computed_style.unwrap().color,
    Some(@foundation.Color::white()),
  )
  assert_eq(
    nodes[5].computed_style.unwrap().color,
    Some(@foundation.Color::accent()),
  )
  let declaration : @view.FlexStyle? = nodes[1].specified_style.unwrap().get()
  assert_true(declaration is Some(_))
}

///|
test "indicator metrics and gap affect measurement painting and theme invalidation" {
  let make_theme = fn(width, height, gap) {
    let indicator = @style.BoxStyle().width(width).height(height)
    let frame = @style.BoxStyle().shrink(0.0)
    @style.Theme(
      styles=@style.Styles()
        .add(
          @controls.CheckboxStyle().indicator(indicator).frame(frame).gap(gap),
        )
        .add(@controls.RadioStyle().indicator(indicator).frame(frame).gap(gap)),
    )
  }
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.checkbox(label="Check"),
        @controls.radio(label="Radio"),
      ])
    },
    theme=make_theme(30.0, 36.0, 14.0),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=150.0)
  let text = StyleRecorder()
  let boxes = ScrollRecorder()
  root.paint(text, size~)
  let before = root.snapshot().unwrap().tree.nodes
  for index in [1, 2] {
    assert_eq(before[index].frame.size.height, 36.0)
    assert_eq(
      before[index].computed_style.unwrap().indicator_size,
      Some(Size(width=30.0, height=36.0)),
    )
    assert_eq(before[index].computed_style.unwrap().indicator_gap, Some(14.0))
    assert_eq(
      text.text[index - 1].frame.origin.x,
      before[index].frame.origin.x + 44.0,
    )
  }
  root.paint(boxes, size~)
  assert_eq(boxes.fills[0].0.size, Size(width=30.0, height=36.0))
  assert_eq(boxes.fills[1].0.size, Size(width=30.0, height=36.0))
  root.set_theme(make_theme(24.0, 28.0, 10.0))
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(text, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.height, 28.0)
  assert_eq(text.text[0].frame.origin.x, 34.0)
}

///|
test "placeholder typography changes independently and its state color is paint only" {
  let font = @foundation.FontSpec::default().size(28.0)
  let value = @reactive.signal("")
  let root = @runtime.mount(
    fn() { @view.column([@controls.text_input(value~, placeholder="Hint")]) },
    theme=Theme(
      styles=@style.Styles().add(
        @controls.TextInputStyle().placeholder(
          @view.TextStyle()
          .font(font)
          .align(TextEnd)
          .focused(@view.TextAppearance().color(@foundation.Color::accent())),
        ),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=100.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  let node = root.snapshot().unwrap().tree.nodes[1]
  assert_eq(node.frame.size.height, 51.0)
  assert_eq(node.computed_style.unwrap().placeholder_font, Some(font))
  assert_eq(renderer.text[0].font, font)
  assert_eq(
    renderer.text[0].frame.origin.x + renderer.text[0].frame.size.width,
    node.content.origin.x + node.content.size.width,
  )
  let layouts = root.frame_stats().layout_count
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].color, @foundation.Color::accent())
  assert_eq(root.frame_stats().layout_count, layouts)
  value.set("Text")
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].font, @foundation.FontSpec::default())
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.height, 36.0)
}

///|
test "input text alignment agrees with pointer selection before painting" {
  let value = @reactive.signal("abcd")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().text(@view.TextStyle().align(TextEnd)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=50.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  let x = renderer.text[0].frame.origin.x
  assert_true(x > 100.0)
  assert_true(root.pointer_down(size~, point=Point(x=x + 1.0, y=20.0)))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "Xabcd")
  root.set_theme(
    Theme(
      styles=@style.Styles().add(
        @controls.TextInputStyle().text(
          @view.TextStyle().font(@foundation.FontSpec::default().size(20.0)),
        ),
      ),
    ),
  )
  // Updated metrics must be used even when the next pointer event precedes paint.
  assert_true(root.pointer_down(size~, point=Point(x=131.0, y=20.0)))
  assert_true(root.text_input("Y"))
  assert_eq(value.get(), "YXabcd")
}

///|
test "nonfinite and negative indicator geometry produces empty finite boxes" {
  let root = @runtime.mount(
    fn() {
      @controls.checkbox(
        style=@controls.CheckboxStyle()
          .indicator(@style.BoxStyle().width(@double.infinity).height(-10.0))
          .frame(BoxStyle())
          .gap(@double.not_a_number),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(StyleRecorder(), size=Size(width=100.0, height=50.0))
  let style = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
  assert_eq(style.indicator_size, Some(Size(width=0.0, height=0.0)))
  assert_eq(style.indicator_gap, Some(0.0))
}

///|
test "text parts override surface states inside a layer while later layers still win" {
  let red = @foundation.Color::rgb(r=180, g=20, b=30)
  let blue = @foundation.Color::rgb(r=20, g=40, b=180)
  let green = @foundation.Color::rgb(r=20, g=180, b=40)
  let root = @runtime.mount(
    fn() { @controls.button("Button") },
    theme=Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle()
        .surface(@style.BoxStyle().hovered(@style.Appearance().color(red)))
        .label(
          @view.TextStyle()
          .color(blue)
          .pressed(@view.TextAppearance().color(green)),
        ),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=50.0)
  let renderer = StyleRecorder()
  ignore(root.pointer_move(size~, point=Point(x=5.0, y=5.0)))
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].color, blue)
  assert_true(root.pointer_down(size~, point=Point(x=5.0, y=5.0)))
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].color, green)
  let theme = root.theme()
  root.set_theme({
    ..theme,
    styles: theme.styles.add(
      @controls.ButtonStyle().label(@view.TextStyle().color(red)),
    ),
  })
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].color, red)
}

///|
fn PanelStyle::PanelStyle() -> PanelStyle {
  Default::default()
}

///|
fn PanelStyle::surface(
  self : PanelStyle,
  value : @view.FlexStyle,
) -> PanelStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
fn PanelStyle::title(self : PanelStyle, value : @view.TextStyle) -> PanelStyle {
  { ..self, title: self.title.merge(value), }
}

///|
impl @style.StyleSpec for PanelStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(self, other) {
    {
      source: None,
      surface: self.surface.merge(other.surface),
      title: self.title.merge(other.title),
    }
  })
}

///|
pub extend PanelStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
fn panel(
  title : String,
  body : @view.View,
  style~ : PanelStyle = PanelStyle(),
) -> @view.View {
  @view.column(
    [
      @view.text(
        title,
        style=style.select(fn(s) {
          panel_selections.val += 1
          s.title
        }),
      ),
      body,
    ],
    style=style.select(s => s.surface),
  )
}

///|
#derive(Eq, Debug)
pub struct OuterPanelStyle {
  panel : PanelStyle
}

///|
impl @style.StyleSpec for OuterPanelStyle with fn merge(self, other) {
  { panel: self.panel.merge(other.panel), }
}

///|
pub extend OuterPanelStyle with Eq::{equal, not_equal}

///|
pub extend OuterPanelStyle with Debug::{to_repr}

///|
pub extend OuterPanelStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
test "nested concrete composition contracts forward root and child field styles" {
  let original = panel(
    "Title",
    @view.text("Body"),
    style=OuterPanelStyle::{ panel: PanelStyle(), }.select(s => s.panel),
  )
  let root = @runtime.mount(
    fn() { original },
    theme=Theme(
      styles=@style.Styles().add(OuterPanelStyle::{
        panel: PanelStyle()
        .surface(
          @view.FlexStyle().padding(@foundation.Insets::all(17.0)).spacing(9.0),
        )
        .title(
          @view.TextStyle()
          .font(@foundation.FontSpec::default().size(24.0))
          .color(@foundation.Color::accent()),
        ),
      }),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=300.0, height=200.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[0].padding, @foundation.Insets::all(17.0))
  assert_eq(nodes[0].computed_style.unwrap().spacing, Some(9.0))
  assert_eq(
    nodes[1].computed_style.unwrap().font,
    Some(@foundation.FontSpec::default().size(24.0)),
  )
  assert_eq(renderer.text[0].color, @foundation.Color::accent())
}

///|
test "a self-typed field selector terminates and retains the original node" {
  let original = @controls.button(
    "Button",
    style=@controls.ButtonStyle()
      .surface(@style.BoxStyle().radius(13.0))
      .select(fn(value) { value }),
  )
  let styled = original
  let root = @runtime.mount(
    fn() { styled },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(StyleRecorder(), size=Size(width=200.0, height=60.0))
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].id,
    original.node_id_at_path([]).unwrap(),
  )
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().radius,
    Some(13.0),
  )
}

///|
#derive(Eq, Debug)
pub struct ButtonChrome {
  button : @controls.ButtonStyle
}

///|
impl @style.StyleSpec for ButtonChrome with fn merge(self, other) {
  { button: self.button.merge(other.button), }
}

///|
pub extend ButtonChrome with Eq::{equal, not_equal}

///|
pub extend ButtonChrome with Debug::{to_repr}

///|
pub extend ButtonChrome with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
test "a user style can wrap a built-in control without codecs keys or paint type casts" {
  let clicks = Ref(0)
  let button = @controls.button(
    "Button",
    on_click=fn() { clicks.val += 1 },
    style=ButtonChrome::{ button: ButtonStyle(), }.select(s => s.button),
  )
  let decorated = button
  let root = @runtime.mount(
    fn() { decorated },
    theme=Theme(
      styles=@style.Styles().add(ButtonChrome::{
        button: @controls.ButtonStyle()
        .surface(
          @style.BoxStyle().radius(15.0).background(@foundation.Color::black()),
        )
        .label(@view.TextStyle().color(@foundation.Color::white())),
      }),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=60.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  assert_eq(renderer.fills[0].0, @foundation.Color::black())
  assert_eq(renderer.fills[0].1, 15.0)
  assert_eq(renderer.text[0].color, @foundation.Color::white())
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(clicks.val, 1)
}

///|
#derive(Eq, Debug)
pub struct InputChrome {
  input : @controls.TextInputStyle
}

///|
impl @style.StyleSpec for InputChrome with fn merge(self, other) {
  { input: self.input.merge(other.input), }
}

///|
pub extend InputChrome with Eq::{equal, not_equal}

///|
pub extend InputChrome with Debug::{to_repr}

///|
pub extend InputChrome with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
test "input field styles share frozen alignment with pointer-to-caret mapping" {
  let value = @reactive.signal("abcd")
  let input = @controls.text_input(
    value~,
    style=InputChrome::{ input: TextInputStyle(), }.select(s => s.input),
  )
  let root = @runtime.mount(
    fn() { input },
    theme=Theme(
      styles=@style.Styles().add(InputChrome::{
        input: @controls.TextInputStyle().text(@view.TextStyle().align(TextEnd)),
      }),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=60.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  let x = renderer.text[0].frame.origin.x
  assert_true(x > 100.0)
  assert_true(root.pointer_down(size~, point=Point(x=x + 1.0, y=20.0)))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "Xabcd")
}

///|
#derive(Eq, Debug)
pub struct PanelFrameStyle {
  surface : @style.BoxStyle
}

///|
impl @style.StyleSpec for PanelFrameStyle with fn merge(self, other) {
  { surface: self.surface.merge(other.surface), }
}

///|
impl @style.StyleSpec for PanelFrameStyle with fn root_style(self) {
  self.surface
}

///|
test "custom root geometry composes with flex container arrangement" {
  let theme = fn(padding) {
    @style.Theme(
      styles=@style.Styles().add(PanelFrameStyle::{
        surface: @style.BoxStyle().padding(@foundation.Insets::all(padding)),
      }),
    )
  }
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.column(
            [@view.box(style=@style.BoxStyle().width(60.0).height(10.0))],
            style=@view.FlexStyle().surface(
              PanelFrameStyle::{ surface: @style.BoxStyle().width(120.0), }.select(s => {
                  s.surface
                },
              ),
            ),
          ),
        ],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    theme=theme(10.0),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=240.0, height=180.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap().tree.nodes
  assert_eq(before[1].frame.size.width, 120.0)
  assert_eq(before[1].frame.size.height, 30.0)
  assert_eq(before[1].padding, @foundation.Insets::all(10.0))
  root.set_theme(theme(20.0))
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap().tree.nodes
  assert_eq(after[1].frame.size.width, 120.0)
  assert_eq(after[1].frame.size.height, 50.0)
  assert_eq(after[1].padding, @foundation.Insets::all(20.0))
  assert_eq(after[1].id, before[1].id)
}

///|
impl @style.StyleSpec for PanelStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
impl @style.SourceStyle for PanelStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend PanelFrameStyle with @style.StyleSpec::{select}
