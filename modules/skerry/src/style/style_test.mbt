///|
test "box fragments merge layout text and flex item properties independently" {
  let font = @foundation.FontSpec::default().size(20.0)
  let before = @style.BoxStyle()
    .width(40.0)
    .font(font)
    .grow(1.0)
    .align_self(Center)
  let next = before.merge(@style.BoxStyle().height(0.0).shrink(0.0))
  assert_eq(next.layout.width, Some(40.0))
  assert_eq(next.layout.height, Some(0.0))
  assert_eq(next.text.font, Some(font))
  assert_eq(next.flex.grow, Some(1.0))
  assert_eq(next.flex.shrink, Some(0.0))
  assert_eq(next.flex.align_self, Some(Center))
  assert_eq(before.layout.height, None)
}
