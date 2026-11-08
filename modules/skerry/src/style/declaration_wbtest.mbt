///|
#derive(Eq, Debug)
pub struct Point {
  x : Double
  y : Double
}

///|
impl StyleSpec for Point with fn merge(_, other) {
  other
}

///|
impl StyleSpec for @foundation.Point with fn merge(_, other) {
  other
}

///|
pub extend Point with Eq::{equal, not_equal}

///|
pub extend Point with Debug::{to_repr}

///|
pub extend Point with StyleSpec::{merge, root_style, metrics}

///|
#derive(Eq, Debug)
pub struct ScalarStyle(Int32)

///|
impl StyleSpec for ScalarStyle with fn merge(_, other) {
  other
}

///|
pub extend ScalarStyle with Eq::{equal, not_equal}

///|
pub extend ScalarStyle with Debug::{to_repr}

///|
pub extend ScalarStyle with StyleSpec::{merge, root_style, metrics}

///|
test "style extraction distinguishes identical names and layouts in different packages" {
  let local_style = StyleDeclaration(Point::{ x: 1.0, y: 2.0, })
  let foreign = StyleDeclaration(@foundation.Point(x=1.0, y=2.0))
  assert_false(local_style.same_type(foreign))
  assert_eq((local_style.get() : @foundation.Point?), None)
  assert_eq((foreign.get() : Point?), None)
  assert_eq((local_style.get() : Point?), Some({ x: 1.0, y: 2.0, }))
  assert_eq((foreign.get() : @foundation.Point?), Some(Point(x=1.0, y=2.0)))
}

///|
test "scalar style values remain boxed and nominal after erasure" {
  let value = StyleDeclaration(ScalarStyle(42))
  assert_eq((value.get() : ScalarStyle?), Some(ScalarStyle(42)))
  assert_eq((value.get() : Int32?), None)
  assert_eq((value.get() : BoxStyle?), None)
}
