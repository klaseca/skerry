///|
/// Placement of children along a row's horizontal or a column's vertical axis.
#derive(Debug, Eq)
pub(all) enum JustifyContent {
  Start
  Center
  End
  SpaceBetween
  SpaceAround
  SpaceEvenly
}

///|
pub extend JustifyContent with Debug::{to_repr}

///|
pub extend JustifyContent with Eq::{equal, not_equal}

///|
/// Placement across a row's vertical or a column's horizontal axis.
#derive(Debug, Eq)
pub(all) enum AlignItems {
  Start
  Center
  End
  Stretch
}

///|
pub extend AlignItems with Debug::{to_repr}

///|
pub extend AlignItems with Eq::{equal, not_equal}

///|
/// Override the parent's cross-axis alignment for one child. Auto inherits it.
#derive(Debug, Eq)
pub(all) enum AlignSelf {
  Auto
  Start
  Center
  End
  Stretch
}

///|
pub extend AlignSelf with Debug::{to_repr}

///|
pub extend AlignSelf with Eq::{equal, not_equal}

///|
/// Override cross-axis placement as a row/column child. Auto restores inheritance.
pub fn BoxStyle::align_self(self : BoxStyle, alignment : AlignSelf) -> BoxStyle {
  { ..self, flex: { ..self.flex, align_self: Some(alignment), }, }
}
