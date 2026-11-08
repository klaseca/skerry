///|
fn assert_same_layout(
  actual : @text.TextLayoutResult,
  expected : @text.TextLayoutResult,
) -> Unit raise {
  assert_eq(actual.size, expected.size)
  assert_eq(actual.baseline, expected.baseline)
  assert_eq(actual.caret_positions, expected.caret_positions)
  assert_eq(
    actual.lines.map(line => {
      (line.text, line.x, line.y, line.width, line.height, line.baseline)
    }),
    expected.lines.map(line => {
      (line.text, line.x, line.y, line.width, line.height, line.baseline)
    }),
  )
}

///|
test "cached and uncached text layouts agree for text fonts and width constraints" {
  let cached = test_text_layout_system()
  let plain = test_text_layout_system()
  plain.set_cache_enabled(false)
  for
    text in [
      "", "one line", "a\n\nb", "Р В Р’В Р вЂ™Р’В°Р В Р’В Р вЂ™Р’В±Р РЋР вЂљР РЋРЎСџР Р†РІР‚С›РЎС›Р Р†Р вЂљРЎв„ўcd",
      "eР В РЎС™Р В РЎвЂњ and text", "word word word word",
    ] {
    for size in [10.0, 16.0] {
      let font = @foundation.FontSpec::default().size(size)
      for
        width in [
          None,
          Some(-10.0),
          Some(0.0),
          Some(1.0),
          Some(25.0),
          Some(200.0),
        ] {
        let input = @text.TextLayoutInput(text~, font~, max_width=width)
        let expected = plain.layout(input)
        assert_same_layout(cached.layout(input), expected)
        let before = cached.measure_count()
        assert_same_layout(cached.layout(input), expected)
        assert_eq(cached.measure_count(), before)
      }
    }
  }
  assert_true(cached.cache_stats().layout_hits > 0)
  assert_true(cached.measure_count() < plain.measure_count())
}

///|
test "cache keys distinguish text font wrapping and normalized zero width" {
  let system = test_text_layout_system()
  let font = @foundation.FontSpec::default().size(10.0)
  let natural = system.layout(TextLayoutInput(text="abcd", font~))
  let first = system.cache_stats()
  let zero = system.layout(
    TextLayoutInput(text="abcd", font~, max_width=Some(0.0)),
  )
  assert_same_layout(zero, natural)
  assert_eq(system.cache_stats().layout_entries, 2)
  assert_eq(system.cache_stats().layout_hits, first.layout_hits)
  assert_true(system.cache_stats().measure_hits > first.measure_hits)
  ignore(
    system.layout(TextLayoutInput(text="abcd", font~, max_width=Some(-7.0))),
  )
  ignore(
    system.layout(TextLayoutInput(text="abcd", font~, max_width=Some(-0.0))),
  )
  assert_eq(system.cache_stats().layout_hits, first.layout_hits + 2)
  let wrapped = system.layout(
    TextLayoutInput(text="abcd", font~, max_width=Some(13.0)),
  )
  assert_eq(wrapped.lines.length(), 2)
  assert_eq(wrapped.size.height, natural.size.height * 2.0)
  let larger = system.layout(TextLayoutInput(text="abcd", font=font.size(20.0)))
  assert_eq(larger.size.width, natural.size.width * 2.0)
  let before = system.measure_count()
  ignore(system.layout(TextLayoutInput(text="abce", font~)))
  assert_eq(system.measure_count(), before + 1)
}

///|
test "cached arrays are isolated from callers and provider-owned arrays" {
  let provider_carets : Array[Double] = [0.0, 10.0, 20.0]
  let system = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(_) {
      TextMetrics(
        width=20.0,
        line_height=10.0,
        baseline=8.0,
        caret_positions=provider_carets,
      )
    }),
  )
  let input = @text.TextLayoutInput(text="ab")
  let first = system.layout(input)
  first.lines.clear()
  first.caret_positions[1] = -100.0
  provider_carets[1] = -200.0
  let hit = system.layout(input)
  assert_eq(hit.lines.length(), 1)
  assert_eq(hit.lines[0].text, "ab")
  assert_eq(hit.caret_positions, [0.0, 10.0, 20.0])
  hit.caret_positions.clear()
  hit.lines.clear()
  let metric_hit = system.layout(
    TextLayoutInput(text="ab", max_width=Some(0.0)),
  )
  assert_eq(metric_hit.caret_positions, [0.0, 10.0, 20.0])
  assert_eq(metric_hit.size.width, 20.0)
  assert_eq(system.layout(input).caret_positions, [0.0, 10.0, 20.0])
  assert_eq(system.measure_count(), 1)
}

///|
test "layout cache evicts the least recently used entry at its capacity" {
  let system = test_text_layout_system()
  for width in 1..<=64 {
    ignore(
      system.layout(
        TextLayoutInput(text="abcdef", max_width=Some(width.to_double())),
      ),
    )
  }
  assert_eq(system.cache_stats().layout_entries, 64)
  let before = system.cache_stats().layout_hits
  ignore(system.layout(TextLayoutInput(text="abcdef", max_width=Some(1.0))))
  assert_eq(system.cache_stats().layout_hits, before + 1)
  ignore(system.layout(TextLayoutInput(text="abcdef", max_width=Some(65.0))))
  let filled = system.cache_stats()
  assert_eq(filled.layout_entries, 64)
  assert_eq(filled.evictions, 1)
  ignore(system.layout(TextLayoutInput(text="abcdef", max_width=Some(1.0))))
  assert_eq(system.cache_stats().layout_hits, filled.layout_hits + 1)
  ignore(system.layout(TextLayoutInput(text="abcdef", max_width=Some(2.0))))
  assert_eq(system.cache_stats().layout_hits, filled.layout_hits + 1)
  assert_eq(system.cache_stats().evictions, 2)
}

///|
test "metrics cache maintains LRU order independently of layout eviction" {
  let system = test_text_layout_system()
  for index in 0..<256 {
    ignore(system.layout(TextLayoutInput(text="entry\{index}")))
  }
  assert_eq(system.cache_stats().measure_entries, 256)
  assert_eq(system.cache_stats().layout_entries, 64)
  let before = system.measure_count()
  ignore(system.layout(TextLayoutInput(text="entry0")))
  assert_eq(system.measure_count(), before)
  ignore(system.layout(TextLayoutInput(text="entry256")))
  assert_eq(system.measure_count(), before + 1)
  ignore(system.layout(TextLayoutInput(text="entry0")))
  assert_eq(system.measure_count(), before + 1)
  ignore(system.layout(TextLayoutInput(text="entry1")))
  assert_eq(system.measure_count(), before + 2)
  assert_eq(system.cache_stats().measure_entries, 256)
}

///|
test "cache payload is bounded separately from entry capacity" {
  let system = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      TextMetrics(
        width=input.text.length().to_double(),
        line_height=10.0,
        baseline=8.0,
        caret_positions=Array::make(1000, 0.0),
      )
    }),
  )
  for index in 0..<100 {
    ignore(system.layout(TextLayoutInput(text="payload\{index}")))
    assert_true(system.cache_stats().payload_bytes <= 512 * 1024)
  }
  let stats = system.cache_stats()
  assert_true(stats.measure_entries < 256)
  assert_true(stats.layout_entries < 64)
  assert_true(stats.evictions > 0)
  assert_true(stats.payload_bytes > 0)
  let before = system.measure_count()
  ignore(system.layout(TextLayoutInput(text="payload99")))
  assert_eq(system.measure_count(), before)
}

///|
test "oversized results and strings bypass retention without flushing useful entries" {
  let system = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      TextMetrics(
        width=input.text.length().to_double(),
        line_height=10.0,
        baseline=8.0,
        caret_positions=if input.text == "large" {
          Array::make(40_000, 0.0)
        } else {
          [0.0]
        },
      )
    }),
  )
  ignore(system.layout(TextLayoutInput(text="small")))
  let useful = system.cache_stats()
  for _ in 0..<2 {
    let result = system.layout(TextLayoutInput(text="large"))
    assert_eq(result.caret_positions.length(), 40_000)
  }
  let large_text = String::from_array(Array::make(140_000, 'x'))
  for _ in 0..<2 {
    assert_eq(
      system.layout(TextLayoutInput(text=large_text)).size.width,
      140_000.0,
    )
  }
  assert_eq(system.cache_stats().measure_entries, useful.measure_entries)
  assert_eq(system.cache_stats().layout_entries, useful.layout_entries)
  assert_eq(system.cache_stats().payload_bytes, useful.payload_bytes)
  assert_eq(system.cache_stats().evictions, useful.evictions)
  let before = system.measure_count()
  ignore(system.layout(TextLayoutInput(text="small")))
  assert_eq(system.measure_count(), before)
}

///|
test "explicit invalidation and cache opt-out respect changing provider metrics" {
  let factor = Ref(1.0)
  let system = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(_) {
      TextMetrics(width=20.0 * factor.val, line_height=10.0, baseline=8.0, caret_positions=[
        0.0,
        20.0 * factor.val,
      ])
    }),
  )
  let input = @text.TextLayoutInput(text="a")
  let previous = system.layout(input)
  factor.val = 2.0
  assert_eq(system.layout(input).size.width, 20.0)
  let calls = system.measure_count()
  let hits = system.cache_stats().layout_hits
  system.clear_cache()
  assert_eq(system.measure_count(), calls)
  assert_eq(system.cache_stats().payload_bytes, 0)
  assert_eq(system.cache_stats().layout_hits, hits)
  assert_eq(system.layout(input).size.width, 40.0)
  assert_eq(previous.caret_positions, [0.0, 20.0])
  system.set_cache_enabled(false)
  let session = system.new_session()
  assert_false(session.cache_stats().enabled)
  factor.val = 3.0
  assert_eq(system.layout(input).size.width, 60.0)
  factor.val = 4.0
  assert_eq(system.layout(input).size.width, 80.0)
  assert_eq(system.cache_stats().payload_bytes, 0)
  system.set_cache_enabled(true)
  assert_eq(system.layout(input).size.width, 80.0)
  let before = system.measure_count()
  ignore(system.layout(input))
  assert_eq(system.measure_count(), before)
}

///|
test "clear during provider execution prevents storing obsolete results" {
  let system_ref : Ref[@text.TextLayoutSystem?] = Ref(None)
  let first = Ref(true)
  let width = Ref(20.0)
  let system = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(_) {
      let measured = width.val
      if first.val && system_ref.val is Some(system) {
        first.val = false
        width.val = 40.0
        system.clear_cache()
      }
      TextMetrics(width=measured, line_height=10.0, baseline=8.0, caret_positions=[
        0.0, measured,
      ])
    }),
  )
  system_ref.val = Some(system)
  let input = @text.TextLayoutInput(text="a")
  assert_eq(system.layout(input).size.width, 20.0)
  assert_eq(system.cache_stats().payload_bytes, 0)
  assert_eq(system.layout(input).size.width, 40.0)
  assert_eq(system.measure_count(), 2)
  ignore(system.layout(input))
  assert_eq(system.measure_count(), 2)
}

///|
test "non-reflexive width keys bypass layout caching" {
  let system = test_text_layout_system()
  let nan = 0.0 / 0.0
  for _ in 0..<10 {
    ignore(system.layout(TextLayoutInput(text="ab", max_width=Some(nan))))
  }
  assert_eq(system.cache_stats().layout_entries, 0)
  assert_eq(system.cache_stats().layout_hits, 0)
  assert_true(system.cache_stats().measure_entries > 0)
}
