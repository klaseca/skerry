///|
test "a reusable appearance composes identically in normal and state styles" {
  let base = @style.Appearance()
    .background(@foundation.Color::accent())
    .stroke(@foundation.Color::black(), width=3.0)
    .radius(8.0)
  let patch = @style.Appearance()
    .color(@foundation.Color::white())
    .stroke(@foundation.Color::white(), width=0.0)
    .radius(0.0)
  let composed = base.merge(patch)
  let initial = @style.BoxStyle().appearance(base).width(100.0)
  let style = initial.merge(@style.BoxStyle().appearance(patch))
  assert_eq(initial.appearance(patch), style)
  assert_eq(initial.appearance(Appearance()), initial)
  assert_eq(style.paint, composed)
  assert_eq(initial.paint, base)
  assert_eq(style, @style.BoxStyle().appearance(composed).width(100.0))
  assert_eq(@style.BoxStyle().appearance(Appearance()), BoxStyle())
  assert_eq(style.merge(BoxStyle()), style)
  let adjusted = initial.background(@foundation.Color::white())
  assert_eq(
    adjusted.paint.background,
    Some(Literal(@foundation.Color::white())),
  )
  assert_eq(adjusted.paint.radius, base.radius)
  assert_eq(adjusted.paint.stroke_color, base.stroke_color)
  assert_eq(adjusted.paint.stroke_width, base.stroke_width)
  assert_eq(adjusted.layout, initial.layout)
  assert_eq(style.hovered(base).hovered(patch).controls.hovered, Some(composed))
  assert_eq(composed.background, base.background)
  assert_eq(composed.color, patch.color)
  assert_eq(composed.radius, Some(0.0))
  assert_eq(composed.stroke_width, Some(0.0))
  assert_eq(base.stroke_width, Some(3.0))
  assert_eq(base.radius, Some(8.0))
  assert_eq(
    @style.BoxStyle().appearance(base).hovered(patch).controls.hovered,
    Some(patch),
  )
  assert_eq(@style.BoxStyle().radius(-2.0).paint.radius, Some(0.0))
  assert_eq(
    @style.BoxStyle().stroke(@foundation.Color::black(), width=-2.0).paint.stroke_width,
    Some(0.0),
  )
}
