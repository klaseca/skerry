///|
pub(all) struct TextLayoutInput {
  text : String
  font : @foundation.FontSpec
  max_width : Double?
}

///|
pub(all) struct TextLayoutLine {
  text : String
  x : Double
  y : Double
  width : Double
  height : Double
  baseline : Double
}

///|
pub(all) struct TextLayoutResult {
  lines : Array[TextLayoutLine]
  size : @foundation.Size
  baseline : Double
  caret_positions : Array[Double]
}

///|
pub(all) struct TextMeasureInput {
  text : String
  font : @foundation.FontSpec
}

///|
pub(all) struct TextMetrics {
  width : Double
  line_height : Double
  baseline : Double
  caret_positions : Array[Double]
}

///|
pub struct TextMetricsProvider {
  priv measure : (TextMeasureInput) -> TextMetrics
}

///|
pub struct TextLayoutSystem {
  priv provider : TextMetricsProvider
  priv mut measure_count : Int32
  priv mut cache_enabled : Bool
  priv mut cache_generation : Int32
  priv metrics_cache : TextCache[MeasureCacheKey, TextMetrics]
  priv layout_cache : TextCache[LayoutCacheKey, TextLayoutResult]
}

///|
pub fn TextLayoutInput::TextLayoutInput(
  text~ : String,
  font~ : @foundation.FontSpec = @foundation.FontSpec::default(),
  max_width~ : Double? = None,
) -> TextLayoutInput {
  { text, font, max_width, }
}

///|
pub fn TextMeasureInput::TextMeasureInput(
  text~ : String,
  font~ : @foundation.FontSpec = @foundation.FontSpec::default(),
) -> TextMeasureInput {
  { text, font, }
}

///|
pub fn TextMetrics::TextMetrics(
  width~ : Double,
  line_height~ : Double,
  baseline~ : Double,
  caret_positions~ : Array[Double],
) -> TextMetrics {
  { width, line_height, baseline, caret_positions, }
}

///|
pub fn TextMetricsProvider::TextMetricsProvider(
  measure~ : (TextMeasureInput) -> TextMetrics,
) -> TextMetricsProvider {
  { measure, }
}

///|
/// Cache metrics/layout by text and font (plus width for layout). Cached providers
/// must return stable metrics for those inputs; disable caching for dynamic
/// providers or explicitly clear it when external font/scale resources change.
/// Returned arrays are independent of retained cache data.
pub fn TextLayoutSystem::from_metrics(
  provider : TextMetricsProvider,
  cache~ : Bool = true,
) -> TextLayoutSystem {
  {
    provider,
    measure_count: 0,
    cache_enabled: cache,
    cache_generation: 0,
    metrics_cache: TextCache::new(METRICS_CACHE_CAPACITY),
    layout_cache: TextCache::new(LAYOUT_CACHE_CAPACITY),
  }
}

///|
/// Start an independent measurement session using the same metrics provider.
/// Counts/caches begin empty and inherit this system's cache policy;
/// provider behavior and application state are shared.
/// Mounted roots use separate sessions even when supplied the same system.
pub fn TextLayoutSystem::new_session(
  self : TextLayoutSystem,
) -> TextLayoutSystem {
  TextLayoutSystem::from_metrics(self.provider, cache=self.cache_enabled)
}

///|
/// Number of calls to the metrics provider, including wrapping and input layout.
/// A single text layout can request many measurements. Reading is side-effect free.
pub fn TextLayoutSystem::measure_count(self : TextLayoutSystem) -> Int32 {
  self.measure_count
}

///|
fn TextLayoutSystem::measure(
  self : TextLayoutSystem,
  input : TextMeasureInput,
) -> TextMetrics {
  let generation = self.cache_generation
  let key : MeasureCacheKey = { text: input.text, font: input.font, }
  let cacheable = self.cache_enabled &&
    input.text.length() <= CACHE_PAYLOAD_LIMIT / 2 &&
    key == key
  if cacheable && self.metrics_cache.get(key) is Some(metrics) {
    return metrics
  }
  self.measure_count += 1
  let metrics = (self.provider.measure)(input)
  if cacheable &&
    generation == self.cache_generation &&
    metrics_payload_bytes(input, metrics) is Some(bytes) {
    let retained = {
      ..metrics,
      caret_positions: metrics.caret_positions.copy(),
    }
    self.metrics_cache.put(key, retained, bytes)
    retained
  } else {
    metrics
  }
}

///|
pub fn TextLayoutSystem::layout(
  self : TextLayoutSystem,
  input : TextLayoutInput,
) -> TextLayoutResult {
  let generation = self.cache_generation
  let key : LayoutCacheKey = {
    text: input.text,
    font: input.font,
    max_width: input.max_width.map(width => {
      if width <= 0.0 {
        0.0
      } else {
        width
      }
    }),
  }
  let cacheable = self.cache_enabled &&
    input.text.length() <= CACHE_PAYLOAD_LIMIT / 2 &&
    key == key
  if cacheable && self.layout_cache.get(key) is Some(layout) {
    return layout.copy()
  }
  let layout = layout_from_metrics(self, input)
  if cacheable &&
    generation == self.cache_generation &&
    layout_payload_bytes(input, layout) is Some(bytes) {
    self.layout_cache.put(key, layout.copy(), bytes)
  }
  layout
}

///|
fn layout_from_metrics(
  system : TextLayoutSystem,
  input : TextLayoutInput,
) -> TextLayoutResult {
  let base = system.measure(TextMeasureInput(text=input.text, font=input.font))
  let lines = match input.max_width {
    Some(max_width) =>
      layout_lines_from_metrics(
        system,
        input.text,
        input.font,
        max_width.max(0.0),
        base.line_height,
        base.baseline,
      )
    None =>
      unwrapped_lines_from_metrics(
        system,
        input.text,
        input.font,
        base.width,
        base.line_height,
        base.baseline,
      )
  }
  let width = lines.fold(init=0.0, fn(acc, line) { acc.max(line.width) })
  let height = lines.length().to_double() * base.line_height
  {
    lines,
    size: Size(width~, height~),
    baseline: base.baseline,
    caret_positions: base.caret_positions.copy(),
  }
}

///|
fn unwrapped_lines_from_metrics(
  system : TextLayoutSystem,
  text : String,
  font : @foundation.FontSpec,
  width : Double,
  line_height : Double,
  baseline : Double,
) -> Array[TextLayoutLine] {
  let lines : Array[TextLayoutLine] = []
  if !text.contains("\n") {
    push_layout_line(lines, text, width, line_height, baseline)
  } else {
    for paragraph in text.split("\n") {
      let line_text = paragraph.to_owned()
      push_layout_line(
        lines,
        line_text,
        measured_width(system, line_text, font),
        line_height,
        baseline,
      )
    }
  }
  if lines.is_empty() {
    push_layout_line(lines, "", 0.0, line_height, baseline)
  }
  for index, line in lines {
    lines[index] = { ..line, y: index.to_double() * line_height, }
  }
  lines
}

///|
fn layout_lines_from_metrics(
  system : TextLayoutSystem,
  text : String,
  font : @foundation.FontSpec,
  max_width : Double,
  line_height : Double,
  baseline : Double,
) -> Array[TextLayoutLine] {
  let lines : Array[TextLayoutLine] = []
  for paragraph in text.split("\n") {
    append_paragraph_lines(
      system,
      lines,
      paragraph.to_owned(),
      font,
      max_width,
      line_height,
      baseline,
    )
  }
  if lines.is_empty() {
    push_layout_line(lines, "", 0.0, line_height, baseline)
  }
  for index, line in lines {
    lines[index] = { ..line, y: index.to_double() * line_height, }
  }
  lines
}

///|
fn append_paragraph_lines(
  system : TextLayoutSystem,
  lines : Array[TextLayoutLine],
  paragraph : String,
  font : @foundation.FontSpec,
  max_width : Double,
  line_height : Double,
  baseline : Double,
) -> Unit {
  if paragraph.is_empty() {
    push_layout_line(lines, "", 0.0, line_height, baseline)
  } else if max_width <= 0.0 {
    push_layout_line(
      lines,
      paragraph,
      measured_width(system, paragraph, font),
      line_height,
      baseline,
    )
  } else {
    append_wrapped_paragraph(
      system, lines, paragraph, font, max_width, line_height, baseline,
    )
  }
}

///|
fn append_wrapped_paragraph(
  system : TextLayoutSystem,
  lines : Array[TextLayoutLine],
  paragraph : String,
  font : @foundation.FontSpec,
  max_width : Double,
  line_height : Double,
  baseline : Double,
) -> Unit {
  let mut current = ""
  let mut current_width = 0.0
  for char in paragraph {
    let candidate = current + String::from_array([char])
    let candidate_width = measured_width(system, candidate, font)
    if !current.is_empty() && candidate_width > max_width {
      push_layout_line(lines, current, current_width, line_height, baseline)
      current = String::from_array([char])
      current_width = measured_width(system, current, font)
    } else {
      current = candidate
      current_width = candidate_width
    }
  }
  if !current.is_empty() {
    push_layout_line(lines, current, current_width, line_height, baseline)
  }
}

///|
fn measured_width(
  system : TextLayoutSystem,
  text : String,
  font : @foundation.FontSpec,
) -> Double {
  system.measure(TextMeasureInput(text~, font~)).width
}

///|
fn push_layout_line(
  lines : Array[TextLayoutLine],
  text : String,
  width : Double,
  line_height : Double,
  baseline : Double,
) -> Unit {
  lines.push({ text, x: 0.0, y: 0.0, width, height: line_height, baseline, })
}
