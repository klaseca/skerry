///|
test "effect cleanup is untracked and manual disposal is idempotent" {
  let source = @reactive.signal(0)
  let unrelated = @reactive.signal(0)
  let runs : Array[Int32] = []
  let cleanups = Ref(0)
  let stop = @reactive.effect(fn() {
    runs.push(source.get())
    @reactive.on_cleanup(fn() {
      ignore(unrelated.get())
      cleanups.val += 1
    })
  })
  defer stop()
  source.set(1)
  assert_eq(runs, [0, 1])
  assert_eq(cleanups.val, 1)
  unrelated.set(1)
  assert_eq(runs, [0, 1])
  assert_eq(cleanups.val, 1)
  stop()
  stop()
  source.set(2)
  assert_eq(runs, [0, 1])
  assert_eq(cleanups.val, 2)
}

///|
test "manual effect disposal stays stopped when cleanup updates its source" {
  let source = @reactive.signal(0)
  let runs = Ref(0)
  let cleanups = Ref(0)
  let stop = @reactive.effect(fn() {
    ignore(source.get())
    runs.val += 1
    @reactive.on_cleanup(fn() {
      cleanups.val += 1
      source.update(value => value + 1)
    })
  })
  defer stop()
  stop()
  assert_eq(source.get(), 1)
  assert_eq(cleanups.val, 1)
  assert_eq(runs.val, 1)
}

///|
test "an outside effect keeps its context when a UI scope triggers its update" {
  let trigger = @reactive.signal(false)
  let source = @reactive.signal(0)
  let nested_runs = Ref(0)
  let stop = @reactive.effect(fn() {
    if trigger.get() {
      ignore(
        @reactive.effect(fn() {
          ignore(source.get())
          nested_runs.val += 1
        }),
      )
    }
  })
  defer stop()
  let ui_scope = @reactive.Scope::new()
  ui_scope.run(fn() { trigger.set(true) })
  assert_eq(nested_runs.val, 1)
  ui_scope.dispose()
  source.set(1)
  assert_eq(nested_runs.val, 2)
  stop()
  source.set(2)
  assert_eq(nested_runs.val, 2)
}

///|
test "update callbacks preserve FIFO when a callback queues another callback" {
  let order : Array[Int32] = []
  @reactive.during_update(fn() {
    @reactive.after_update(fn() {
      order.push(1)
      @reactive.after_update(fn() { order.push(3) })
    })
    @reactive.after_update(fn() { order.push(2) })
  })
  assert_eq(order, [1, 2, 3])
}
