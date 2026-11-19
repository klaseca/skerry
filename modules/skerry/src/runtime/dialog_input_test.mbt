///|
test "dialog edits reuse background layout and background updates still reflow" {
  let value = @reactive.signal("")
  let width = @reactive.signal(120.0)
  let open = @reactive.signal(true)
  let background_builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          component_name="Background",
          style=@style.BoxStyle().width(width).height(20.0),
          measure=fn(context) {
            background_builds.val += 1
            @view.text_measure(
              "Background",
              context.font,
              context.text_layout_system,
            )
          },
          painter=@view.Painter::empty(),
        ),
        @controls.dialog(popup_test_button("open"), open~, fn(_close) {
          @controls.text_input(value~)
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  root.paint(ScrollRecorder(), size~)
  let builds = background_builds.val
  let passes = root.frame_stats().layout_pass_count
  let focus = root.snapshot().unwrap().focused_node_id
  for _ in 0..<20 {
    assert_true(root.text_input("x"))
    root.paint(ScrollRecorder(), size~)
    assert_eq(root.snapshot().unwrap().focused_node_id, focus)
  }
  assert_eq(value.get(), String::from_array(Array::make(20, 'x')))
  assert_eq(background_builds.val, builds)
  // The floating surface needs one pass; the background does not need another.
  assert_eq(root.frame_stats().layout_pass_count - passes, 20)
  for background_first in [false, true] {
    let next = if background_first { 240.0 } else { 180.0 }
    @reactive.batch(fn() {
      if background_first {
        width.set(next)
      }
      value.set("changed")
      if !background_first {
        width.set(next)
      }
    })
    let before = background_builds.val
    root.paint(ScrollRecorder(), size~)
    assert_true(background_builds.val > before)
    let background = root.snapshot().unwrap().tree.nodes[1]
    assert_eq(background.component_name, "Background")
    assert_eq(background.frame.size.width, next)
  }
  let before = root.frame_stats().layout_pass_count
  let small = @foundation.Size(width=320.0, height=240.0)
  root.paint(ScrollRecorder(), size=small)
  assert_true(root.frame_stats().layout_pass_count - before >= 2)
  assert_eq(root.snapshot().unwrap().tree.nodes[0].frame.size, small)
  let theme_builds = background_builds.val
  root.set_theme(@style.Theme(font=@foundation.FontSpec::default().size(24.0)))
  root.paint(ScrollRecorder(), size=small)
  assert_true(background_builds.val > theme_builds)
  let before = background_builds.val
  open.set(false)
  root.paint(ScrollRecorder(), size=small)
  assert_eq(background_builds.val, before)
  assert_true(root.view().overlay_targets().is_empty())
}
