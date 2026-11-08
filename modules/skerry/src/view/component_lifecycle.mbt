///|
pub struct MountContext {
  priv mark_layout_dirty : () -> Unit
  priv mark_paint_dirty : () -> Unit
  priv on_node_detach : (Int32) -> Unit
  priv on_theme_change : (Int32, @style.Theme?) -> Unit
  priv on_disabled_change : (Int32) -> Unit
  priv can_change : (Int32) -> Bool
  priv style_sheet : @style.StyleSheet?
  priv style_theme : @environment.ThemeProvider?
}

///|
pub struct Reactivity {
  priv mount : (MountContext) -> () -> Unit
  priv manages_children : Bool
  priv text_value : TextContent?
  priv image_value : ImageValue?
}

///|
/// Subscriptions for one leaf instance. Return a disposer that releases them.
/// Create local component state normally and capture it in these callbacks.
pub fn Reactivity::Reactivity(
  mount~ : (MountContext) -> () -> Unit = fn(_) { fn() { () } },
) -> Reactivity {
  { ..empty_reactivity(), mount, }
}

///|
/// Track paint state without invalidating layout. The initial run stays idle.
pub fn Reactivity::paint(track : () -> Unit) -> Reactivity {
  paint_reactivity(track)
}

///|
pub fn MountContext::invalidate_layout(self : MountContext) -> Unit {
  (self.mark_layout_dirty)()
}

///|
pub fn MountContext::invalidate_paint(self : MountContext) -> Unit {
  (self.mark_paint_dirty)()
}

///|
pub fn PaintContext::with_font(
  self : PaintContext,
  font : @foundation.FontSpec,
) -> PaintContext {
  { ..self, font, }
}
