///|
impl OverlayPolicy for PopupSpec with fn origin(
  self,
  anchor : @foundation.Rect,
  size : @foundation.Size,
  viewport : @foundation.Rect,
) -> @foundation.Point {
  let right = anchor.origin.x + anchor.size.width
  let bottom = anchor.origin.y + anchor.size.height
  let end_x = viewport.origin.x + viewport.size.width
  let end_y = viewport.origin.y + viewport.size.height
  let below = bottom + self.gap
  let above = anchor.origin.y - self.gap - size.height
  let after = right + self.gap
  let before = anchor.origin.x - self.gap - size.width
  let (x, y) = match self.placement {
    BottomStart | BottomEnd => {
      let y = if below + size.height > end_y &&
        anchor.origin.y - viewport.origin.y > end_y - bottom {
        above
      } else {
        below
      }
      (
        if self.placement == BottomEnd {
          right - size.width
        } else {
          anchor.origin.x
        },
        y,
      )
    }
    TopStart | TopEnd => {
      let y = if above < viewport.origin.y &&
        end_y - bottom > anchor.origin.y - viewport.origin.y {
        below
      } else {
        above
      }
      (
        if self.placement == TopEnd {
          right - size.width
        } else {
          anchor.origin.x
        },
        y,
      )
    }
    LeftStart =>
      (
        if before < viewport.origin.x &&
          end_x - right > anchor.origin.x - viewport.origin.x {
          after
        } else {
          before
        },
        anchor.origin.y,
      )
    RightStart =>
      (
        if after + size.width > end_x &&
          anchor.origin.x - viewport.origin.x > end_x - right {
          before
        } else {
          after
        },
        anchor.origin.y,
      )
  }
  Point(
    x=x.max(viewport.origin.x).min((end_x - size.width).max(viewport.origin.x)),
    y=y.max(viewport.origin.y).min((end_y - size.height).max(viewport.origin.y)),
  )
}

///|
impl OverlayPolicy for PopupSpec with fn layout(
  self,
  crater : @crater_node.Node,
  viewport : @foundation.Size,
  anchor_width : Double,
) -> @crater_node.Node {
  with_node_style(crater, {
    ..crater.style,
    width: if self.match_anchor_width {
      Length(anchor_width.max(0.0).min(viewport.width.max(0.0)))
    } else {
      FitContent(viewport.width.max(0.0))
    },
    max_width: Length(viewport.width.max(0.0)),
    max_height: Length(viewport.height.max(0.0)),
  })
}

///|
impl OverlayPolicy for PopupSpec with fn contains(
  _self,
  surface,
  trigger,
  point,
) {
  overlay_geometry_contains(surface, point) ||
  (match trigger {
    Some(trigger) => clip_contains(trigger.clip.intersect(trigger.frame), point)
    None => false
  })
}

///|
impl OverlayPolicy for PopupSpec with fn behavior(self) {
  OverlayBehavior(
    focus=if self.focus { Cycle } else { Preserve },
    escape=Dismiss,
    outside_press=Dismiss,
  )
}
