///|
fn scheduled_root(
  now : Ref[Double],
  content~ : () -> @view.View = @view.empty,
) -> @runtime.UiRoot {
  @runtime.mount(content, text_layout_system=test_text_layout_system(), clock=fn() {
    now.val
  })
}

///|
test "timers respect deadlines, FIFO ties and one reactive batch" {
  let now = Ref(0.0)
  let value = @reactive.signal(0)
  let observed : Array[Int32] = []
  let stop = @reactive.effect(fn() { observed.push(value.get()) })
  defer stop()
  let root = scheduled_root(now, content=fn() { @view.text_of(value) })
  defer root.dispose()
  root.paint(
    TextRunRecorder::{ text: Ref(None), },
    size=@foundation.Size(width=100.0, height=50.0),
  )
  let order : Array[Int32] = []
  ignore(
    root.post_delayed(30, fn() {
      order.push(3)
      value.set(3)
    }),
  )
  ignore(
    root.post_delayed(10, fn() {
      order.push(1)
      value.set(1)
    }),
  )
  ignore(
    root.post_delayed(10, fn() {
      order.push(2)
      value.set(2)
    }),
  )
  ignore(root.post(fn() { order.push(0) }))
  root.drain_actions()
  assert_eq(order, [0])
  assert_false(root.has_pending_actions())
  assert_eq(root.next_action_delay(), Some(10))
  now.val = 9.4
  assert_eq(root.next_action_delay(), Some(1))
  root.drain_actions()
  assert_eq(order, [0])
  now.val = 10.0
  assert_true(root.has_pending_actions())
  root.drain_actions()
  assert_eq(order, [0, 1, 2])
  assert_eq(observed, [0, 2])
  assert_eq(root.next_action_delay(), Some(20))
  now.val = 30.0
  root.drain_actions()
  assert_eq(order, [0, 1, 2, 3])
  assert_eq(observed, [0, 2, 3])
  assert_eq(root.next_action_delay(), None)
  assert_eq(root.frame_stats().paint_count, 1)
}

///|
test "future timers notify an attached host and cancellation changes its deadline" {
  let now = Ref(0.0)
  let root = scheduled_root(now)
  defer root.dispose()
  let calls = Ref(0)
  let cancel = root.post_delayed(100, fn() { calls.val += 10 })
  ignore(root.post_delayed(200, fn() { calls.val += 1 }))
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  assert_eq(wakeups.val, 1)
  assert_eq(root.next_action_delay(), Some(100))
  let earlier = root.post_delayed(50, fn() { calls.val += 100 })
  assert_eq(wakeups.val, 2)
  earlier()
  earlier()
  assert_eq(wakeups.val, 3)
  assert_eq(root.next_action_delay(), Some(100))
  cancel()
  assert_eq(root.next_action_delay(), Some(200))
  now.val = 200.0
  root.drain_actions()
  assert_eq(calls.val, 1)
  assert_eq(root.next_action_delay(), None)
}

///|
test "nonpositive delays remain deferred posts in FIFO order" {
  let now = Ref(0.0)
  let root = scheduled_root(now)
  defer root.dispose()
  let order : Array[Int32] = []
  ignore(root.post_delayed(-1, fn() { order.push(1) }))
  ignore(root.post(fn() { order.push(2) }))
  ignore(root.post_delayed(0, fn() { order.push(3) }))
  assert_eq(order, [])
  assert_eq(root.next_action_delay(), Some(0))
  root.drain_actions()
  assert_eq(order, [1, 2, 3])
}

///|
test "timers created during a drain wait for the next pass even if already due" {
  let now = Ref(0.0)
  let root = scheduled_root(now)
  defer root.dispose()
  let order : Array[Int32] = []
  ignore(
    root.post_delayed(1, fn() {
      order.push(1)
      ignore(root.post_delayed(1, fn() { order.push(3) }))
      now.val = 2.0
      root.drain_actions()
    }),
  )
  ignore(root.post_delayed(1, fn() { order.push(2) }))
  now.val = 1.0
  root.drain_actions()
  assert_eq(order, [1, 2])
  assert_eq(root.next_action_delay(), Some(0))
  root.drain_actions()
  assert_eq(order, [1, 2, 3])
}

///|
test "disposed component and root lifetimes cancel timers and present callbacks" {
  let now = Ref(0.0)
  let root = scheduled_root(now)
  let scope = @reactive.Scope::root()
  let calls = Ref(0)
  scope.run(fn() {
    ignore(root.post_delayed(10, fn() { calls.val += 1 }))
    ignore(root.after_present(fn() { calls.val += 10 }))
  })
  scope.dispose()
  assert_eq(root.next_action_delay(), None)
  now.val = 10.0
  root.drain_actions()
  root.record_present(1)
  assert_eq(calls.val, 0)
  scope.run(fn() {
    ignore(root.post_delayed(10, fn() { calls.val += 1 }))
    ignore(root.after_present(fn() { calls.val += 10 }))
  })
  assert_eq(root.next_action_delay(), None)
  let cancel_timer = root.post_delayed(1, fn() { calls.val += 100 })
  let cancel_present = root.after_present(fn() { calls.val += 1000 })
  root.dispose()
  cancel_timer()
  cancel_present()
  now.val = 20.0
  root.drain_actions()
  root.record_present(2)
  ignore(root.post_delayed(1, fn() { calls.val += 100 }))
  ignore(root.after_present(fn() { calls.val += 1000 }))
  assert_eq(calls.val, 0)
  assert_eq(root.next_action_delay(), None)
}

///|
test "timer clocks and callbacks do not subscribe the caller and preserve posting ownership" {
  let time = @reactive.signal(0.0)
  let trigger = @reactive.signal(0)
  let unrelated = @reactive.signal(0)
  let root = @runtime.mount(
    @view.empty,
    text_layout_system=test_text_layout_system(),
    clock=fn() { time.get() },
  )
  defer root.dispose()
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let effects = Ref(0)
  let cleanups = Ref(0)
  let pumps = Ref(0)
  scope.run(fn() {
    ignore(
      root.post_delayed(1, fn() {
        ignore(unrelated.get())
        @reactive.on_cleanup(fn() { cleanups.val += 1 })
        ignore(
          @reactive.effect(fn() {
            ignore(unrelated.get())
            effects.val += 1
          }),
        )
      }),
    )
  })
  let stop = @reactive.effect(fn() {
    ignore(trigger.get())
    pumps.val += 1
    ignore(root.next_action_delay())
    root.drain_actions()
  })
  defer stop()
  time.set(1.0)
  assert_eq(pumps.val, 1)
  trigger.set(1)
  assert_eq(pumps.val, 2)
  assert_eq(effects.val, 1)
  unrelated.set(1)
  assert_eq(pumps.val, 2)
  assert_eq(effects.val, 2)
  scope.dispose()
  assert_eq(cleanups.val, 1)
  unrelated.set(2)
  assert_eq(effects.val, 2)
}

///|
test "timer deadlines extend beyond the signed millisecond range" {
  let now = Ref(3_000_000_000.0)
  let root = scheduled_root(now)
  defer root.dispose()
  let calls = Ref(0)
  ignore(root.post_delayed(100, fn() { calls.val += 1 }))
  assert_eq(root.next_action_delay(), Some(100))
  now.val += 100.0
  root.drain_actions()
  assert_eq(calls.val, 1)
}

///|
test "present callbacks request a frame and run once after notification in a batch" {
  let now = Ref(0.0)
  let value = @reactive.signal(0)
  let observed : Array[Int32] = []
  let stop = @reactive.effect(fn() { observed.push(value.get()) })
  defer stop()
  let root = scheduled_root(now, content=fn() { @view.text_of(value) })
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=100.0, height=50.0)
  root.paint(renderer, size~)
  root.record_present(root.paint_revision())
  let order : Array[Int32] = []
  let observer = root.observe_frames(fn(event) {
    if event is @runtime.Presented(_) {
      order.push(0)
    }
  })
  defer observer()
  ignore(
    root.after_present(fn() {
      order.push(1)
      value.set(1)
    }),
  )
  let cancel = root.after_present(fn() { order.push(99) })
  cancel()
  cancel()
  ignore(
    root.after_present(fn() {
      order.push(2)
      value.set(2)
    }),
  )
  assert_true(root.needs_frame())
  root.drain_actions()
  root.paint(renderer, size~)
  assert_eq(order, [])
  assert_eq(renderer.text.val, Some("0"))
  root.record_present(root.paint_revision())
  assert_eq(order, [0, 1, 2])
  assert_eq(observed, [0, 2])
  assert_true(root.needs_frame())
  root.paint(renderer, size~)
  root.record_present(root.paint_revision())
  assert_eq(order, [0, 1, 2, 0])
  assert_eq(renderer.text.val, Some("2"))
  assert_false(root.needs_frame())
}

///|
test "nested present callbacks and posts cannot reenter present, paint or drain" {
  let now = Ref(0.0)
  let root = scheduled_root(now)
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=100.0, height=50.0)
  let order : Array[Int32] = []
  ignore(
    root.after_present(fn() {
      order.push(1)
      ignore(root.after_present(fn() { order.push(3) }))
      ignore(root.post(fn() { order.push(2) }))
      root.record_present(1)
      root.paint(renderer, size~)
      root.drain_actions()
    }),
  )
  root.paint(renderer, size~)
  root.record_present(root.paint_revision())
  assert_eq(order, [1])
  assert_eq(root.frame_stats().paint_count, 1)
  assert_eq(root.frame_stats().present_count, 1)
  root.drain_actions()
  assert_eq(order, [1, 2])
  root.paint(renderer, size~)
  root.record_present(root.paint_revision())
  assert_eq(order, [1, 2, 3])
}

///|
test "a presented observer schedules callbacks for the following present" {
  let now = Ref(0.0)
  let root = scheduled_root(now)
  defer root.dispose()
  let calls = Ref(0)
  let first = Ref(true)
  let stop = root.observe_frames(fn(event) {
    if event is @runtime.Presented(_) && first.val {
      first.val = false
      ignore(root.after_present(fn() { calls.val += 1 }))
    }
  })
  defer stop()
  root.record_present(1)
  assert_eq(calls.val, 0)
  assert_true(root.needs_frame())
  root.record_present(2)
  assert_eq(calls.val, 1)
}

///|
test "disposal in a present callback cancels the remaining snapshot" {
  let now = Ref(0.0)
  let root = scheduled_root(now)
  let calls = Ref(0)
  ignore(root.after_present(fn() { root.dispose() }))
  ignore(root.after_present(fn() { calls.val += 1 }))
  root.record_present(1)
  assert_true(root.is_disposed())
  assert_eq(calls.val, 0)
}
