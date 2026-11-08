///|
test "computed is cold and caches reads until a dependency changes" {
  let source = @reactive.signal(1)
  let reads = Ref(0)
  let value : @reactive.Computed[Int32] = @reactive.computed(() => {
    reads.val += 1
    source.get() * 2
  })
  let binding = value.bind()
  assert_eq(reads.val, 0)
  assert_eq(binding.constant_value(), None)
  assert_eq(value.get(), 2)
  assert_eq(binding.get(), 2)
  assert_eq(value.get(), 2)
  assert_eq(reads.val, 1)
  source.set(2)
  assert_eq(reads.val, 1)
  assert_eq(binding.get(), 4)
  assert_eq(value.get(), 4)
  assert_eq(reads.val, 2)
}

///|
test "computed readers share a cache and receive dependency updates" {
  let source = @reactive.signal(1)
  let reads = Ref(0)
  let value = @reactive.computed(() => {
    reads.val += 1
    source.get() * 2
  })
  let first : Array[Int32] = []
  let second : Array[Int32] = []
  let stop_first = @reactive.render_effect(() => first.push(value.get()))
  defer stop_first()
  let stop_second = @reactive.render_effect(() => second.push(value.get()))
  defer stop_second()
  assert_eq((first, second), ([2], [2]))
  assert_eq(reads.val, 1)
  source.set(2)
  assert_eq((first, second), ([2, 4], [2, 4]))
  assert_eq(reads.val, 2)
  stop_first()
  source.set(3)
  assert_eq((first, second), ([2, 4], [2, 4, 6]))
  assert_eq(reads.val, 3)
  stop_second()
  source.set(4)
  assert_eq(reads.val, 3)
}

///|
test "computed tracks changing dependencies and batches their final values" {
  let choose_first = @reactive.signal(true)
  let first = @reactive.signal(1)
  let second = @reactive.signal(10)
  let reads = Ref(0)
  let value = @reactive.computed(() => {
    reads.val += 1
    if choose_first.get() {
      first.get()
    } else {
      second.get()
    }
  })
  let received : Array[Int32] = []
  let stop = @reactive.render_effect(() => received.push(value.get()))
  defer stop()
  second.set(11)
  assert_eq(reads.val, 1)
  first.set(2)
  choose_first.set(false)
  first.set(3)
  assert_eq(received, [1, 2, 11])
  assert_eq(reads.val, 3)
  @reactive.batch(() => {
    second.set(12)
    second.set(13)
  })
  assert_eq(received, [1, 2, 11, 13])
  assert_eq(reads.val, 4)
}

///|
test "nested computed values share dependencies and deliver a coherent batch" {
  let source = @reactive.signal(1)
  let left = @reactive.computed(() => source.get() * 2)
  let right = @reactive.computed(() => source.get() + 10)
  let total = @reactive.computed(() => left.get() + right.get())
  let received : Array[Int32] = []
  let stop = @reactive.render_effect(() => received.push(total.get()))
  defer stop()
  assert_eq(received, [13])
  @reactive.batch(() => {
    source.set(2)
    source.set(3)
  })
  assert_eq(received, [13, 19])
  assert_eq((left.get(), right.get(), total.get()), (6, 13, 19))
}

///|
test "computed bindings compare results and release subscriptions with each owner" {
  let source = @reactive.signal(0)
  let reads = Ref(0)
  let value = @reactive.computed(() => {
    reads.val += 1
    source.get() / 2
  })
  let binding = value.bind()
  let first = @reactive.Scope::root()
  defer first.dispose()
  let second = @reactive.Scope::root()
  defer second.dispose()
  let a : Array[Int32] = []
  let b : Array[Int32] = []
  first.run(() => ignore(binding.subscribe(next => a.push(next))))
  second.run(() => ignore(binding.subscribe(next => b.push(next))))
  source.set(1)
  assert_eq((a, b), ([0], [0]))
  source.set(2)
  assert_eq((a, b), ([0, 1], [0, 1]))
  assert_eq(reads.val, 3)
  first.dispose()
  source.set(4)
  assert_eq((a, b), ([0, 1], [0, 1, 2]))
  second.dispose()
  source.set(6)
  assert_eq(reads.val, 4)
  assert_eq(value.get(), 3)
  assert_eq(reads.val, 5)
  assert_eq((a, b), ([0, 1], [0, 1, 2]))
}

///|
priv struct ComputedPayload {
  id : Int32
}

///|
test "computed and its generic binding need no payload adapter Show or Eq" {
  let source = @reactive.signal(1)
  let value = @reactive.computed(() => ComputedPayload::{ id: source.get(), })
  let binding : @reactive.Binding[ComputedPayload] = value.bind()
  assert_eq(value.get().id, 1)
  assert_eq(binding.get().id, 1)
  source.set(2)
  assert_eq(binding.get().id, 2)
}

///|
test "computed does not subscribe its construction caller" {
  let source = @reactive.signal(1)
  let builds = Ref(0)
  let reads = Ref(0)
  let saved : Ref[@reactive.Computed[Int32]?] = Ref(None)
  let stop = @reactive.effect(() => {
    builds.val += 1
    saved.val = Some(
      @reactive.computed(() => {
        reads.val += 1
        source.get()
      }),
    )
  })
  defer stop()
  source.set(2)
  assert_eq((builds.val, reads.val), (1, 0))
  assert_eq(saved.val.unwrap().get(), 2)
  source.set(3)
  assert_eq((builds.val, reads.val), (1, 1))
  assert_eq(saved.val.unwrap().get(), 3)
}
