///|
test "signal batch coalesces effect runs" {
  let count = @reactive.signal(0)
  let runs = Ref(0)
  let dispose = @reactive.effect(fn() {
    ignore(count.get())
    runs.val = runs.val + 1
  })
  inspect(runs.val, content="1")
  @reactive.batch(fn() {
    count.set(1)
    count.set(2)
  })
  inspect(runs.val, content="2")
  dispose()
}
