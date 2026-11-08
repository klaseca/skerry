///|
/// Extra intrinsic layout dependencies, interpreted by the component. Slots
/// merge individually, so a later omitted property retains the earlier value.
/// No component-specific fields or paint data belong in this common contract.
#derive(Eq, Debug)
pub struct StyleMetrics {
  dimensions : ReadOnlyArray[Double?]
  fonts : ReadOnlyArray[@foundation.FontSpec?]
  flags : ReadOnlyArray[Int32?]
}

///|
pub fn StyleMetrics::StyleMetrics(
  dimensions~ : ArrayView[Double?] = [],
  fonts~ : ArrayView[@foundation.FontSpec?] = [],
  flags~ : ArrayView[Int32?] = [],
) -> StyleMetrics {
  {
    dimensions: ReadOnlyArray::from_array(dimensions),
    fonts: ReadOnlyArray::from_array(fonts),
    flags: ReadOnlyArray::from_array(flags),
  }
}

///|
fn[T] merge_metric_slots(
  a : ReadOnlyArray[T?],
  b : ReadOnlyArray[T?],
) -> ReadOnlyArray[T?] {
  ReadOnlyArray::from_array(
    Array::makei(a.length().max(b.length()), i => {
      match b.get(i) {
        Some(Some(value)) => Some(value)
        _ => a.get(i).unwrap_or(None)
      }
    })[:],
  )
}

///|
pub fn StyleMetrics::merge(
  self : StyleMetrics,
  other : StyleMetrics,
) -> StyleMetrics {
  {
    dimensions: merge_metric_slots(self.dimensions, other.dimensions),
    fonts: merge_metric_slots(self.fonts, other.fonts),
    flags: merge_metric_slots(self.flags, other.flags),
  }
}

///|
pub extend StyleMetrics with Eq::{equal, not_equal}

///|
pub extend StyleMetrics with Debug::{to_repr}
