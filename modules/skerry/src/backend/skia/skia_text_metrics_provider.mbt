///|
fn skia_text_metrics_provider(
  font : @skia_lib.Font,
) -> @text.TextMetricsProvider {
  TextMetricsProvider(measure=fn(input) { measure_skia_text(font, input) })
}

///|
fn measure_skia_text(
  font : @skia_lib.Font,
  input : @text.TextMeasureInput,
) -> @text.TextMetrics {
  font.set_size(Float::from_double(input.font.point_size()))
  let metrics = font.metrics()
  let line_height = skia_line_height(input.font, metrics)
  let baseline = skia_baseline(input.font, metrics, line_height)
  TextMetrics(
    width=skia_text_width(font, input.text),
    line_height~,
    baseline~,
    caret_positions=skia_caret_positions(font, input.text),
  )
}

///|
fn skia_line_height(
  font_spec : @foundation.FontSpec,
  metrics : @skia_lib.FontMetrics,
) -> Double {
  let ascent = metrics.ascent.to_double()
  let descent = metrics.descent.to_double()
  let leading = metrics.leading.to_double()
  let height = descent - ascent + leading
  if height > 0.0 {
    height
  } else {
    font_spec.point_size() * 1.25
  }
}

///|
fn skia_baseline(
  font_spec : @foundation.FontSpec,
  metrics : @skia_lib.FontMetrics,
  line_height : Double,
) -> Double {
  let ascent = metrics.ascent.to_double()
  let descent = metrics.descent.to_double()
  let text_height = (descent - ascent).max(0.0)
  if text_height > 0.0 {
    (line_height - text_height) * 0.5 - ascent
  } else {
    font_spec.point_size() * 0.8
  }
}

///|
fn skia_caret_positions(font : @skia_lib.Font, text : String) -> Array[Double] {
  let carets : Array[Double] = [0.0]
  let advances : Map[Char, Float] = Map([])
  // Canvas::draw_text uses Skia's drawSimpleText: one glyph per code point,
  // without shaping or kerning. Accumulate Float advances as SkFont::getPos
  // does, rather than re-encoding and measuring every growing prefix.
  // Keep the cache local: the shared font's size can change between calls.
  for char in text; x = Float::from_double(0.0) {
    let advance = match advances.get(char) {
      Some(advance) => advance
      None => {
        let advance = font.measure_text(
          @utf8.encode(String::from_array([char])),
        )
        advances[char] = advance
        advance
      }
    }
    let next_x = x + advance
    carets.push(next_x.to_double())
    continue next_x
  }
  carets
}

///|
fn skia_text_width(font : @skia_lib.Font, text : String) -> Double {
  font.measure_text(@utf8.encode(text)).to_double()
}
