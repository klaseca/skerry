///|
/// Value-only provenance of a materialized style declaration. Sheet IDs identify
/// the effective lookup provider; rule indices are within that style family.
/// Projection records types, not the field name of an opaque selector lambda.
/// Provenance describes evaluation; it never assigns priority to a declaration.
#derive(Eq, Debug)
pub(all) enum StyleOrigin {
  Local(String)
  Binding(String, StyleOrigin)
  ThemeRule(
    sheet~ : Int32,
    rule~ : Int32,
    family~ : String,
    source~ : StyleOrigin
  )
  Projection(from~ : String, to~ : String, source~ : StyleOrigin)
  Merged(StyleOrigin, StyleOrigin)
  Nested(StyleOrigin, StyleOrigin)
}

///|
pub extend StyleOrigin with Eq::{equal, not_equal}

///|
pub extend StyleOrigin with Debug::{to_repr}

///|
fn StyleOrigin::is_theme(self : Self) -> Bool {
  match self {
    ThemeRule(..) => true
    Binding(_, source) | Projection(source~, ..) => source.is_theme()
    Merged(left, right) => left.is_theme() && right.is_theme()
    Nested(outer, inner) => outer.is_theme() || inner.is_theme()
    Local(_) => false
  }
}

///|
fn nest_origin(outer : StyleOrigin, inner : StyleOrigin) -> StyleOrigin {
  match (outer, inner) {
    (Local(_), inner) => inner
    (outer, Local(_)) => outer
    (outer, inner) => Nested(outer, inner)
  }
}
