///|
fn test_image(width : Int32, height : Int32) -> @foundation.Image raise {
  @foundation.Image(width~, height~, Bytes::new(width * height * 4))
}

///|
test "image replacement preserves identity and only relayouts for changed intrinsic size" {
  let first = test_image(40, 20)
  let same_size = test_image(40, 20)
  let larger = test_image(80, 40)
  let value = @reactive.signal(first)
  let root = @runtime.mount(
    fn() { @view.image(value, style=@view.ImageStyle().fit(Cover)) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=60.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  assert_eq(before.tree.nodes[0].component_name, "Image")
  assert_eq(before.tree.nodes[0].image.unwrap().size, first.size())
  value.set(first)
  assert_eq(root.dirty(), Clean)
  value.set(same_size)
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.frame.layout_count, before.frame.layout_count)
  assert_eq(after.tree.nodes[0].id, before.tree.nodes[0].id)
  value.set(larger)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.frame.layout_count, before.frame.layout_count + 1)
  assert_eq(after.tree.nodes[0].image.unwrap().size, larger.size())
  assert_eq(before.tree.nodes[0].image.unwrap().size, first.size())
}

///|
test "image getters are materialized per root and snapshot never evaluates a producer" {
  let first = test_image(30, 15)
  let next = test_image(60, 30)
  let value = @reactive.signal(first)
  let reads = Ref(0)
  let view = @view.image(
    @reactive.bind(fn() {
      reads.val += 1
      value.get()
    }),
  )
  assert_eq(reads.val, 0)
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=80.0)
  root.paint(renderer, size~)
  let before = reads.val
  ignore(root.snapshot())
  root.paint(renderer, size~)
  ignore(root.snapshot())
  assert_eq(reads.val, before)
  value.set(next)
  assert_eq(reads.val, before + 1)
  root.paint(renderer, size~)
  assert_eq(reads.val, before + 1)
  root.dispose()
  let disposed_reads = reads.val
  value.set(first)
  assert_eq(reads.val, disposed_reads)
}

///|
test "image fit style sources repaint while frame sources request layout" {
  let resource = test_image(40, 20)
  let cover = @reactive.signal(false)
  let width = @reactive.signal(80.0)
  let root = @runtime.mount(
    fn() {
      @view.image(
        resource,
        style=@view.ImageStyle::bind(
          @reactive.bind(fn() {
            @view.ImageStyle()
            .width(width)
            .height(80.0)
            .fit(if cover.get() { Cover } else { Contain })
          }),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=100.0)
  root.paint(renderer, size~)
  let before = root.frame_stats()
  cover.set(true)
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, before.layout_count)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].image.unwrap().fit,
    @foundation.Cover,
  )
  width.set(60.0)
  assert_eq(root.dirty(), NeedsLayout)
}

///|
test "a shared image view keeps source values isolated between roots" {
  let first = test_image(40, 20)
  let second = test_image(20, 40)
  let next = test_image(60, 30)
  let first_source = @reactive.signal(first)
  let second_source = @reactive.signal(second)
  let source = @reactive.Context(first_source)
  let create = fn() { @view.image(@reactive.bind(fn() { source.get().get() })) }
  let left = @runtime.mount(
    create,
    providers=[source.provide(first_source)],
    text_layout_system=test_text_layout_system(),
  )
  defer left.dispose()
  let right = @runtime.mount(
    create,
    providers=[source.provide(second_source)],
    text_layout_system=test_text_layout_system(),
  )
  defer right.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=100.0)
  right.paint(renderer, size~)
  left.paint(renderer, size~)
  assert_eq(
    left.snapshot().unwrap().tree.nodes[0].image.unwrap().size,
    first.size(),
  )
  assert_eq(
    right.snapshot().unwrap().tree.nodes[0].image.unwrap().size,
    second.size(),
  )
  first_source.set(next)
  assert_eq(left.dirty(), NeedsLayout)
  assert_eq(right.dirty(), Clean)
  left.dispose()
  second_source.set(first)
  right.paint(renderer, size~)
  assert_eq(
    right.snapshot().unwrap().tree.nodes[0].image.unwrap().size,
    first.size(),
  )
}
