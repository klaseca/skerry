///|
test "root releases user effects watches and cleanup once" {
  let source = @reactive.signal(0)
  let runs : Array[Int32] = []
  let watched : Array[(Int32, Int32)] = []
  let cleanups = Ref(0)
  let effect_cleanups = Ref(0)
  let root = @runtime.mount(
    fn() {
      ignore(
        @reactive.effect(fn() {
          runs.push(source.get())
          @reactive.on_cleanup(fn() { effect_cleanups.val += 1 })
        }),
      )
      ignore(
        @reactive.watch(fn() { source.get() }, fn(value, previous) {
          watched.push((value, previous))
        }),
      )
      @reactive.on_cleanup(fn() { cleanups.val += 1 })
      @view.empty()
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(runs, [0])
  source.set(1)
  assert_eq(runs, [0, 1])
  assert_eq(watched, [(1, 0)])
  assert_eq(cleanups.val, 0)
  assert_eq(effect_cleanups.val, 1)
  root.dispose()
  root.dispose()
  source.set(2)
  assert_eq(runs, [0, 1])
  assert_eq(watched, [(1, 0)])
  assert_eq(cleanups.val, 1)
  assert_eq(effect_cleanups.val, 2)
}

///|
test "roots keep independent subscriptions and restore the caller context" {
  let source = @reactive.signal(0)
  let first_runs = Ref(0)
  let second_runs = Ref(0)
  let outside_runs = Ref(0)
  let first_cleanups = Ref(0)
  let second_cleanups = Ref(0)
  fn content(runs : Ref[Int32], cleanups : Ref[Int32]) -> @view.View {
    ignore(
      @reactive.effect(fn() {
        ignore(source.get())
        runs.val += 1
      }),
    )
    @reactive.on_cleanup(fn() { cleanups.val += 1 })
    @view.empty()
  }
  let first = @runtime.mount(
    fn() { content(first_runs, first_cleanups) },
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    fn() { content(second_runs, second_cleanups) },
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  let stop_outside = @reactive.effect(fn() {
    ignore(source.get())
    outside_runs.val += 1
  })
  defer stop_outside()
  first.dispose()
  source.set(1)
  assert_eq(first_runs.val, 1)
  assert_eq(second_runs.val, 2)
  assert_eq(outside_runs.val, 2)
  assert_eq(first_cleanups.val, 1)
  assert_eq(second_cleanups.val, 0)
  second.dispose()
  source.set(2)
  assert_eq(second_runs.val, 2)
  assert_eq(outside_runs.val, 3)
  assert_eq(second_cleanups.val, 1)
}

///|
test "root cleanup can update a dependency without rerunning disposed effects" {
  let source = @reactive.signal(0)
  let runs = Ref(0)
  let cleanups = Ref(0)
  let root = @runtime.mount(
    fn() {
      ignore(
        @reactive.effect(fn() {
          ignore(source.get())
          runs.val += 1
          @reactive.on_cleanup(fn() {
            cleanups.val += 1
            source.update(value => value + 1)
          })
        }),
      )
      @view.empty()
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.dispose()
  root.dispose()
  assert_eq(source.get(), 1)
  assert_eq(cleanups.val, 1)
  assert_eq(runs.val, 1)
}

///|
test "root disposal cancels subscriptions waiting for batch completion" {
  let source = @reactive.signal(0)
  let runs : Array[Int32] = []
  let watched : Array[Int32] = []
  let cleanups = Ref(0)
  let root = @runtime.mount(
    fn() {
      ignore(@reactive.effect(fn() { runs.push(source.get()) }))
      ignore(
        @reactive.watch(fn() { source.get() }, fn(value, _) {
          watched.push(value)
        }),
      )
      @reactive.on_cleanup(fn() { cleanups.val += 1 })
      @view.empty()
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  @reactive.batch(fn() {
    source.set(1)
    root.dispose()
    source.set(2)
  })
  assert_eq(runs, [0])
  assert_eq(watched, [])
  assert_eq(cleanups.val, 1)
}

///|
test "a root created by another builder has an independent lifetime" {
  let source = @reactive.signal(0)
  let calls = Ref(0)
  let cleanups = Ref(0)
  let nested : Ref[@runtime.UiRoot?] = Ref(None)
  let parent = @runtime.mount(
    fn() {
      nested.val = Some(
        @runtime.mount(
          fn() {
            ignore(
              @reactive.effect(fn() {
                ignore(source.get())
                calls.val += 1
              }),
            )
            @reactive.on_cleanup(fn() { cleanups.val += 1 })
            @view.empty()
          },
          text_layout_system=test_text_layout_system(),
        ),
      )
      @view.empty()
    },
    text_layout_system=test_text_layout_system(),
  )
  defer parent.dispose()
  let child = nested.val.unwrap()
  defer child.dispose()
  parent.dispose()
  source.set(1)
  assert_eq(calls.val, 2)
  assert_eq(cleanups.val, 0)
  child.dispose()
  source.set(2)
  assert_eq(calls.val, 2)
  assert_eq(cleanups.val, 1)
}

///|
test "effect cleanup keeps its root context across updates from another scope" {
  let source = @reactive.signal(0)
  let nested_source = @reactive.signal(0)
  let calls = Ref(0)
  let root = @runtime.mount(
    fn() {
      ignore(
        @reactive.effect(fn() {
          ignore(source.get())
          @reactive.on_cleanup(fn() {
            ignore(
              @reactive.effect(fn() {
                ignore(nested_source.get())
                calls.val += 1
              }),
            )
          })
        }),
      )
      @view.empty()
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let other_scope = @reactive.Scope::root()
  defer other_scope.dispose()
  other_scope.run(fn() { source.set(1) })
  assert_eq(calls.val, 1)
  other_scope.dispose()
  nested_source.set(1)
  assert_eq(calls.val, 2)
  root.dispose()
  nested_source.set(2)
  assert_eq(calls.val, 2)
}
