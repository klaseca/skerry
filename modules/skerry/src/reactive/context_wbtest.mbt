///|
test "typed providers shadow by owner ancestry and cleanup removes their values" {
  let number = Context(0)
  let label = Context("default")
  let first = Scope::root()
  defer first.dispose()
  let second = Scope::root()
  defer second.dispose()
  let outer = first.run_with([number.provide(1), label.provide("outer")], fn() {
    Scope::current().unwrap()
  })
  let inner = outer.run_with([number.provide(2)], fn() {
    Scope::current().unwrap()
  })
  assert_eq(outer.run(fn() { number.get() }), 1)
  assert_eq(inner.run(fn() { number.get() }), 2)
  assert_eq(inner.run(fn() { label.get() }), "outer")
  assert_eq(second.run(fn() { number.get() }), 0)
  assert_eq(number.get(), 0)
  inner.dispose()
  assert_eq(number.entries.length(), 1)
  first.dispose()
  assert_eq(number.entries.length(), 0)
  assert_eq(label.entries.length(), 0)
  assert_eq(outer.run(fn() { number.get() }), 0)
}

///|
test "standalone provide is lexical and does not retain providers or effects" {
  let key = Context(0)
  let source = signal(0)
  let runs = Ref(0)
  assert_eq(
    provide([key.provide(3)], fn() {
      ignore(
        effect(fn() {
          ignore(source.get())
          runs.val += 1
        }),
      )
      key.get()
    }),
    3,
  )
  assert_eq(key.entries.length(), 0)
  source.set(1)
  assert_eq(runs.val, 1)
}
