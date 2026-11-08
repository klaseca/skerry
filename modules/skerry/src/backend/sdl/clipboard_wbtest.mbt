///|
suberror TestClipboardError {
  TestClipboardWriteFailed
}

///|
test "SDL Cut commits clipboard and deletion only after an accepted proposal" {
  for
    outcome in [
      "accept", "cancel", "disable", "remove", "dispose", "write error",
    ] {
    let value = @reactive.signal("abcd")
    let blocked = @reactive.signal(false)
    let visible = @reactive.signal(true)
    let slot : Ref[@runtime.UiRoot?] = Ref(None)
    let proposals = Ref(0)
    let writes = Ref(0)
    let contents = Ref("old clipboard")
    let clipboard : Clipboard = {
      read: fn() { Some(contents.val) },
      write: fn(text) raise {
        writes.val += 1
        if outcome == "write error" {
          raise TestClipboardWriteFailed
        }
        // Commit the host write before the default deletion.
        assert_eq(value.peek(), "abcd")
        contents.val = text
      },
    }
    let root = input_test_root(fn() {
      @view.show(fn() { visible.get() }, fn() {
        @controls.text_input(value~, disabled=blocked, on_change=fn(event) {
          proposals.val += 1
          match outcome {
            "cancel" => event.prevent_default()
            "disable" => blocked.set(true)
            "remove" => visible.set(false)
            "dispose" => slot.val.unwrap().dispose()
            _ => ()
          }
        })
      })
    })
    defer root.dispose()
    slot.val = Some(root)
    assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
    assert_true(
      root.key_down(
        @foundation.KeyEvent(key=KeyA, modifiers=KeyModifiers(control=true)),
      ),
    )
    let event = @foundation.KeyEvent(
      key=KeyX,
      modifiers=KeyModifiers(control=true),
    )
    let failed = try {
      let handled = handle_clipboard_shortcut(root, event, clipboard~)
      assert_eq(handled, outcome == "accept")
      false
    } catch {
      TestClipboardWriteFailed => true
      error => raise error
    }
    assert_eq(failed, outcome == "write error")
    assert_eq(proposals.val, 1)
    match outcome {
      "accept" => {
        assert_eq(writes.val, 1)
        assert_eq(contents.val, "abcd")
        assert_eq(value.get(), "")
        assert_eq(root.copy_text(), None)
      }
      "write error" | "cancel" => {
        assert_eq(writes.val, if outcome == "write error" { 1 } else { 0 })
        assert_eq(contents.val, "old clipboard")
        assert_eq(value.get(), "abcd")
        assert_eq(root.copy_text(), Some("abcd"))
      }
      _ => {
        assert_eq(writes.val, 0)
        assert_eq(contents.val, "old clipboard")
        assert_eq(value.get(), "abcd")
      }
    }
  }
}

///|
test "clipboard adapter also handles copy and paste" {
  let value = @reactive.signal("source")
  let contents = Ref("old")
  let reads = Ref(0)
  let writes = Ref(0)
  let clipboard : Clipboard = {
    read: fn() {
      reads.val += 1
      Some(contents.val)
    },
    write: fn(text) {
      writes.val += 1
      contents.val = text
    },
  }
  let root = input_test_root(fn() { @controls.text_input(value~) })
  defer root.dispose()
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(
    root.key_down(
      @foundation.KeyEvent(key=KeyA, modifiers=KeyModifiers(control=true)),
    ),
  )
  assert_true(
    handle_clipboard_shortcut(
      root,
      @foundation.KeyEvent(key=KeyC, modifiers=KeyModifiers(control=true)),
      clipboard~,
    ),
  )
  assert_eq(contents.val, "source")
  assert_eq(value.get(), "source")
  contents.val = "replacement"
  assert_true(
    handle_clipboard_shortcut(
      root,
      @foundation.KeyEvent(key=KeyV, modifiers=KeyModifiers(control=true)),
      clipboard~,
    ),
  )
  assert_eq(value.get(), "replacement")
  assert_eq((reads.val, writes.val), (1, 1))
}

///|
test "nested and later cuts do not inherit a different operation's writer" {
  let inner_value = @reactive.signal("inner")
  let inner = input_test_root(fn() { @controls.text_input(value=inner_value) })
  defer inner.dispose()
  assert_true(inner.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(
    inner.key_down(
      @foundation.KeyEvent(key=KeyA, modifiers=KeyModifiers(control=true)),
    ),
  )
  let nested = Ref(false)
  let outer_value = @reactive.signal("outer")
  let outer = input_test_root(fn() {
    @controls.text_input(value=outer_value, on_change=fn(_) {
      if !nested.val {
        nested.val = true
        ignore(inner.cut_text())
      }
    })
  })
  defer outer.dispose()
  assert_true(outer.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(
    outer.key_down(
      @foundation.KeyEvent(key=KeyA, modifiers=KeyModifiers(control=true)),
    ),
  )
  let written : Array[String] = []
  assert_eq(
    outer.cut_text(write=fn(text) {
      written.push(text)
      true
    }),
    Some("outer"),
  )
  assert_eq(written, ["outer"])
  assert_eq(inner_value.get(), "")
  assert_true(inner.text_input("later"))
  assert_true(
    inner.key_down(
      @foundation.KeyEvent(key=KeyA, modifiers=KeyModifiers(control=true)),
    ),
  )
  assert_eq(inner.cut_text(), Some("later"))
  assert_eq(written, ["outer"])
}
