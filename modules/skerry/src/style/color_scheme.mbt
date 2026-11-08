///|
/// The resolved scheme is independent of whether two Theme values are equal.
#derive(Eq, Debug)
pub(all) enum ColorScheme {
  Light
  Dark
}

///|
pub extend ColorScheme with Eq::{equal, not_equal}

///|
pub extend ColorScheme with Debug::{to_repr}
