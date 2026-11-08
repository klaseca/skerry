///|
test "binding is cold and subscriptions track source changes without tracking receivers" {
  let source = @reactive.signal(0)
  let unrelated = @reactive.signal(0)
  let reads = Ref(0)
  let binding = @reactive.bind(fn() {
    reads.val += 1
    source.get() / 2
  })
  assert_eq(reads.val, 0)
  assert_eq(binding.constant_value(), None)
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let received : Array[Int32] = []
  let stop = scope.run(fn() {
    binding.subscribe(fn(value) {
      ignore(unrelated.get())
      received.push(value)
    })
  })
  assert_eq(received, [0])
  assert_eq(reads.val, 1)
  unrelated.set(1)
  assert_eq(reads.val, 1)
  source.set(1)
  assert_eq(received, [0])
  @reactive.batch(fn() {
    source.set(2)
    source.set(4)
    source.set(6)
  })
  assert_eq(received, [0, 3])
  assert_eq(reads.val, 3)
  stop()
  stop()
  source.set(8)
  assert_eq(received, [0, 3])
  assert_eq(reads.val, 3)
}

///|
test "binding subscribers have independent scopes and contexts" {
  let first = @reactive.Scope::root()
  let second = @reactive.Scope::root()
  defer first.dispose()
  defer second.dispose()
  let key = @reactive.Context(0)
  let source = @reactive.signal(0)
  let binding = @reactive.bind(fn() { key.get() + source.get() })
  let one : Array[Int32] = []
  let two : Array[Int32] = []
  first.run_with([key.provide(10)], fn() {
    ignore(binding.subscribe(fn(value) { one.push(value) }))
  })
  second.run_with([key.provide(20)], fn() {
    ignore(binding.subscribe(fn(value) { two.push(value) }))
  })
  source.set(1)
  assert_eq(one, [10, 11])
  assert_eq(two, [20, 21])
  first.dispose()
  source.set(2)
  assert_eq(one, [10, 11])
  assert_eq(two, [20, 21, 22])
}

///|
test "binding restores lexical providers within a root and uses foreign mount context" {
  let first = @reactive.Scope::root()
  let second = @reactive.Scope::root()
  defer first.dispose()
  defer second.dispose()
  let key = @reactive.Context(0)
  let source = @reactive.signal(0)
  let binding = first.run_with([key.provide(10)], fn() {
    @reactive.bind(fn() { key.get() + source.get() })
  })
  let one : Array[Int32] = []
  let two : Array[Int32] = []
  first.run_with([key.provide(30)], fn() {
    ignore(binding.subscribe(fn(value) { one.push(value) }))
  })
  second.run_with([key.provide(20)], fn() {
    ignore(binding.subscribe(fn(value) { two.push(value) }))
  })
  source.set(1)
  assert_eq(one, [10, 11])
  assert_eq(two, [20, 21])
  first.dispose()
  source.set(2)
  assert_eq(two, [20, 21, 22])
}
