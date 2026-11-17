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

///|
test "cleanup preserves its scope and runs once across reentrant disposal" {
  let key = @reactive.Context("outside")
  let parent = @reactive.Scope::root()
  defer parent.dispose()
  let cleaned : Array[String] = []
  let disposed_scopes : Array[Bool] = []
  let scope = parent.run_with([key.provide("inside")], fn() {
    let scope = @reactive.Scope::current().unwrap()
    @reactive.on_cleanup(fn() {
      disposed_scopes.push(
        @reactive.Scope::current()
        .map(scope => scope.is_disposed())
        .unwrap_or(false),
      )
      cleaned.push(key.get())
      scope.dispose()
      @reactive.on_cleanup(fn() { cleaned.push("already disposed") })
    })
    scope
  })
  scope.dispose()
  scope.dispose()
  // Disposed providers are unavailable even while their cleanup is running.
  assert_eq(cleaned, ["outside", "already disposed"])
  assert_eq(disposed_scopes, [true])
  assert_eq(key.get(), "outside")
}

///|
test "manually stopped effect cleanup runs under its captured live provider" {
  let key = @reactive.Context("outside")
  let parent = @reactive.Scope::root()
  defer parent.dispose()
  let cleaned : Array[String] = []
  let stop = parent.run_with([key.provide("inside")], fn() {
    @reactive.render_effect(fn() {
      @reactive.on_cleanup(fn() { cleaned.push(key.get()) })
    })
  })
  stop()
  stop()
  assert_eq(cleaned, ["inside"])
  assert_eq(key.get(), "outside")
}
