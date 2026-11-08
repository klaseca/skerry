///|
fn bool_source(value : &@value.BoolValue) -> @reactive.Binding[Bool] {
  value.to_binding()
}

///|
fn string_source(value : &@value.StringValue) -> @reactive.Binding[String] {
  value.to_binding()
}

///|
fn int_source(value : &@value.IntValue) -> @reactive.Binding[Int32] {
  value.to_binding()
}

///|
fn double_source(value : &@value.DoubleValue) -> @reactive.Binding[Double] {
  value.to_binding()
}

///|
test "constant Boolean values do not subscribe the caller or retain a producer" {
  let binding = bool_source(true)
  assert_eq(binding.constant_value(), Some(true))
  let unrelated = @reactive.signal(0)
  let runs = Ref(0)
  let received : Array[Bool] = []
  let stop = @reactive.effect(fn() {
    runs.val += 1
    ignore(
      binding.subscribe(fn(value) {
        ignore(unrelated.get())
        received.push(value)
      }),
    )
  })
  defer stop()
  unrelated.set(1)
  assert_eq(runs.val, 1)
  assert_eq(received, [true])
}

///|
test "fixed type adapters preserve constants and accept signals or explicit bindings" {
  assert_eq(bool_source(true).constant_value(), Some(true))
  assert_eq(string_source("title").constant_value(), Some("title"))
  assert_eq(int_source(12).constant_value(), Some(12))
  assert_eq(double_source(12.5).constant_value(), Some(12.5))
  assert_eq(double_source(12.0).constant_value(), Some(12.0))
  assert_eq(double_source(@reactive.val(12.0)).constant_value(), Some(12.0))
  assert_eq(bool_source(@reactive.val(false)).constant_value(), Some(false))
  assert_eq(
    string_source(@reactive.val("saved")).constant_value(),
    Some("saved"),
  )
  let flag = @reactive.signal(false)
  let title = @reactive.signal("before")
  let number = @reactive.signal(1)
  let fraction = @reactive.signal(1.5)
  let flag_source = bool_source(flag)
  let title_source = string_source(title)
  let number_source = int_source(number.bind())
  let fraction_source = double_source(fraction.bind())
  flag.set(true)
  title.set("after")
  number.set(2)
  fraction.set(2.5)
  assert_true(flag_source.get())
  assert_eq(title_source.get(), "after")
  assert_eq(number_source.get(), 2)
  assert_eq(fraction_source.get(), 2.5)
}

///|
test "Double sources are cold and subscribe in the consuming scope" {
  let value = @reactive.signal(0.0)
  let reads = Ref(0)
  let source = double_source(
    @reactive.bind(fn() {
      reads.val += 1
      if value.get() < 2.0 {
        0.0
      } else {
        1.0
      }
    }),
  )
  let direct = double_source(value)
  assert_eq(reads.val, 0)
  let owner = @reactive.Scope::root()
  defer owner.dispose()
  let received : Array[Double] = []
  let signal_values : Array[Double] = []
  owner.run(fn() {
    ignore(source.subscribe(next => received.push(next)))
    ignore(direct.subscribe(next => signal_values.push(next)))
  })
  assert_eq(received, [0.0])
  assert_eq(reads.val, 1)
  value.set(1.0)
  value.set(2.0)
  assert_eq(received, [0.0, 1.0])
  assert_eq(signal_values, [0.0, 1.0, 2.0])
  assert_eq(reads.val, 3)
  owner.dispose()
  value.set(4.0)
  assert_eq(reads.val, 3)
  assert_eq(signal_values, [0.0, 1.0, 2.0])
}

///|
priv struct OpaquePayload {
  id : Int32
}

///|
fn[T] payload(source : @reactive.Binding[T]) -> @reactive.Binding[T] {
  source
}

///|
test "generic source factories need no per type adapter Show or Eq" {
  let constant = payload(@reactive.val(OpaquePayload::{ id: 1, }))
  assert_eq(constant.get().id, 1)
  assert_true(constant.constant_value() is Some({ id: 1, }))
  let model = @reactive.signal(OpaquePayload::{ id: 2, })
  let direct = payload(model.bind())
  let calls = Ref(0)
  let derived = payload(
    @reactive.bind(fn() {
      calls.val += 1
      OpaquePayload::{ id: model.get().id + 1, }
    }),
  )
  assert_eq(calls.val, 0)
  model.set({ id: 3, })
  assert_eq(direct.get().id, 3)
  assert_eq(derived.get().id, 4)
  assert_eq(calls.val, 1)
  assert_eq(constant.get().id, 1)
}

///|
test "fixed type adapters accept Computed without reading or adding a cache" {
  let source = @reactive.signal(1)
  let reads = Ref(0)
  let number = @reactive.computed(() => {
    reads.val += 1
    source.get()
  })
  let integer = int_source(number)
  let flag = bool_source(@reactive.computed(() => source.get() > 1))
  let title = string_source(@reactive.computed(() => source.get().to_string()))
  let fraction = double_source(
    @reactive.computed(() => source.get().to_double() / 2.0),
  )
  assert_eq(reads.val, 0)
  assert_eq(integer.constant_value(), None)
  assert_eq(fraction.constant_value(), None)
  assert_eq(integer.get(), 1)
  assert_eq(reads.val, 1)
  assert_false(flag.get())
  assert_eq(title.get(), "1")
  assert_eq(fraction.get(), 0.5)
  source.set(2)
  assert_eq(integer.get(), 2)
  assert_eq(reads.val, 2)
  assert_true(flag.get())
  assert_eq(title.get(), "2")
  assert_eq(fraction.get(), 1.0)
}

///|
test "computed Double sources preserve equality and consumer disposal" {
  let source = @reactive.signal(0.0)
  let value = @reactive.computed(() => {
    if source.get() < 2.0 {
      0.0
    } else {
      1.0
    }
  })
  let binding = double_source(value)
  let owner = @reactive.Scope::root()
  defer owner.dispose()
  let received : Array[Double] = []
  owner.run(() => ignore(binding.subscribe(next => received.push(next))))
  source.set(1.0)
  source.set(2.0)
  assert_eq(received, [0.0, 1.0])
  owner.dispose()
  source.set(4.0)
  assert_eq(received, [0.0, 1.0])
}
