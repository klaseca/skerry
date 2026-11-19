///|
test "overlay host targets and frozen snapshots carry each layer's input policy" {
  let open = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.popup(
          popup_test_button("popup"),
          open=@reactive.signal(true),
          focus=false,
          fn(_close) { @view.text("Passive popup") },
        ),
        @controls.dialog(
          popup_test_button("dialog"),
          open~,
          close_on_escape=false,
          close_on_backdrop=false,
          fn(_close) { popup_test_button("inside") },
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  let popup = root.view().overlay_targets()[0]
  assert_eq(
    popup.behavior,
    @foundation.OverlayBehavior(escape=Dismiss, outside_press=Dismiss),
  )
  root.paint(ScrollRecorder(), size~)
  let previous = root.snapshot().unwrap()
  let popup_snapshot = previous.tree.nodes
    .iter()
    .filter(node => node.id == popup.node_id)
    .to_array()[0]
  assert_eq(
    popup_snapshot.overlay,
    Some({ trigger_id: popup.trigger_id, behavior: popup.behavior, }),
  )
  open.set(true)
  let targets = root.view().overlay_targets()
  assert_eq(targets.length(), 2)
  let modal = targets[1]
  assert_eq(
    modal.behavior,
    @foundation.OverlayBehavior(
      focus=Contain,
      pointer=BlockOutside,
      escape=Consume,
      outside_press=Consume,
    ),
  )
  assert_false(root.view().focus_allows_path(popup.path))
  assert_false(root.view().pointer_allows_path(popup.path))
  assert_true(root.view().focus_allows_path(modal.path))
  root.paint(ScrollRecorder(), size~)
  let modal_snapshot = root.snapshot().unwrap().tree.nodes
    .iter()
    .filter(node => node.id == modal.node_id)
    .to_array()[0]
  assert_eq(
    modal_snapshot.overlay,
    Some({ trigger_id: modal.trigger_id, behavior: modal.behavior, }),
  )
  assert_eq(modal_snapshot.frame, @foundation.Rect::from_size(size))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(open.get())
  open.set(false)
  assert_eq(root.view().overlay_targets().length(), 1)
  assert_true(root.view().focus_allows_path(popup.path))
  assert_eq(
    popup_snapshot.overlay,
    Some({ trigger_id: popup.trigger_id, behavior: popup.behavior, }),
  )
}
