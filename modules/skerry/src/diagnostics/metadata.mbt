///|
/// An explicit application source tag. File paths are stored as provided;
/// line and column use one-based coordinates. Column may be omitted.
/// This value does not access files or capture the caller automatically.
#derive(Debug, Eq)
pub(all) struct SourceLocation {
  file : String
  line : Int32
  column : Int32?
}

///|
pub extend SourceLocation with Debug::{to_repr}

///|
pub extend SourceLocation with Eq::{equal, not_equal}

///|
pub fn SourceLocation::SourceLocation(
  file~ : String,
  line~ : Int32,
  column? : Int32,
) -> SourceLocation {
  { file, line, column, }
}

///|
/// One virtual component boundary above its containing NodeSnapshot. Boundaries
/// are ordered outermost first. IDs are stable for this boundary's lifetime and
/// have a separate namespace from UI node IDs. Names do not determine identity.
/// Geometry, styles, input and mounting belong to the containing UI node, not
/// to this value-only diagnostic record.
#derive(Debug, Eq)
pub(all) struct ComponentSnapshot {
  id : Int32
  name : String
  debug_name : String?
  source : SourceLocation?
}

///|
pub extend ComponentSnapshot with Debug::{to_repr}

///|
pub extend ComponentSnapshot with Eq::{equal, not_equal}
