///|
test "frame fragments retain typography states and earlier independent fields" {
  let font = @foundation.FontSpec::default().size(22.0)
  let red = @foundation.Color::rgb(r=180, g=20, b=30)
  let white = @foundation.Color::white()
  let first = @style.BoxStyle()
    .font(font)
    .color(red)
    .align(TextEnd)
    .width(120.0)
    .hovered(@style.Appearance().color(white))
  let original = @view.TextStyle().frame(first)
  let next = original.frame(
    @style.BoxStyle().height(0.0).pressed(@style.Appearance().color(red)),
  )
  assert_eq(next.font, Some(font))
  assert_eq(next.color, Some(Literal(red)))
  assert_eq(next.align, Some(TextEnd))
  assert_eq(next.frame.layout.width, Some(120.0))
  assert_eq(next.frame.layout.height, Some(0.0))
  assert_eq(next.controls.hovered.unwrap().color, Some(Literal(white)))
  assert_eq(next.controls.pressed.unwrap().color, Some(Literal(red)))
  assert_eq(original.frame.layout.height, None)
  assert_eq(original.frame(BoxStyle()), original)
}

///|
test "frame and direct text setters preserve last explicit value precedence" {
  let first = @foundation.FontSpec::default().size(18.0)
  let second = first.size(24.0)
  let last = first.size(30.0)
  let style = @view.TextStyle()
    .font(first)
    .frame(@style.BoxStyle().font(second).color(@foundation.Color::black()))
  assert_eq(style.font, Some(second))
  let extended = style
    .font(last)
    .color(@foundation.Color::white())
    .frame(@style.BoxStyle().padding(@foundation.Insets::all(9.0)))
  assert_eq(extended.font, Some(last))
  assert_eq(extended.color, Some(Literal(@foundation.Color::white())))
  assert_eq(extended.root_style().text.font, Some(last))
  assert_eq(extended.root_style().paint.color, extended.color)
}
