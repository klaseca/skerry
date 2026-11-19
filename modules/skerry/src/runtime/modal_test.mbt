///|
test "modal uses ordinary flex alignment instead of centering its content" {
  let panel_id = Ref(-1)
  let root = @runtime.mount(
    fn() {
      @view.modal(popup_test_button("open"), open=@reactive.signal(true), fn(
        _close,
      ) {
        let panel = popup_test_button("panel")
        panel_id.val = panel.node_id_at_path([]).unwrap()
        panel
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(ScrollRecorder(), size=Size(width=320.0, height=240.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  let panel = nodes.iter().filter(node => node.id == panel_id.val).to_array()[0]
  assert_eq(panel.frame, Rect(x=0.0, y=0.0, width=80.0, height=24.0))
  assert_true(panel.state.focused)
  assert_true(
    nodes.any(node => {
      node.component_name == "Modal" &&
      node.frame == Rect(x=0.0, y=0.0, width=320.0, height=240.0)
    }),
  )
}

///|
test "modal layout reacts without rebuilding and uses positioned content for dismissal" {
  let open = @reactive.signal(true)
  let at_end = @reactive.signal(false)
  let creates = Ref(0)
  let clicks = Ref(0)
  let panel_id = Ref(-1)
  let root = @runtime.mount(
    fn() {
      @view.modal(
        popup_test_button("open"),
        open~,
        style=@view.FlexStyle::computed(fn() {
          @view.FlexStyle()
          .padding(@foundation.Insets::all(20.0))
          .align_items(if at_end.get() { End } else { Start })
          .justify_content(if at_end.get() { End } else { Start })
        }),
        fn(_close) {
          creates.val += 1
          let panel = popup_test_button("panel", on_click=fn() {
            clicks.val += 1
          })
          panel_id.val = panel.node_id_at_path([]).unwrap()
          panel
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=320.0, height=240.0)
  root.paint(ScrollRecorder(), size~)
  let panel = root.snapshot().unwrap().tree.nodes
    .iter()
    .filter(node => node.id == panel_id.val)
    .to_array()[0]
  assert_eq(panel.frame, Rect(x=20.0, y=20.0, width=80.0, height=24.0))
  at_end.set(true)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(ScrollRecorder(), size~)
  let moved = root.snapshot().unwrap().tree.nodes
    .iter()
    .filter(node => node.id == panel_id.val)
    .to_array()[0]
  assert_eq(moved.frame, Rect(x=220.0, y=196.0, width=80.0, height=24.0))
  assert_eq(moved.id, panel.id)
  assert_eq(creates.val, 1)
  assert_true(root.click_at(size~, point=Point(x=230.0, y=205.0)))
  assert_eq(clicks.val, 1)
  assert_true(open.get())
  assert_true(root.click_at(size~, point=Point(x=25.0, y=25.0)))
  assert_false(open.get())
}
