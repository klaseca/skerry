///|
/// The selected native presentation path.
#derive(Debug, Eq)
pub(all) struct RenderingInfo {
  backend : String
  renderer : String
}

///|
pub extend RenderingInfo with Debug::{to_repr}

///|
pub extend RenderingInfo with Eq::{equal, not_equal}

///|
/// Available in on_mount and diagnostic snapshots; absent for custom hosts
/// which do not supply presentation information.
pub fn UiRoot::rendering_info(self : Self) -> RenderingInfo? {
  self.rendering
}
