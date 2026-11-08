///|
test "style merge composes partial state appearances and preserves explicit zero stroke" {
  let base = @style.BoxStyle()
    .hovered(
      @style.Appearance()
      .background(@foundation.Color::accent())
      .stroke(@foundation.Color::black(), width=2.0),
    )
    .focused(@style.Appearance().color(@foundation.Color::white()))
  let next = @style.BoxStyle().hovered(
    @style.Appearance()
    .color(@foundation.Color::black())
    .stroke(@foundation.Color::white(), width=0.0),
  )
  let merged = base.merge(next)
  let hover = merged.controls.hovered.unwrap()
  assert_eq(hover.background, Some(Literal(@foundation.Color::accent())))
  assert_eq(hover.color, Some(Literal(@foundation.Color::black())))
  assert_eq(hover.stroke_color, Some(Literal(@foundation.Color::white())))
  assert_eq(hover.stroke_width, Some(0.0))
  assert_eq(merged.controls.focused, base.controls.focused)
  assert_eq(base.controls.hovered.unwrap().stroke_width, Some(2.0))
  assert_eq(merged.merge(BoxStyle()), merged)
}

///|
test "state builder fragments compose like merge for every state" {
  let setters : Array[(@style.BoxStyle, @style.Appearance) -> @style.BoxStyle] = [
    fn(style, appearance) { style.hovered(appearance) },
    fn(style, appearance) { style.pressed(appearance) },
    fn(style, appearance) { style.focused(appearance) },
    fn(style, appearance) { style.disabled(appearance) },
  ]
  let background = @foundation.Color::accent()
  let first = @style.Appearance()
    .background(background)
    .stroke(@foundation.Color::black(), width=2.0)
  let next = @style.Appearance()
    .color(@foundation.Color::white())
    .stroke(@foundation.Color::white(), width=0.0)
  let base = @style.BoxStyle().width(80.0).grow(0.0)
  for set in setters {
    let original = set(base, first)
    let chained = set(original, next)
    let merged = original.merge(set(BoxStyle(), next))
    assert_eq(chained, merged)
    assert_eq(chained, set(base, first.merge(next)))
    assert_eq(set(chained, Appearance()), chained)
    assert_eq(original, set(base, first))
    assert_eq(chained.layout.width, Some(80.0))
    assert_eq(chained.flex.grow, Some(0.0))
  }
}
