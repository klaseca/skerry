///|
test "measurement sessions count real provider calls independently" {
  let calls = Ref(0)
  let source = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      calls.val += 1
      let width = input.text.length().to_double() * 10.0
      TextMetrics(width~, line_height=10.0, baseline=8.0, caret_positions=[])
    }),
  )
  let first = source.new_session()
  let second = first.new_session()
  assert_eq(source.measure_count(), 0)
  ignore(first.layout(TextLayoutInput(text="abcdef", max_width=Some(25.0))))
  assert_true(first.measure_count() > 1)
  assert_eq(first.measure_count(), calls.val)
  assert_eq(second.measure_count(), 0)
  assert_eq(source.measure_count(), 0)
  let before = first.measure_count()
  let result = second.layout(TextLayoutInput(text="abcdef"))
  assert_eq(result.size.width, 60.0)
  assert_eq(second.measure_count(), 1)
  assert_eq(first.measure_count(), before)
  assert_eq(calls.val, before + 1)
  ignore(source.layout(TextLayoutInput(text="a\nb")))
  assert_eq(source.measure_count(), 3)
  assert_eq(first.measure_count(), before)
  assert_eq(second.measure_count(), 1)
  assert_eq(calls.val, before + 4)
}
