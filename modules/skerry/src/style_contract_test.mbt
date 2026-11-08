///|
// StyleSpec supplies patching, equality and debugging; Default is the neutral patch.
fn[T : @skerry.StyleSpec + Default] assert_patch(
  base : T,
  patch : T,
  expected : T,
) -> Unit raise {
  let empty : T = Default::default()
  assert_eq(@skerry.StyleSpec::merge(empty, base), base)
  assert_eq(@skerry.StyleSpec::merge(base, empty), base)
  assert_eq(@skerry.StyleSpec::merge(base, patch), expected)
}

///|
test "all built-in styles share the generic patch contract" {
  let surface = @skerry.BoxStyle()
    .padding(@skerry.Insets::all(9.0))
    .width(120.0)
  let font = @skerry.FontSpec::default().size(22.0)
  let label = @skerry.TextStyle().font(font)
  assert_patch(surface, @skerry.BoxStyle().radius(0.0), surface.radius(0.0))
  assert_patch(
    @skerry.FlexStyle().surface(surface).spacing(8.0).align_items(Center),
    @skerry.FlexStyle().spacing(0.0),
    @skerry.FlexStyle().surface(surface).spacing(0.0).align_items(Center),
  )
  assert_patch(
    label,
    @skerry.TextStyle().color(@skerry.accent_token),
    label.color(@skerry.accent_token),
  )
  assert_patch(
    @skerry.ButtonStyle().surface(surface).label(label),
    @skerry.ButtonStyle().surface(@skerry.BoxStyle().radius(0.0)),
    @skerry.ButtonStyle().surface(surface.radius(0.0)).label(label),
  )
  assert_patch(
    @skerry.TextInputStyle().surface(surface).text(label),
    @skerry.TextInputStyle().placeholder(@skerry.TextStyle().font(font)),
    @skerry.TextInputStyle()
    .surface(surface)
    .text(label)
    .placeholder(@skerry.TextStyle().font(font)),
  )
  assert_patch(
    @skerry.CheckboxStyle().frame(surface).label(label).gap(8.0),
    @skerry.CheckboxStyle().gap(0.0),
    @skerry.CheckboxStyle().frame(surface).label(label).gap(0.0),
  )
  assert_patch(
    @skerry.RadioStyle().frame(surface).label(label).gap(8.0),
    @skerry.RadioStyle().gap(0.0),
    @skerry.RadioStyle().frame(surface).label(label).gap(0.0),
  )
}
