///|
test "UI actions are deferred FIFO, cancellable and batched before a frame" {
  let value = @reactive.signal(0)
  let observed : Array[Int32] = []
  let stop = @reactive.effect(fn() { observed.push(value.get()) })
  defer stop()
  let root = @runtime.mount(
    fn() { @view.text_of(value) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  let order : Array[Int32] = []
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  ignore(
    root.post(fn() {
      order.push(1)
      value.set(1)
    }),
  )
  let cancel = root.post(fn() { order.push(99) })
  cancel()
  cancel()
  ignore(
    root.post(fn() {
      order.push(2)
      value.set(2)
    }),
  )
  assert_eq(order, [])
  assert_eq(wakeups.val, 1)
  assert_true(root.has_pending_actions())
  root.drain_actions()
  assert_eq(order, [1, 2])
  assert_eq(observed, [0, 2])
  assert_false(root.has_pending_actions())
  root.paint(renderer, size~)
  assert_eq(renderer.text.val, Some("2"))
  assert_eq(root.frame_stats().paint_count, 2)
  assert_eq(root.frame_stats().layout_count, 2)
}

///|
test "nested posts wait for the next pass and cannot reenter the drain" {
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let order : Array[Int32] = []
  ignore(
    root.post(fn() {
      order.push(1)
      ignore(root.post(fn() { order.push(3) }))
      root.drain_actions()
    }),
  )
  ignore(root.post(fn() { order.push(2) }))
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  assert_eq(wakeups.val, 1)
  root.drain_actions()
  assert_eq(order, [1, 2])
  assert_true(root.has_pending_actions())
  assert_eq(wakeups.val, 2)
  root.drain_actions()
  assert_eq(order, [1, 2, 3])
  assert_false(root.has_pending_actions())
}

///|
test "root disposal cancels pending, nested and subsequent UI actions" {
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  let calls = Ref(0)
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  ignore(
    root.post(fn() {
      ignore(root.post(fn() { calls.val += 100 }))
      root.dispose()
    }),
  )
  let cancel = root.post(fn() { calls.val += 1 })
  root.drain_actions()
  ignore(root.post(fn() { calls.val += 10 }))
  root.drain_actions()
  cancel()
  assert_eq(calls.val, 0)
  assert_eq(wakeups.val, 3)
  assert_false(root.has_pending_actions())
}

///|
test "posted actions follow the posting component lifetime" {
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let scope = @reactive.Scope::root()
  let calls = Ref(0)
  scope.run(fn() { ignore(root.post(fn() { calls.val += 1 })) })
  scope.dispose()
  root.drain_actions()
  assert_eq(calls.val, 0)
  scope.run(fn() { ignore(root.post(fn() { calls.val += 1 })) })
  assert_false(root.has_pending_actions())
}

///|
test "posted reads do not subscribe the caller and created effects belong to the root" {
  let unrelated = @reactive.signal(0)
  let trigger = @reactive.signal(0)
  let effect_calls = Ref(0)
  let drain_calls = Ref(0)
  let cleanups = Ref(0)
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  ignore(
    root.post(fn() {
      ignore(unrelated.get())
      @reactive.on_cleanup(fn() { cleanups.val += 1 })
      ignore(
        @reactive.effect(fn() {
          ignore(unrelated.get())
          effect_calls.val += 1
        }),
      )
    }),
  )
  let stop = @reactive.effect(fn() {
    ignore(trigger.get())
    drain_calls.val += 1
    root.drain_actions()
  })
  defer stop()
  unrelated.set(1)
  assert_eq(drain_calls.val, 1)
  assert_eq(effect_calls.val, 2)
  root.dispose()
  unrelated.set(2)
  assert_eq(effect_calls.val, 2)
  assert_eq(cleanups.val, 1)
}

///|
test "actions posted during paint stay deferred until the next action pass" {
  let value = @reactive.signal("first")
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if first.val {
              first.val = false
              let root = root_ref.val.unwrap()
              ignore(root.post(fn() { value.set("second") }))
              root.drain_actions()
            }
          }),
        ),
        @view.text_of(value),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  assert_eq(value.get(), "first")
  assert_true(root.has_pending_actions())
  root.drain_actions()
  root.paint(renderer, size~)
  assert_eq(renderer.text.val, Some("second"))
  assert_false(root.has_pending_actions())
}

///|
test "painting requested from an action waits until the batch completes" {
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  ignore(root.post(fn() { root.paint(renderer, size~) }))
  root.drain_actions()
  assert_eq(root.frame_stats().paint_count, 1)
  assert_true(root.needs_frame())
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().paint_count, 2)
}

///|
test "App on_mount posts work under root ownership" {
  let cleanups = Ref(0)
  let value = @reactive.signal("first")
  let app = @runtime.App(content=fn() { @view.text_of(value) }, on_mount=fn(
    root,
  ) {
    @reactive.on_cleanup(fn() { cleanups.val += 1 })
    ignore(root.post(fn() { value.set("ready") }))
  })
  let root = app.mount(text_layout_system=test_text_layout_system())
  assert_eq(value.get(), "first")
  root.drain_actions()
  assert_eq(value.get(), "ready")
  root.dispose()
  assert_eq(cleanups.val, 1)
}
