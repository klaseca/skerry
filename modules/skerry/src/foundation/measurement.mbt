///|
/// Minimum and preferred content dimensions returned by a leaf's measurement.
/// Padding, border and the parent's allocation are handled by layout.
#derive(Eq, Debug)
pub(all) struct IntrinsicSize {
  min_width : Double
  max_width : Double
  min_height : Double
  max_height : Double
}

///|
pub extend IntrinsicSize with Eq::{equal, not_equal}

///|
pub extend IntrinsicSize with Debug::{to_repr}
