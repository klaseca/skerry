///|
test "Skia caret advances agree with prefix measurements at Unicode boundaries" {
  let typeface = @skia_lib.Typeface::default()
  defer typeface.dispose()
  let font = @skia_lib.Font(typeface, size=14.0)
  defer font.dispose()
  for size in [14.0, 13.25, 32.5, 96.0, 513.25, 0.0, 14.0] {
    font.set_size(Float::from_double(size))
    for
      text in [
        "", "AV office ffi 123", "Привет 世界", "a\u{301}😀👩\u{200d}💻z",
        "a\u{0}b",
      ] {
      let carets = skia_caret_positions(font, text)
      assert_eq(carets.length(), text.iter().count() + 1)
      assert_eq(carets[0], 0.0)
      let prefix : Array[Char] = []
      for char in text {
        prefix.push(char)
        let expected = skia_text_width(font, String::from_array(prefix))
        assert_true((carets[prefix.length()] - expected).abs() < 0.001)
      }
    }
  }
}

///|
test "Skia metrics preserve all caret positions for long input" {
  let typeface = @skia_lib.Typeface::default()
  defer typeface.dispose()
  let font = @skia_lib.Font(typeface, size=14.0)
  defer font.dispose()
  for length in [10_000, 20_000, 40_000] {
    let text = String::from_array(Array::make(length, 'W'))
    let metrics = measure_skia_text(font, TextMeasureInput(text~))
    assert_eq(metrics.caret_positions.length(), length + 1)
    assert_eq(metrics.caret_positions[0], 0.0)
    assert_eq(metrics.caret_positions[length], metrics.width)
    for i in 1..<=length {
      assert_true(metrics.caret_positions[i] > metrics.caret_positions[i - 1])
    }
  }
}

///|
test "Skia uncached metrics scale with input length" (bench : @bench.T) {
  let typeface = try! @skia_lib.Typeface::default()
  defer typeface.dispose()
  let font = try! @skia_lib.Font(typeface, size=14.0)
  defer font.dispose()
  for repetitions in [1000, 2000, 4000] {
    let text = Array::make(repetitions, "AV Привет😀 ").join("")
    let input = @text.TextMeasureInput(text~)
    bench.bench(name="\{text.iter().count()} code points", fn() {
      bench.keep(measure_skia_text(font, input))
    })
  }
}
