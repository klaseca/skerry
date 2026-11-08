///|
pub fn text_measure(
  text : String,
  font : @foundation.FontSpec,
  text_layout_system : @text.TextLayoutSystem,
) -> Measure {
  let natural = text_layout_system.layout(
      TextLayoutInput(text~, font~, max_width=None),
    ).size
  // The text system wraps by character; its minimum is the widest character.
  let mut minimum = 0.0
  for char in text {
    let size = text_layout_system.layout(
        TextLayoutInput(text=String::from_array([char]), font~, max_width=None),
      ).size
    minimum = minimum.max(size.width)
  }
  fn(available_width, _available_height) {
    let max_width = if available_width > 0.0 {
      Some(available_width)
    } else {
      None
    }
    let size = match max_width {
      Some(_) =>
        text_layout_system.layout(TextLayoutInput(text~, font~, max_width~)).size
      None => natural
    }
    {
      min_width: minimum,
      max_width: natural.width,
      min_height: size.height,
      max_height: size.height,
    }
  }
}
