///|
test "cached and uncached roots paint the same form through updates and resize" {
  let value = @reactive.signal("wrapped text for the form")
  let checked = @reactive.signal(false)
  let create = fn() {
    @view.column([
      @view.text_of(value),
      @controls.button("button"),
      @controls.checkbox(checked~, label="check"),
      @controls.text_input(value~),
    ])
  }
  let cached_system = test_text_layout_system()
  let plain_system = test_text_layout_system()
  plain_system.set_cache_enabled(false)
  let cached = @runtime.mount(create, text_layout_system=cached_system)
  defer cached.dispose()
  let plain = @runtime.mount(create, text_layout_system=plain_system)
  defer plain.dispose()
  let cached_renderer = StyleRecorder()
  let plain_renderer = StyleRecorder()
  for step in 0..<4 {
    if step == 1 {
      checked.set(true)
    }
    if step == 2 {
      value.set("new shorter text")
    }
    let size = @foundation.Size(
      width=if step == 3 { 95.0 } else { 220.0 },
      height=240.0,
    )
    let before = cached.frame_stats().text_measure_count
    cached.paint(cached_renderer, size~)
    plain.paint(plain_renderer, size~)
    assert_eq(cached_renderer.text, plain_renderer.text)
    assert_eq(cached_renderer.fills, plain_renderer.fills)
    assert_eq(cached_renderer.strokes, plain_renderer.strokes)
    let cached_tree = cached.snapshot().unwrap().tree
    let plain_tree = plain.snapshot().unwrap().tree
    assert_eq(cached_tree.size, plain_tree.size)
    assert_eq(cached_tree.nodes.length(), plain_tree.nodes.length())
    for i, actual in plain_tree.nodes {
      let expected = cached_tree.nodes[i]
      // Both instances have the same structure and values with distinct IDs.
      assert_true(actual.id != expected.id)
      let translate = fn(id) {
        for j, node in plain_tree.nodes {
          if node.id == id {
            return cached_tree.nodes[j].id
          }
        }
        abort("snapshot references a missing node")
      }
      assert_eq(
        {
          ..actual,
          id: translate(actual.id),
          parent_id: actual.parent_id.map(translate),
          children: ReadOnlyArray::from_iter(
            actual.children.iter().map(translate),
          ),
        },
        expected,
      )
    }
    if step == 1 {
      assert_eq(cached.frame_stats().text_measure_count, before)
      assert_eq(cached.frame_stats().last_paint.unwrap().text_measure_count, 0)
      assert_true(
        plain.frame_stats().last_paint.unwrap().text_measure_count > 0,
      )
    }
  }
  assert_true(
    cached.frame_stats().text_measure_count <
    plain.frame_stats().text_measure_count,
  )
  assert_true(cached.frame_stats().text_cache.layout_hits > 0)
}

///|
test "caret hit testing and cursor paints reuse text metrics" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() { @controls.text_input(value~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=40.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  let first = root.frame_stats()
  assert_true(root.pointer_down(size~, point=Point(x=20.0, y=20.0)))
  assert_true(root.pointer_up(size~, point=Point(x=20.0, y=20.0)))
  root.paint(renderer, size~)
  let clicked = root.frame_stats()
  assert_eq(clicked.text_measure_count, first.text_measure_count)
  assert_eq(clicked.layout_count, first.layout_count)
  assert_true(clicked.text_cache.layout_hits > first.text_cache.layout_hits)
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().text_measure_count, first.text_measure_count)
  assert_eq(value.get(), "abc")
}

///|
test "external metrics invalidation clears text and requests one layout frame" {
  let factor = Ref(1.0)
  let system = @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      let advance = 10.0 * factor.val
      let carets = [0.0]
      let mut width = 0.0
      for _ in input.text {
        width += advance
        carets.push(width)
      }
      TextMetrics(
        width~,
        line_height=10.0,
        baseline=8.0,
        caret_positions=carets,
      )
    }),
  )
  let root = @runtime.mount(
    fn() { @view.text("abc") },
    text_layout_system=system,
  )
  defer root.dispose()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=40.0)
  root.paint(renderer, size~)
  let width = renderer.text[0].frame.size.width
  let first = root.snapshot().unwrap()
  let before = root.frame_stats().text_measure_count
  factor.val = 2.0
  root.invalidate_text()
  root.invalidate_text()
  assert_eq(root.dirty(), NeedsLayout)
  assert_eq(wakeups.val, 1)
  assert_eq(root.frame_stats().text_cache.payload_bytes, 0)
  assert_eq(root.frame_stats().text_measure_count, before)
  assert_true(root.snapshot() is None)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].frame.size.width, width * 2.0)
  assert_true(root.frame_stats().text_measure_count > before)
  assert_eq(root.frame_stats().layout_count, 2)
  assert_true(first.frame.text_cache.payload_bytes > 0)
  root.dispose()
  assert_eq(root.frame_stats().text_cache.payload_bytes, 0)
  assert_false(root.frame_stats().text_cache.enabled)
  root.invalidate_text()
  assert_false(root.needs_frame())
}

///|
test "disposal during measurement leaves text caches empty" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() { @view.text("dispose while wrapping this text") },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      if first.val && root_ref.val is Some(root) {
        first.val = false
        root.dispose()
      }
    }),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  performance_paint(root)
  assert_true(root.is_disposed())
  let stats = root.frame_stats()
  assert_eq(stats.paint_count, 0)
  assert_eq(stats.last_paint, None)
  assert_false(stats.text_cache.enabled)
  assert_eq(stats.text_cache.measure_entries, 0)
  assert_eq(stats.text_cache.layout_entries, 0)
  assert_eq(stats.text_cache.payload_bytes, 0)
}
