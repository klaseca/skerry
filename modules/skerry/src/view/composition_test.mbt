///|
test "focused keyed child keeps text input after reorder" {
  let order = @reactive.signal(["first", "second"])
  let first_value = @reactive.signal("")
  let second_value = @reactive.signal("")
  let size = @foundation.Size(width=180.0, height=90.0)
  let root = @runtime.mount(
    fn() {
      @view.for_each(fn() { order.get() }, fn(item) { item }, fn(item) {
        let value = if item() == "first" { first_value } else { second_value }
        @controls.text_input(
          value~,
          style=@controls.TextInputStyle().surface(
            @style.BoxStyle().width(140.0).height(32.0),
          ),
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  root.paint(TextRunRecorder::{ text: Ref(None), }, size~)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  order.set(["second", "first"])
  assert_true(root.text_input("x"))
  inspect(first_value.get(), content="x")
  inspect(second_value.get(), content="")
  root.dispose()
}

///|
fn test_composition_wrapper(kind : String, child : @view.View) -> @view.View {
  match kind {
    "column" => @view.column([child])
    "stack" => @view.stack([child])
    "fragment" => @view.fragment([child])
    "interactive" => @view.interactive(child)
    _ => @view.interactive(@view.stack([@view.interactive(child)]))
  }
}

///|
test "interactive preserves clipboard and observers through nested wrappers" {
  for depth in [1, 2] {
    let value = @reactive.signal("abc")
    let keys = Ref(0)
    let texts = Ref(0)
    let pointers = Ref(0)
    let root = @runtime.mount(
      fn() {
        let mut input = @controls.text_input(value~)
        for _ in 0..<depth {
          input = @view.interactive(
            input,
            on_key_down=fn(_) { keys.val += 1 },
            on_text_input=fn(_) { texts.val += 1 },
            on_pointer_down=fn(_) { pointers.val += 1 },
            on_pointer_move=fn(_) { pointers.val += 1 },
            on_pointer_up=fn(_) { pointers.val += 1 },
          )
        }
        input
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.key_down(test_control_key_event(KeyA)))
    assert_eq(keys.val, depth)
    assert_eq(root.copy_text(), Some("abc"))
    assert_eq(root.cut_text(), Some("abc"))
    assert_eq(value.get(), "")
    assert_true(root.paste_text("xyz"))
    assert_eq(value.get(), "xyz")
    assert_true(root.text_input("!"))
    assert_eq(value.get(), "xyz!")
    assert_eq(texts.val, depth)
    let size = @foundation.Size(width=180.0, height=50.0)
    assert_true(root.pointer_down(size~, point=Point(x=10.0, y=18.0)))
    assert_true(root.pointer_move(size~, point=Point(x=20.0, y=18.0)))
    assert_true(root.pointer_up(size~, point=Point(x=20.0, y=18.0)))
    assert_eq(pointers.val, depth * 3)
  }
}

///|
test "show updates wrapped content and disposes hidden subscriptions" {
  for kind in ["column", "stack", "fragment", "interactive", "nested"] {
    let visible = @reactive.signal(false)
    let label = @reactive.signal("shown")
    let clicks = Ref(0)
    let builds = Ref(0)
    let root = @runtime.mount(
      fn() {
        builds.val += 1
        test_composition_wrapper(
          kind,
          @view.show(fn() { visible.get() }, fn() {
            @view.interactive(
              @view.text_of(
                label,
                style=@view.TextStyle().frame(
                  @style.BoxStyle().width(80.0).height(24.0),
                ),
              ),
              on_click=fn() { clicks.val += 1 },
            )
          }),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=180.0, height=80.0)
    let hidden_focus_count = root.view().focusable_paths().length()
    let hidden = TextRunRecorder::{ text: Ref(None), }
    root.paint(hidden, size~)
    assert_eq(hidden.text.val, None)
    visible.set(true)
    assert_eq(root.dirty(), NeedsLayout)
    let shown = TextRunRecorder::{ text: Ref(None), }
    root.paint(shown, size~)
    assert_eq(shown.text.val, Some("shown"))
    assert_eq(root.view().focusable_paths().length(), hidden_focus_count + 1)
    assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(clicks.val, 1)
    label.set("updated")
    assert_eq(root.dirty(), NeedsLayout)
    let updated = TextRunRecorder::{ text: Ref(None), }
    root.paint(updated, size~)
    assert_eq(updated.text.val, Some("updated"))
    visible.set(false)
    let hidden_again = TextRunRecorder::{ text: Ref(None), }
    root.paint(hidden_again, size~)
    assert_eq(hidden_again.text.val, None)
    assert_eq(root.view().focusable_paths().length(), hidden_focus_count)
    label.set("detached")
    assert_eq(root.dirty(), Clean)
    assert_eq(builds.val, 1)
  }
}

///|
test "for_each updates wrapped content and preserves identity on reorder" {
  for kind in ["column", "stack", "fragment", "interactive", "nested"] {
    let items = @reactive.signal(["a"])
    let clicked = Ref("")
    let renders = Ref(0)
    let builds = Ref(0)
    let root = @runtime.mount(
      fn() {
        builds.val += 1
        test_composition_wrapper(
          kind,
          @view.for_each(fn() { items.get() }, fn(item) { item }, fn(item) {
            renders.val += 1
            @controls.button(
              item(),
              on_click=fn() { clicked.val = item() },
              style=@controls.ButtonStyle().surface(
                @style.BoxStyle().width(80.0).height(24.0),
              ),
            )
          }),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=180.0, height=100.0)
    let base_focus_count = root.view().focusable_paths().length() - 1
    root.paint(TextRunRecorder::{ text: Ref(None), }, size~)
    items.set(["b", "c"])
    assert_eq(root.dirty(), NeedsLayout)
    let updated = TextRunRecorder::{ text: Ref(None), }
    root.paint(updated, size~)
    assert_eq(updated.text.val, Some("c"))
    assert_eq(root.view().focusable_paths().length(), base_focus_count + 2)
    assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(clicked.val, "b")
    let paths = root.view().focusable_paths()
    let first_id = root.view().node_id_at_path(paths[base_focus_count])
    let second_id = root.view().node_id_at_path(paths[base_focus_count + 1])
    items.set(["c", "b"])
    let reordered = TextRunRecorder::{ text: Ref(None), }
    root.paint(reordered, size~)
    assert_eq(reordered.text.val, Some("b"))
    let reordered_paths = root.view().focusable_paths()
    assert_eq(
      root.view().node_id_at_path(reordered_paths[base_focus_count]),
      second_id,
    )
    assert_eq(
      root.view().node_id_at_path(reordered_paths[base_focus_count + 1]),
      first_id,
    )
    assert_eq(renders.val, 3)
    assert_true(root.key_down(test_key_event(KeyEnter)))
    assert_eq(clicked.val, "b")
    items.set([])
    assert_eq(root.view().focusable_paths().length(), base_focus_count)
    assert_eq(builds.val, 1)
  }
}

///|
test "for_each updates keyed values and callbacks without rebuilding views" {
  for kind in ["column", "stack", "fragment", "interactive", "nested"] {
    let items = @reactive.signal([(1, "old")])
    let clicked = Ref("")
    let renders = Ref(0)
    let root = @runtime.mount(
      fn() {
        test_composition_wrapper(
          kind,
          @view.for_each(fn() { items.get() }, fn(item) { item.0 }, fn(item) {
            renders.val += 1
            @view.interactive(
              @view.text(
                @reactive.bind(fn() { item().1 }),
                style=@view.TextStyle().frame(
                  @style.BoxStyle().width(80.0).height(24.0),
                ),
              ),
              on_click=fn() { clicked.val = item().1 },
            )
          }),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    let size = @foundation.Size(width=180.0, height=100.0)
    root.paint(TextRunRecorder::{ text: Ref(None), }, size~)
    let paths = root.view().focusable_paths()
    let child_id = root.view().node_id_at_path(paths[paths.length() - 1])
    items.set([(1, "new")])
    let updated = TextRunRecorder::{ text: Ref(None), }
    root.paint(updated, size~)
    assert_eq(updated.text.val, Some("new"))
    assert_eq(renders.val, 1)
    let updated_paths = root.view().focusable_paths()
    assert_eq(
      root.view().node_id_at_path(updated_paths[updated_paths.length() - 1]),
      child_id,
    )
    assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(clicked.val, "new")
    items.set([])
    root.paint(TextRunRecorder::{ text: Ref(None), }, size~)
    root.dispose()
    items.set([(1, "detached")])
    assert_eq(root.dirty(), Clean)
    assert_eq(renders.val, 1)
  }
}

///|
test "for_each preserves focus caret and selection on keyed updates" {
  for kind in ["column", "stack", "fragment", "interactive", "nested"] {
    let items = @reactive.signal([(1, "first"), (2, "second")])
    let edited = Ref("")
    let submitted = Ref((0, "", ""))
    let renders = Ref(0)
    let root = @runtime.mount(
      fn() {
        test_composition_wrapper(
          kind,
          @view.for_each(fn() { items.get() }, fn(item) { item.0 }, fn(item) {
            renders.val += 1
            @controls.text_input(
              style=@controls.TextInputStyle().surface(
                @style.BoxStyle().width(140.0).height(32.0),
              ),
              on_change=fn(value) { edited.val = value.value },
              on_submit=fn(value) {
                submitted.val = (item().0, item().1, value)
              },
            )
          }),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=180.0, height=150.0)
    assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
    assert_true(root.text_input("abcd"))
    assert_true(root.key_down(test_key_event(KeyArrowLeft)))
    items.set([(2, "second updated"), (1, "first updated")])
    root.paint(TextRunRecorder::{ text: Ref(None), }, size~)
    assert_true(root.text_input("X"))
    assert_eq(edited.val, "abcXd")
    assert_true(root.key_down(test_key_event(KeyEnter)))
    assert_eq(submitted.val, (1, "first updated", "abcXd"))
    assert_eq(renders.val, 2)
    assert_true(root.key_down(test_control_key_event(KeyA)))
    items.set([(1, "latest"), (2, "second updated")])
    assert_true(root.text_input("replacement"))
    assert_eq(edited.val, "replacement")
    assert_true(root.key_down(test_key_event(KeyEnter)))
    assert_eq(submitted.val, (1, "latest", "replacement"))
    assert_eq(renders.val, 2)
  }
}

///|
test "for_each matches duplicate keys by occurrence" {
  let items = @reactive.signal([(1, "first"), (1, "second")])
  let clicked = Ref("")
  let renders = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.for_each(fn() { items.get() }, fn(item) { item.0 }, fn(item) {
        renders.val += 1
        @view.interactive(
          @view.text(
            @reactive.bind(fn() { item().1 }),
            style=@view.TextStyle().frame(
              @style.BoxStyle().width(80.0).height(24.0),
            ),
          ),
          on_click=fn() { clicked.val = item().1 },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let paths = root.view().focusable_paths()
  let first_id = root.view().node_id_at_path(paths[0])
  let second_id = root.view().node_id_at_path(paths[1])
  assert_true(first_id != second_id)
  items.set([(1, "second updated"), (1, "first updated")])
  let updated_paths = root.view().focusable_paths()
  assert_eq(root.view().node_id_at_path(updated_paths[0]), first_id)
  assert_eq(root.view().node_id_at_path(updated_paths[1]), second_id)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(clicked.val, "second updated")
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(clicked.val, "first updated")
  items.set([(1, "remaining")])
  assert_eq(
    root.view().node_id_at_path(root.view().focusable_paths()[0]),
    first_id,
  )
  assert_eq(renders.val, 2)
}

///|
test "for_each getter updates nested show content" {
  let items = @reactive.signal([(1, "hidden", false)])
  let renders = Ref(0)
  let clicks = Ref("")
  let root = @runtime.mount(
    fn() {
      @view.stack([
        @view.for_each(fn() { items.get() }, fn(item) { item.0 }, fn(item) {
          renders.val += 1
          @view.show(fn() { item().2 }, fn() {
            @view.interactive(
              @view.text(
                @reactive.bind(fn() { item().1 }),
                style=@view.TextStyle().frame(
                  @style.BoxStyle().width(80.0).height(24.0),
                ),
              ),
              on_click=fn() { clicks.val = item().1 },
            )
          })
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=180.0, height=100.0)
  root.paint(TextRunRecorder::{ text: Ref(None), }, size~)
  items.set([(1, "shown", true)])
  let shown = TextRunRecorder::{ text: Ref(None), }
  root.paint(shown, size~)
  assert_eq(shown.text.val, Some("shown"))
  assert_eq(root.view().focusable_paths().length(), 1)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(clicks.val, "shown")
  @reactive.batch(fn() {
    items.set([(2, "intermediate", true)])
    items.set([(1, "hidden again", false)])
  })
  let hidden = TextRunRecorder::{ text: Ref(None), }
  root.paint(hidden, size~)
  assert_eq(hidden.text.val, None)
  assert_eq(root.view().focusable_paths().length(), 0)
  assert_eq(renders.val, 1)
}

///|
test "tree changes refresh layout after hit testing before paint" {
  for kind in ["column", "stack", "fragment", "interactive", "nested"] {
    let visible = @reactive.signal(false)
    let root = @runtime.mount(
      fn() {
        test_composition_wrapper(
          kind,
          @view.show(fn() { visible.get() }, fn() {
            @view.text(
              "shown",
              style=@view.TextStyle().frame(
                @style.BoxStyle().width(80.0).height(24.0),
              ),
            )
          }),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=180.0, height=100.0)
    ignore(root.click_at(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(root.dirty(), NeedsLayout)
    visible.set(true)
    let shown = TextRunRecorder::{ text: Ref(None), }
    root.paint(shown, size~)
    assert_eq(shown.text.val, Some("shown"))
    visible.set(false)
    ignore(root.click_at(size~, point=Point(x=10.0, y=10.0)))
    visible.set(true)
    let shown_again = TextRunRecorder::{ text: Ref(None), }
    root.paint(shown_again, size~)
    assert_eq(shown_again.text.val, Some("shown"))
  }
}
