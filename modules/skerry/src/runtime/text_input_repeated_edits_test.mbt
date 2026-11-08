///|
test "repeated typing and deletion preserve focus geometry and paint-only cache reuse" {
  for cache in [false, true] {
    let system = test_text_layout_system()
    system.set_cache_enabled(cache)
    let value = @reactive.signal("")
    let root = @runtime.mount(
      fn() {
        @view.column([
          @controls.text_input(
            value~,
            placeholder="empty",
            style=@controls.TextInputStyle().surface(
              @style.BoxStyle().width(120.0).height(36.0),
            ),
          ),
        ])
      },
      text_layout_system=system,
    )
    defer root.dispose()
    let size = @foundation.Size(width=200.0, height=80.0)
    let recorder = TextRunRecorder::{ text: Ref(None), }
    assert_true(root.key_down(test_key_event(KeyTab)))
    root.paint(recorder, size~)
    let before = root.snapshot().unwrap()
    for cycle in 0..<3 {
      for length in 1..<=64 {
        assert_true(root.text_input("x"))
        root.paint(recorder, size~)
        assert_eq(recorder.text.val, Some(String::make(length, 'x')))
      }
      for length in 64>..0 {
        assert_true(root.key_down(test_key_event(KeyBackspace)))
        root.paint(recorder, size~)
        assert_eq(
          recorder.text.val,
          Some(if length == 0 { "empty" } else { String::make(length, 'x') }),
        )
      }
      assert_eq(value.peek(), "")
      let after = root.snapshot().unwrap()
      assert_eq(after.focused_node_id, before.focused_node_id)
      assert_eq(after.tree, before.tree)
      assert_eq(
        after.frame.layout_count,
        before.frame.layout_count + (cycle + 1) * 128,
      )
      assert_false(root.needs_frame())
      let passes = after.frame.layout_pass_count
      root.mark_paint_dirty()
      root.paint(recorder, size~)
      assert_eq(root.frame_stats().layout_pass_count, passes)
      assert_eq(root.frame_stats().last_paint.unwrap().layout_count, 0)
    }
  }
}
