///|
fn leaf_node(
  id : String,
  style : @css_style.Style,
  size : @foundation.Size,
) -> @crater_node.Node {
  @crater_node.Node::with_measure(id, style, measure_func(size))
}

///|
fn text_node(
  id : String,
  style : @css_style.Style,
  measure : @crater_core.MeasureFunc,
  text : String,
) -> @crater_node.Node {
  @crater_node.Node::text(id, style, measure, text)
}

///|
fn measure_func(size : @foundation.Size) -> @crater_core.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @crater_core.IntrinsicSize {
      {
        min_width: size.width,
        max_width: size.width,
        min_height: size.height,
        max_height: size.height,
      }
    },
  }
}

///|
fn text_measure_func(
  spec : TextSpec,
  text_layout_system : @text.TextLayoutSystem,
  font : @foundation.FontSpec,
) -> @crater_core.MeasureFunc {
  crater_measure(text_measure(spec.text.get(), font, text_layout_system))
}

///|
fn empty_style() -> @css_style.Style {
  @css_style.Style::default()
}

///|
fn box_style() -> @css_style.Style {
  @css_style.Style::default()
}

///|
fn fill_box_style(height : Double) -> @css_style.Style {
  {
    ..@css_style.Style::default(),
    width: Percent(1.0),
    height: Length(height),
  }
}

///|
fn content_style(
  style : @style.BoxStyle,
  font : @foundation.FontSpec,
) -> @css_style.Style {
  apply_frame_size(
    {
      ..@css_style.Style::default(),
      display: Block,
      padding: css_rect_from_insets(
        style.layout.padding.unwrap_or(@foundation.Insets::all(0.0)),
      ),
      font_size: font.point_size(),
      line_height: font.point_size() * 1.25,
    },
    { width: style.layout.width, height: style.layout.height, },
  )
}

///|
fn flex_style(spec : FlexSpec) -> @css_style.Style {
  let gap = @css_values.Dimension::Length(spec.spacing)
  let base = match spec.axis {
    Horizontal =>
      {
        ..@css_style.Style::default(),
        display: Flex,
        flex_direction: Row,
        align_items: Stretch,
        column_gap: gap,
        column_gap_is_normal: false,
      }
    Vertical =>
      {
        ..@css_style.Style::default(),
        display: Flex,
        flex_direction: Column,
        align_items: Stretch,
        row_gap: gap,
      }
  }
  apply_frame_size(
    {
      ..base,
      padding: css_rect_from_insets(spec.padding),
      justify_content: spec.justify_content
      .map(css_justify_content)
      .unwrap_or(base.justify_content),
      align_items: spec.align_items
      .map(css_align_items)
      .unwrap_or(base.align_items),
    },
    spec.frame,
  )
}

///|
fn stack_style() -> @css_style.Style {
  { ..@css_style.Style::default(), position: Relative, }
}

///|
fn absolute_at_origin(style : @css_style.Style) -> @css_style.Style {
  {
    ..style,
    position: Absolute,
    inset: @css_values.Rect::new(Length(0.0), Auto, Length(0.0), Auto),
  }
}

///|
fn force_size(
  style : @css_style.Style,
  size : @foundation.Size,
) -> @css_style.Style {
  {
    ..style,
    box_sizing: BorderBox,
    width: Length(size.width),
    height: Length(size.height),
    // The host owns the root allocation, including when its style has bounds.
    min_width: Auto,
    max_width: Auto,
    min_height: Auto,
    max_height: Auto,
  }
}

///|
// Apply properties shared by every built-in without duplicating them in each
// painter/control spec. Retain the node uid and type-specific viewport defaults.
fn apply_layout_properties(
  node : @crater_node.Node,
  style : @style.BoxStyle,
) -> @crater_node.Node {
  let layout = style.layout
  let flex = style.flex
  if layout.min_width is None &&
    layout.max_width is None &&
    layout.min_height is None &&
    layout.max_height is None &&
    flex.grow is None &&
    flex.shrink is None &&
    flex.align_self is None {
    return node
  }
  let base = node.style
  with_node_style(node, {
    ..base,
    min_width: css_optional_length(layout.min_width, base.min_width),
    max_width: css_optional_length(layout.max_width, base.max_width),
    min_height: css_optional_length(layout.min_height, base.min_height),
    max_height: css_optional_length(layout.max_height, base.max_height),
    flex_grow: flex.grow.unwrap_or(base.flex_grow),
    flex_shrink: flex.shrink.unwrap_or(base.flex_shrink),
    align_self: flex.align_self.map(css_align_self).unwrap_or(base.align_self),
  })
}

///|
fn apply_frame_size(
  style : @css_style.Style,
  spec : FrameSpec,
) -> @css_style.Style {
  {
    ..style,
    box_sizing: BorderBox,
    width: css_optional_length(spec.width, style.width),
    height: css_optional_length(spec.height, style.height),
  }
}

///|
fn css_optional_length(
  value : Double?,
  fallback : @css_values.Dimension,
) -> @css_values.Dimension {
  match value {
    Some(v) => Length(v)
    None => fallback
  }
}

///|
fn css_rect_from_insets(
  insets : @foundation.Insets,
) -> @css_values.Rect[@css_values.Dimension] {
  @css_values.Rect::new(
    Length(insets.left),
    Length(insets.right),
    Length(insets.top),
    Length(insets.bottom),
  )
}

///|
fn with_node_style(
  node : @crater_node.Node,
  style : @css_style.Style,
) -> @crater_node.Node {
  @crater_node.Node::with_uid_and_measure(
    node.id,
    node.uid,
    style,
    node.children,
    node.measure,
    node.text,
    src=node.src,
  )
}
