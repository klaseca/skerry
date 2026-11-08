///|
/// A value-only description of one UI node and its layout box.
/// Coordinates use the same root coordinate system as paint and input.
/// Disabled includes ancestor state; focusable and hit_testable describe the
/// node's own capabilities. State describes the last painted interaction state
/// in this root. No handlers, signals or native objects are retained.
#derive(Debug, Eq)
pub(all) struct NodeSnapshot {
  id : Int32
  parent_id : Int32?
  children : ReadOnlyArray[Int32]
  // Open diagnostic name, independent of layout, behavior and style identity.
  component_name : String
  // Virtual component boundaries above this UI node, outermost first. They
  // preserve the actual node's name and parent/children, with no layout boxes.
  components : ReadOnlyArray[ComponentSnapshot]
  style_type : String?
  debug_name : String?
  source : SourceLocation?
  key_label : String?
  // Local concrete declaration, including unset properties and token references.
  // Reactive sources contain their last materialized values, never producers.
  // None means this node has no style declaration.
  specified_style : @style.StyleDeclaration?
  // Materialized theme and local rule layers used by this paint.
  style_layers : ReadOnlyArray[@style.StyleDeclaration]
  computed_style : ComputedStyle?
  // Font/tokens and static rules; live theme producers are omitted.
  theme : @style.Theme
  frame : @foundation.Rect
  content : @foundation.Rect
  clip : @foundation.Rect
  scroll : ScrollSnapshot?
  image : ImageSnapshot?
  padding : @foundation.Insets
  border : @foundation.Insets
  disabled : Bool
  state : @foundation.ControlState
  focusable : Bool
  hit_testable : Bool
}

///|
pub extend NodeSnapshot with Debug::{to_repr}

///|
pub extend NodeSnapshot with Eq::{equal, not_equal}

///|
/// UI nodes are in preorder with their actual parent/children links. Virtual
/// boundaries are stored in each node's components list, not as extra UI nodes.
#derive(Debug, Eq)
pub(all) struct TreeSnapshot {
  size : @foundation.Size
  nodes : ReadOnlyArray[NodeSnapshot]
}

///|
pub extend TreeSnapshot with Debug::{to_repr}

///|
pub extend TreeSnapshot with Eq::{equal, not_equal}

///|
/// Image geometry only. No pixel storage or native resource is retained.
#derive(Eq, Debug)
pub(all) struct ImageSnapshot {
  size : @foundation.Size
  fit : @foundation.ImageFit
  alignment : @foundation.ImageAlignment
  placement : @foundation.ImagePlacement?
}

///|
pub extend ImageSnapshot with Eq::{equal, not_equal}

///|
pub extend ImageSnapshot with Debug::{to_repr}

///|
/// Resolved values for the viewport used by a completed paint.
#derive(Eq, Debug)
pub(all) struct ScrollSnapshot {
  axis : @foundation.Axis
  viewport : @foundation.Rect
  content_size : @foundation.Size
  offset : Double
  max_offset : Double
  scrollbar : ScrollbarSnapshot?
}

///|
pub extend ScrollSnapshot with Eq::{equal, not_equal}

///|
pub extend ScrollSnapshot with Debug::{to_repr}

///|
/// Overlay scrollbar geometry in root coordinates, shared by paint and input.
/// None in ScrollSnapshot means hidden or no scrollable content.
#derive(Eq, Debug)
pub(all) struct ScrollbarSnapshot {
  track : @foundation.Rect
  thumb : @foundation.Rect
  // Declared style retains token references; colors below are the painted RGBA.
  style : @style.ScrollbarStyle
  track_color : @foundation.Color
  thumb_color : @foundation.Color
}

///|
pub extend ScrollbarSnapshot with Eq::{equal, not_equal}

///|
pub extend ScrollbarSnapshot with Debug::{to_repr}
