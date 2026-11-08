///|
#derive(Eq, Debug)
pub struct FirstStyle {
  value : Int32
}

///|
#derive(Eq, Debug)
pub struct SecondStyle {
  value : Int32
}

///|
impl @style.StyleSpec for FirstStyle with fn merge(_, other) {
  other
}

///|
impl @style.StyleSpec for SecondStyle with fn merge(_, other) {
  other
}

///|
pub extend FirstStyle with Eq::{equal, not_equal}

///|
pub extend FirstStyle with Debug::{to_repr}

///|
pub extend FirstStyle with @style.StyleSpec::{merge, root_style, metrics}

///|
pub extend SecondStyle with Eq::{equal, not_equal}

///|
pub extend SecondStyle with Debug::{to_repr}

///|
pub extend SecondStyle with @style.StyleSpec::{merge, root_style, metrics}

///|
test "automatic style storage preserves nominal types and repeated layers" {
  let before = @style.Styles().add(FirstStyle::{ value: 7, })
  let styles = before
    .add(SecondStyle::{ value: 7, })
    .add(FirstStyle::{ value: 8, })
  let first : ReadOnlyArray[FirstStyle] = styles.get()
  let second : ReadOnlyArray[SecondStyle] = styles.get()
  let unchanged : ReadOnlyArray[FirstStyle] = before.get()
  assert_eq(first, [{ value: 7, }, { value: 8, }])
  assert_eq(second, [{ value: 7, }])
  assert_eq(unchanged, [{ value: 7, }])
  assert_eq(styles.iter().count(), 3)
}

///|
test "declarations reject the wrong nominal type and compare values" {
  let a = @style.StyleDeclaration(FirstStyle::{ value: 7, })
  let b = @style.StyleDeclaration(SecondStyle::{ value: 7, })
  assert_false(a.same_type(b))
  assert_false(a == b)
  assert_eq((a.get() : FirstStyle?), Some({ value: 7, }))
  assert_eq((a.get() : SecondStyle?), None)
  assert_eq(a, StyleDeclaration(FirstStyle::{ value: 7, }))
  assert_false(a == StyleDeclaration(FirstStyle::{ value: 8, }))
}

///|
test "merging collections preserves independent state layers and originals" {
  let red = @foundation.Color::rgb(r=200, g=20, b=30)
  let first = @style.BoxStyle()
    .radius(4.0)
    .hovered(@style.Appearance().background(red))
  let second = @style.BoxStyle().radius(8.0)
  let before = @style.Styles().add(first)
  let merged = before.merge(@style.Styles().add(second))
  let layers : ReadOnlyArray[@style.BoxStyle] = merged.get()
  assert_eq(layers, [first, second])
  assert_eq((before.get() : ReadOnlyArray[@style.BoxStyle]), [first])
  assert_eq(merged, @style.Styles().add(first).add(second))
}

///|
test "intrinsic metric slots merge partial declarations field by field" {
  let first = @style.StyleMetrics(dimensions=[Some(20.0), Some(30.0)], flags=[
    Some(1),
  ])
  let next = first.merge(StyleMetrics(dimensions=[None, Some(0.0)]))
  assert_eq(next.dimensions, [Some(20.0), Some(0.0)])
  assert_eq(next.flags, [Some(1)])
}

///|
#derive(Eq, Debug)
pub struct GenericStyle[T] {
  value : T
}

///|
impl[T : Eq + Debug] @style.StyleSpec for GenericStyle[T] with fn merge(
  _,
  other,
) {
  other
}

///|
pub extend GenericStyle with Eq::{equal, not_equal}

///|
pub extend GenericStyle with Debug::{to_repr}

///|
pub extend GenericStyle with @style.StyleSpec::{merge, root_style, metrics}

///|
test "automatic style identity includes generic arguments and nominal wrappers" {
  let styles = @style.Styles()
    .add(GenericStyle::{ value: 42, })
    .add(GenericStyle::{ value: "text", })
  let numbers : ReadOnlyArray[GenericStyle[Int32]] = styles.get()
  let strings : ReadOnlyArray[GenericStyle[String]] = styles.get()
  let doubles : ReadOnlyArray[GenericStyle[Double]] = styles.get()
  assert_eq(numbers, [{ value: 42, }])
  assert_eq(strings, [{ value: "text", }])
  assert_eq(doubles, [])
}
