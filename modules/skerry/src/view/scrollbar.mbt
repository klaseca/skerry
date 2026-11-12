///|
// Capture belongs to a mounted LayoutState, not the shared View or offset signal.
priv enum ScrollbarPress {
  Thumb(Int32, Double)
  Track(Int32)
}

///|
fn ScrollbarPress::node_id(self : ScrollbarPress) -> Int32 {
  match self {
    Thumb(id, _) | Track(id) => id
  }
}

///|
fn scroll_axis_position(
  axis : @foundation.Axis,
  point : @foundation.Point,
) -> Double {
  match axis {
    Vertical => point.y
    Horizontal => point.x
  }
}

///|
fn scroll_axis_length(
  axis : @foundation.Axis,
  size : @foundation.Size,
) -> Double {
  match axis {
    Vertical => size.height
    Horizontal => size.width
  }
}

///|
fn scrollbar_geometry(
  axis : @foundation.Axis,
  viewport : @foundation.Rect,
  bounds : @foundation.Rect,
  content : @foundation.Size,
  offset : Double,
  maximum : Double,
  style : @style.ScrollbarStyle,
  theme~ : @style.Theme,
) -> @diagnostics.ScrollbarSnapshot? {
  guard maximum > 0.0 && style.thickness > 0.0 && !viewport.is_empty() else {
    return None
  }
  // Use the padded viewport for track length, and the outer box for its edge.
  let track = match axis {
    Vertical => {
      let width = style.thickness.min(bounds.size.width)
      @foundation.Rect(
        x=bounds.origin.x + bounds.size.width - width,
        y=viewport.origin.y,
        width~,
        height=viewport.size.height,
      )
    }
    Horizontal => {
      let height = style.thickness.min(bounds.size.height)
      Rect(
        x=viewport.origin.x,
        y=bounds.origin.y + bounds.size.height - height,
        width=viewport.size.width,
        height~,
      )
    }
  }
  let range = scrollbar_thumb_range(axis, track, style)
  let length = scroll_axis_length(axis, range.size)
  let extent = scroll_axis_length(axis, content)
  // Keep a usable target, including tiny viewports, without eliminating travel.
  let minimum = 20.0.min(length * 0.8)
  let thumb_length = (length *
    (scroll_axis_length(axis, viewport.size) / extent))
    .max(minimum)
    .min(length)
  let position = (length - thumb_length) * (offset / maximum)
  let thumb = match axis {
    Vertical =>
      @foundation.Rect(
        x=range.origin.x,
        y=range.origin.y + position,
        width=range.size.width,
        height=thumb_length,
      )
    Horizontal =>
      Rect(
        x=range.origin.x + position,
        y=range.origin.y,
        width=thumb_length,
        height=range.size.height,
      )
  }
  Some({
    track,
    thumb,
    style,
    track_color: style.track_color.resolve(theme),
    thumb_color: style.thumb_color.resolve(theme),
  })
}

///|
fn scrollbar_thumb_range(
  axis : @foundation.Axis,
  track : @foundation.Rect,
  style : @style.ScrollbarStyle,
) -> @foundation.Rect {
  let cross = match axis {
    Vertical => track.size.width
    Horizontal => track.size.height
  }
  // Retain a nonempty thumb and travel even in a tiny viewport or with large inset.
  let inset = style.thumb_inset
    .min(cross * 0.25)
    .min(scroll_axis_length(axis, track.size) * 0.1)
  track.inset(@foundation.Insets::all(inset))
}

///|
fn paint_scrollbar(geometry : NodeGeometry, context : PaintContext) -> Unit {
  guard geometry.scroll is Some({ scrollbar: Some(bar), .. }) else { return }
  // Content padding must not cut off the track anchored to the outer edge.
  let clip = geometry.clip.intersect(geometry.frame.inset(geometry.border))
  guard !clip.is_empty() else { return }
  let push_clip = clip != geometry.clip
  if push_clip {
    context.renderer.push_clip(clip)
  }
  defer (fn() { if push_clip { context.renderer.pop_clip() } })()
  context.fill_box(bar.track, bar.track_color, bar.style.track_radius)
  context.fill_box(bar.thumb, bar.thumb_color, bar.style.thumb_radius)
}

///|
/// Clear per-root pointer interaction state. Custom hosts also cancel their
/// capture and notify the View's pointer_cancel_path for application targets.
pub fn LayoutState::pointer_cancel(self : LayoutState) -> Unit {
  self.scrollbar_press = None
}

///|
fn LayoutState::scrollbar_pointer(
  self : LayoutState,
  node : UiNode,
  geometry : NodeGeometry,
  point : @foundation.Point,
  phase : PointerPhase,
  scrollbar : Bool,
) -> Bool {
  if phase is PointerDown {
    guard scrollbar &&
      geometry.scroll is Some(scroll) &&
      scroll.scrollbar is Some(bar) &&
      clip_contains(geometry.clip.intersect(bar.track), point) else {
      return false
    }
    let position = scroll_axis_position(scroll.axis, point)
    let thumb_start = scroll_axis_position(scroll.axis, bar.thumb.origin)
    let thumb_length = scroll_axis_length(scroll.axis, bar.thumb.size)
    // The narrow cross-axis margins belong to the thumb's grab area, so a
    // press beside the thumb does not unexpectedly page the content.
    if position >= thumb_start && position < thumb_start + thumb_length {
      self.scrollbar_press = Some(
        Thumb(node.id, (position - thumb_start) / thumb_length),
      )
    } else {
      // A track press pages once. Holding/repeat is a separate interaction.
      self.scrollbar_press = Some(Track(node.id))
      let page = scroll_axis_length(scroll.axis, scroll.viewport.size)
      let next = scroll.offset +
        (if position < thumb_start { -page } else { page })
      node.set_scroll_offset(scroll, next)
    }
    return true
  }
  guard self.scrollbar_press is Some(press) && press.node_id() == node.id else {
    return false
  }
  // End state before signal callbacks can detach, dispose or start another press.
  if phase is PointerUp {
    self.scrollbar_press = None
  }
  if press is Thumb(_, grab) &&
    geometry.scroll is Some(scroll) &&
    scroll.scrollbar is Some(bar) {
    let range = scrollbar_thumb_range(scroll.axis, bar.track, bar.style)
    let start = scroll_axis_position(scroll.axis, range.origin)
    let thumb_length = scroll_axis_length(scroll.axis, bar.thumb.size)
    let travel = scroll_axis_length(scroll.axis, range.size) - thumb_length
    let position = scroll_axis_position(scroll.axis, point)
    if travel > 0.0 && position == position {
      let fraction = ((position - start - grab * thumb_length) / travel)
        .max(0.0)
        .min(1.0)
      node.set_scroll_offset(scroll, fraction * scroll.max_offset)
    }
  }
  true
}

///|
fn UiNode::set_scroll_offset(
  self : UiNode,
  scroll : @diagnostics.ScrollSnapshot,
  next : Double,
) -> Unit {
  if self.geometry is Some({ scroll: Some(spec), .. }) {
    let next = clamped_scroll_offset(next, scroll.max_offset)
    if next != scroll.offset {
      spec.offset.set(next)
    }
  }
}
