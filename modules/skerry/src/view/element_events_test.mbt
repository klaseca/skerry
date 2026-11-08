///|
fn event_test_leaf(events : @view.ElementEvents) -> @view.View {
  @view.element(
    style=@style.BoxStyle().width(80.0).height(32.0),
    painter=@view.Painter::empty(),
    events~,
  )
}

///|
test "event disabled sources are cold shared per root and subscribed once through decorators" {
  let context = @reactive.Context(false)
  let blocked = @reactive.signal(false)
  let reads = Ref(0)
  let clicks = Ref(0)
  let source = @reactive.bind(fn() {
    reads.val += 1
    blocked.get() || context.get()
  })
  let events = @view.ElementEvents(focusable=true, disabled=source, on_click=fn() {
    clicks.val += 1
  })
  let build = fn() {
    let leaf = event_test_leaf(events)
    @view.interactive(@view.interactive(leaf))
  }
  assert_eq(reads.val, 0)
  let first = @runtime.mount(
    build,
    providers=[context.provide(true)],
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    build,
    providers=[context.provide(false)],
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  assert_eq(reads.val, 2)
  let size = @foundation.Size(width=100.0, height=40.0)
  let point = @foundation.Point(x=10.0, y=10.0)
  assert_false(first.click_at(size~, point~))
  assert_true(second.click_at(size~, point~))
  assert_eq(clicks.val, 1)
  assert_eq(reads.val, 2)
  blocked.set(true)
  assert_false(first.click_at(size~, point~))
  assert_false(second.click_at(size~, point~))
  assert_eq(reads.val, 4)
  blocked.set(false)
  assert_false(first.click_at(size~, point~))
  assert_true(second.click_at(size~, point~))
  assert_eq(clicks.val, 2)
  assert_eq(reads.val, 6)
  first.dispose()
  second.dispose()
  blocked.set(true)
  assert_eq(reads.val, 6)
}

///|
test "interactive retains applied disabled state and explicit overrides replace its source" {
  let blocked = @reactive.signal(false)
  let reads = Ref(0)
  let source = @reactive.bind(fn() {
    reads.val += 1
    blocked.get()
  })
  let leaf = event_test_leaf(@view.ElementEvents(disabled=source))
  let stop = leaf.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
    ()
  })
  defer stop()
  assert_eq(reads.val, 1)
  blocked.set(true)
  let decorated = @view.interactive(@view.interactive(leaf))
  assert_false(decorated.is_enabled_path([]))
  assert_eq(reads.val, 2)
  assert_true(@view.interactive(leaf, disabled=false).is_enabled_path([]))
  blocked.set(false)
  assert_true(decorated.is_enabled_path([]))
  assert_eq(reads.val, 3)
  stop()
  let overridden = @view.interactive(
    event_test_leaf(@view.ElementEvents(disabled=source)),
    disabled=false,
  )
  let stop_override = overridden.mount_reactivity(
    mark_layout_dirty=fn() { () },
    mark_paint_dirty=fn() { () },
  )
  defer stop_override()
  assert_eq(reads.val, 3)
  assert_true(overridden.is_enabled_path([]))
  assert_false(
    event_test_leaf(@view.ElementEvents(disabled=true)).is_enabled_path([]),
  )
}

///|
test "focus entry and decorated handlers retain their separate construction contexts" {
  let context = @reactive.Context("default")
  let entry_context = Ref("")
  let clicks : Array[String] = []
  let root = @runtime.mount(
    fn() {
      let inner = @reactive.provide([context.provide("inner")], fn() {
        event_test_leaf(
          @view.ElementEvents(
            focusable=true,
            focus_entry=fn() {
              entry_context.val = context.get()
              None
            },
            on_click=fn() { clicks.push(context.get()) },
          ),
        )
      })
      @view.interactive(inner, on_click=fn() { clicks.push(context.get()) })
    },
    providers=[context.provide("outer")],
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(entry_context.val, "")
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(entry_context.val, "inner")
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_eq(clicks, ["inner", "outer"])
}
