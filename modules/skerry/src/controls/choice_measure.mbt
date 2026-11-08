///|
fn choice_measure_func(
  label : String,
  font : @foundation.FontSpec,
  size : @foundation.Size,
  gap : Double,
  text_layout_system : @text.TextLayoutSystem,
) -> @view.Measure {
  if label.is_empty() {
    return fixed_measure(size)
  }
  let measure = @view.text_measure(label, font, text_layout_system)
  let decoration_width = size.width + gap
  fn(available_width, _available_height) {
    let label_width = if available_width > 0.0 {
      (available_width - decoration_width).max(0.0)
    } else {
      0.0
    }
    let label_size = measure(label_width, 0.0)
    let height = size.height.max(label_size.max_height)
    {
      min_width: decoration_width + label_size.min_width,
      max_width: decoration_width + label_size.max_width,
      min_height: height,
      max_height: height,
    }
  }
}

///|
fn choice_indicator_size(indicator : @style.BoxStyle) -> @foundation.Size {
  Size(
    width=style_length(indicator.layout.width.unwrap_or(18.0)),
    height=style_length(indicator.layout.height.unwrap_or(18.0)),
  )
}

///|
// Keep NaN, infinities and negative declarations out of intrinsic geometry.
fn style_length(value : Double) -> Double {
  if !value.is_nan() && !value.is_inf() {
    value.max(0.0)
  } else {
    0.0
  }
}

///|
fn fixed_measure(size : @foundation.Size) -> @view.Measure {
  fn(_, _) {
    {
      min_width: size.width,
      max_width: size.width,
      min_height: size.height,
      max_height: size.height,
    }
  }
}
