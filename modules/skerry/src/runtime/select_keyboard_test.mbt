///|
test "select Space and Enter confirm selection and restore focus after release" {
  for key in [@foundation.KeyEnter, KeySpace] {
    for initial in [None, Some(1)] {
      let selected = @reactive.signal(initial)
      let proposals : Array[Int32?] = []
      let root = @runtime.mount(
        fn() {
          @controls.select(
            [0, 1, 2].map(value => {
              @controls.SelectOption(value, label=value.to_string())
            }),
            selected~,
            on_change=fn(event) { proposals.push(event.value) },
          )
        },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      assert_true(root.key_down(test_key_event(KeyTab)))
      ignore(select_test_nodes(root))
      let field = root.snapshot().unwrap().focused_node_id
      assert_true(field is Some(_))
      assert_true(root.key_down(test_key_event(key)))
      ignore(root.key_up(test_key_event(key)))
      assert_eq(select_test_active(root), Some(initial.unwrap_or(0)))
      assert_true(root.key_down(test_key_event(KeyArrowDown)))
      let next = initial.unwrap_or(0) + 1
      assert_eq(select_test_active(root), Some(next))
      assert_eq(selected.peek(), initial)
      assert_true(root.key_down(test_key_event(key)))
      assert_true(root.view().popup_targets().is_empty())
      assert_true(root.view().popup_targets().is_empty())
      assert_eq(selected.peek(), Some(next))
      assert_eq(proposals, [Some(next)])
      // Holding the activation key must not start another popup session.
      ignore(root.key_down(@foundation.KeyEvent(key~, repeat=true)))
      ignore(root.key_up(test_key_event(key)))
      assert_true(root.view().popup_targets().is_empty())
      assert_eq(proposals, [Some(next)])
      ignore(select_test_nodes(root))
      assert_eq(root.snapshot().unwrap().focused_node_id, field)
      // Reopening remembers the committed option; confirming it emits no change.
      assert_true(root.key_down(test_key_event(KeyEnter)))
      assert_eq(select_test_active(root), Some(next))
      assert_true(root.key_down(test_key_event(key)))
      ignore(root.key_up(test_key_event(key)))
      assert_true(root.view().popup_targets().is_empty())
      assert_eq(selected.peek(), Some(next))
      assert_eq(proposals, [Some(next)])
    }
  }
}

///|
test "select accepts independent text commits including single and embedded spaces" {
  let root = @runtime.mount(
    fn() {
      @controls.select(
        ["First", "New York", " Leading space"].map(label => {
          @controls.SelectOption(label, label~)
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input(" "))
  assert_eq(select_test_active(root), Some(2))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(root.text_input("New York"))
  assert_eq(select_test_active(root), Some(1))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(root.text_input(" Leading"))
  assert_eq(select_test_active(root), Some(2))
}
