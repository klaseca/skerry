///|
/// Immutable ordered component style declarations. The concrete type selects
/// its consumer; repeated values stay separate normal/state layers.
pub struct Styles {
  priv declarations : Array[StyleDeclaration]
  priv lookups : Map[String, StyleLookup]
}

///|
pub fn Styles::Styles() -> Styles {
  { declarations: [], lookups: {}, }
}

///|
pub fn[T : StyleSpec] Styles::add(self : Styles, value : T) -> Styles {
  { declarations: [..self.declarations, StyleDeclaration(value)], lookups: {}, }
}

///|
pub fn Styles::merge(self : Styles, other : Styles) -> Styles {
  if self.declarations.is_empty() {
    return other
  }
  if other.declarations.is_empty() {
    return self
  }
  { declarations: [..self.declarations, ..other.declarations], lookups: {}, }
}

///|
pub fn Styles::iter(self : Styles) -> Iter[StyleDeclaration] {
  self.declarations.iter()
}

///|
/// Data-only rules. Unmaterialized reactive rules are omitted: diagnostics must
/// never call their producers. Painted nodes expose their resolved style layers.
pub fn Styles::snapshot(self : Styles) -> Styles {
  {
    declarations: self.declarations
    .iter()
    .filter_map(value => value.static_snapshot())
    .to_array(),
    lookups: {},
  }
}

///|
pub fn[T] Styles::get(self : Styles) -> ReadOnlyArray[T] {
  let key = describe_style((panic : () -> Ref[T]))
  let witness = StyleWitness::witness((panic : () -> Ref[T]))
  if self.lookups.get(key) is Some(entry) &&
    physical_equal(witness, entry.witness) {
    let value : Ref[ReadOnlyArray[T]] = restore_style(entry.payload)
    return value.val
  }
  let value = ReadOnlyArray::from_iter(
    self.declarations.iter().filter_map(declaration => declaration.get()),
  )
  self.lookups.set(key, { witness, payload: erase_style(Ref(value)), })
  value
}

///|
pub extend Styles with Eq::{equal, not_equal}

///|
pub extend Styles with Debug::{to_repr}

///|
priv struct StyleLookup {
  witness : () -> Unit
  payload : StylePayload
}

///|
pub impl Eq for Styles with fn equal(a, b) {
  a.declarations == b.declarations
}

///|
pub impl Debug for Styles with fn to_repr(value) {
  Repr(value.declarations)
}
