///|
test "mounted controls can request focus without clearing it for invalid targets" {
  let context : Ref[@view.MountContext?] = Ref(None)
  let blocked = @reactive.signal(true)
  let now = Ref(50.0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("First"),
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) { () }),
          reactivity=@view.Reactivity(mount=fn(host) {
            context.val = Some(host)
            fn() { () }
          }),
        ),
        @controls.button("Blocked", disabled=blocked),
      ])
    },
    clock=fn() { now.val },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let host = context.val.unwrap()
  let first = root.view().node_id_at_path([0]).unwrap()
  let decoration = root.view().node_id_at_path([1]).unwrap()
  let last = root.view().node_id_at_path([2]).unwrap()
  assert_true(host.request_focus(first))
  assert_false(host.request_focus(decoration))
  assert_false(host.request_focus(last))
  assert_false(host.request_focus(-1))
  root.paint(StyleRecorder(), size=Size(width=200.0, height=150.0))
  assert_eq(root.snapshot().unwrap().focused_node_id, Some(first))
  assert_eq(host.now(), 50.0)
  now.val = 80.0
  assert_eq(host.now(), 80.0)
  blocked.set(false)
  assert_true(host.request_focus(last))
  root.paint(StyleRecorder(), size=Size(width=200.0, height=150.0))
  assert_eq(root.snapshot().unwrap().focused_node_id, Some(last))
  root.dispose()
  assert_false(host.request_focus(first))
}
