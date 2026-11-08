///|
test "text layout wraps by available width" {
  let font = @foundation.FontSpec::default().size(10.0)
  let layout = test_text_layout_system().layout(
    TextLayoutInput(text="hello moonbit ui", font~, max_width=Some(44.0)),
  )
  assert_true(layout.lines.length() >= 1)
  assert_true(layout.size.width <= 44.0)
  assert_true(layout.size.height >= 12.5)
}

///|
fn test_text_layout_system() -> @text.TextLayoutSystem {
  @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      let advance = input.font.point_size() * 0.6
      let carets : Array[Double] = [0.0]
      let mut width = 0.0
      for _ in input.text {
        width = width + advance
        carets.push(width)
      }
      TextMetrics(
        width~,
        line_height=input.font.point_size() * 1.25,
        baseline=input.font.point_size(),
        caret_positions=carets,
      )
    }),
  )
}
