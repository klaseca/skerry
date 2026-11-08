///|
test "show releases user subscriptions through composition wrappers" {
  for kind in ["column", "stack", "fragment", "interactive", "nested"] {
    let visible = @reactive.signal(true)
    let source = @reactive.signal(0)
    let runs : Array[Int32] = []
    let watched : Array[(Int32, Int32)] = []
    let cleanups = Ref(0)
    let root = @runtime.mount(
      fn() {
        test_composition_wrapper(
          kind,
          @view.show(fn() { visible.get() }, fn() {
            ignore(@reactive.effect(fn() { runs.push(source.get()) }))
            ignore(
              @reactive.watch(fn() { source.get() }, fn(value, previous) {
                watched.push((value, previous))
              }),
            )
            @reactive.on_cleanup(fn() { cleanups.val += 1 })
            @view.empty()
          }),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    source.set(1)
    assert_eq(runs, [0, 1])
    visible.set(false)
    visible.set(false)
    source.set(2)
    assert_eq(runs, [0, 1])
    assert_eq(watched, [(1, 0)])
    assert_eq(cleanups.val, 1)
    visible.set(true)
    source.set(3)
    assert_eq(runs, [0, 1, 2, 3])
    assert_eq(watched, [(1, 0), (3, 2)])
    root.dispose()
    root.dispose()
    source.set(4)
    assert_eq(runs, [0, 1, 2, 3])
    assert_eq(cleanups.val, 2)
  }
}

///|
test "keyed entries retain ownership on updates and reorder" {
  let items = @reactive.signal([(1, "one"), (2, "two")])
  let source = @reactive.signal(0)
  let rendered : Array[Int32] = []
  let cleaned : Array[Int32] = []
  let calls : Array[(Int32, Int32)] = []
  let changes : Array[(Int32, String)] = []
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.stack([
          @view.for_each(fn() { items.get() }, fn(item) { item.0 }, fn(item) {
            let key = item().0
            rendered.push(key)
            @reactive.on_cleanup(fn() { cleaned.push(key) })
            ignore(@reactive.effect(fn() { calls.push((key, source.get())) }))
            ignore(
              @reactive.watch(fn() { item().1 }, fn(value, _) {
                changes.push((key, value))
              }),
            )
            @view.empty()
          }),
        ]),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  items.set([(2, "second"), (1, "first")])
  assert_eq(rendered, [1, 2])
  assert_eq(cleaned, [])
  assert_true(changes.contains((1, "first")))
  assert_true(changes.contains((2, "second")))
  items.set([(3, "three"), (2, "second"), (1, "first")])
  items.set([(1, "FIRST"), (3, "THREE"), (2, "second")])
  assert_eq(rendered, [1, 2, 3])
  assert_eq(cleaned, [])
  assert_true(changes.contains((3, "THREE")))
  calls.clear()
  source.set(1)
  assert_eq(calls.length(), 3)
  assert_true(calls.contains((1, 1)))
  assert_true(calls.contains((2, 1)))
  assert_true(calls.contains((3, 1)))
  items.set([(1, "FIRST"), (3, "THREE")])
  assert_eq(cleaned, [2])
  calls.clear()
  source.set(2)
  assert_eq(calls.length(), 2)
  assert_true(calls.contains((1, 2)))
  assert_true(calls.contains((3, 2)))
  items.set([(2, "again"), (1, "FIRST"), (3, "THREE")])
  assert_eq(rendered, [1, 2, 3, 2])
  assert_eq(cleaned, [2])
  root.dispose()
  assert_eq(cleaned.length(), 4)
  assert_eq(cleaned.filter(key => key == 2).length(), 2)
  calls.clear()
  source.set(3)
  assert_eq(calls, [])
}

///|
test "nested branches finish child cleanup before parent cleanup" {
  let visible = @reactive.signal(true)
  let inner_visible = @reactive.signal(true)
  let source = @reactive.signal(0)
  let child_cleanups = Ref(0)
  let inner_cleanups = Ref(0)
  let outer_cleanups = Ref(0)
  let calls = Ref(0)
  let cleanup_order : Array[(String, Int32)] = []
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @reactive.on_cleanup(fn() {
          cleanup_order.push(("outer", inner_cleanups.val))
          outer_cleanups.val += 1
        })
        @view.show(fn() { inner_visible.get() }, fn() {
          @reactive.on_cleanup(fn() {
            cleanup_order.push(("inner", child_cleanups.val))
            inner_cleanups.val += 1
          })
          @view.for_each(fn() { [1, 2] }, fn(item) { item }, fn(_) {
            @reactive.on_cleanup(fn() { child_cleanups.val += 1 })
            ignore(
              @reactive.effect(fn() {
                ignore(source.get())
                calls.val += 1
              }),
            )
            @view.empty()
          })
        })
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  visible.set(false)
  source.set(1)
  assert_eq(calls.val, 2)
  assert_eq(child_cleanups.val, 2)
  assert_eq(inner_cleanups.val, 1)
  assert_eq(outer_cleanups.val, 1)
  assert_eq(cleanup_order, [("inner", 2), ("outer", 1)])
  root.dispose()
  assert_eq(outer_cleanups.val, 1)
}

///|
test "effects created on later runs inherit the branch lifetime" {
  let visible = @reactive.signal(true)
  let trigger = @reactive.signal(false)
  let source = @reactive.signal(0)
  let calls = Ref(0)
  let cleanups = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        ignore(
          @reactive.effect(fn() {
            if trigger.get() {
              ignore(
                @reactive.effect(fn() {
                  ignore(source.get())
                  calls.val += 1
                  @reactive.on_cleanup(fn() { cleanups.val += 1 })
                }),
              )
            }
          }),
        )
        @view.empty()
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  trigger.set(true)
  assert_eq(calls.val, 1)
  source.set(1)
  assert_eq(calls.val, 2)
  assert_eq(cleanups.val, 1)
  visible.set(false)
  source.set(2)
  assert_eq(calls.val, 2)
  assert_eq(cleanups.val, 2)
}

///|
test "duplicate keys keep separate subscription lifetimes" {
  let items = @reactive.signal(["first", "second"])
  let source = @reactive.signal(0)
  let calls : Array[String] = []
  let cleaned : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.for_each(fn() { items.get() }, fn(_) { 0 }, fn(item) {
        let initial = item()
        ignore(
          @reactive.effect(fn() {
            ignore(source.get())
            calls.push(initial)
          }),
        )
        @reactive.on_cleanup(fn() { cleaned.push(initial) })
        @view.empty()
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  items.set(["FIRST", "SECOND"])
  assert_eq(cleaned, [])
  items.set(["retained"])
  assert_eq(cleaned, ["second"])
  calls.clear()
  source.set(1)
  assert_eq(calls, ["first"])
  items.set(["retained", "replacement"])
  assert_eq(cleaned, ["second"])
  root.dispose()
  assert_eq(cleaned.length(), 3)
  assert_true(cleaned.contains("first"))
  assert_true(cleaned.contains("replacement"))
}

///|
test "branch cleanup can dispose its root during removal" {
  for kind in ["show", "for_each"] {
    let visible = @reactive.signal(true)
    let items = @reactive.signal([1, 2])
    let source = @reactive.signal(0)
    let calls = Ref(0)
    let cleaned : Array[Int32] = []
    let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
    fn content(key : Int32) -> @view.View {
      ignore(
        @reactive.effect(fn() {
          ignore(source.get())
          calls.val += 1
        }),
      )
      @reactive.on_cleanup(fn() {
        cleaned.push(key)
        if root_ref.val is Some(root) {
          root.dispose()
        }
      })
      @view.empty()
    }
    let root = @runtime.mount(
      fn() {
        if kind == "show" {
          @view.show(fn() { visible.get() }, fn() { content(1) })
        } else {
          @view.for_each(fn() { items.get() }, fn(item) { item }, fn(item) {
            content(item())
          })
        }
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    root_ref.val = Some(root)
    if kind == "show" {
      visible.set(false)
      assert_eq(cleaned, [1])
    } else {
      items.set([3])
      assert_eq(cleaned.length(), 3)
      assert_eq(cleaned.filter(key => key == 1).length(), 1)
      assert_eq(cleaned.filter(key => key == 2).length(), 1)
      assert_eq(cleaned.filter(key => key == 3).length(), 1)
    }
    let before = calls.val
    source.set(1)
    items.set([4])
    visible.set(true)
    root.dispose()
    assert_eq(calls.val, before)
    assert_eq(cleaned.length(), if kind == "show" { 1 } else { 3 })
  }
}
