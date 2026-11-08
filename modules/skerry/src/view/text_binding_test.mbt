///|
test "text sources are cold and mounted paint input and snapshots never read producers" {
  let value = @reactive.signal("first")
  let reads = Ref(0)
  let construction_reads = Ref(-1)
  let root = @runtime.mount(
    fn() {
      let view = @view.text(
        @reactive.bind(fn() {
          reads.val += 1
          value.get()
        }),
      )
      construction_reads.val = reads.val
      view
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(construction_reads.val, 0)
  assert_eq(reads.val, 1)
  let recorder = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=200.0, height=40.0)
  root.paint(recorder, size~)
  assert_eq(recorder.text.val, Some("first"))
  ignore(root.snapshot())
  ignore(root.snapshot())
  ignore(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  ignore(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
  ignore(root.key_down(test_key_event(KeyTab)))
  root.mark_paint_dirty()
  root.paint(recorder, size~)
  root.paint(recorder, size=Size(width=240.0, height=60.0))
  assert_eq(reads.val, 1)
  value.set("second")
  assert_eq(reads.val, 2)
  root.paint(recorder, size~)
  assert_eq(recorder.text.val, Some("second"))
  assert_eq(reads.val, 2)
  root.dispose()
  value.set("disposed")
  assert_eq(reads.val, 2)
}

///|
test "text accepts direct String signals and constant or ready bindings" {
  let title = @reactive.signal("before")
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text("literal"),
        @view.text(title),
        @view.text(@reactive.val("constant")),
        @view.text(title.bind()),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  let size = @foundation.Size(width=200.0, height=120.0)
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), [
    "literal", "before", "constant", "before",
  ])
  recorder.runs.clear()
  title.set("after")
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), [
    "literal", "after", "constant", "after",
  ])
}

///|
test "equal final text keeps the root idle and reuses measured layout" {
  let count = @reactive.signal(0)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      @view.text(@reactive.bind(fn() { (count.get() / 2).to_string() }))
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=40.0)
  let recorder = TextRunRecorder::{ text: Ref(None), }
  root.paint(recorder, size~)
  let before = root.frame_stats()
  let node_id = root.snapshot().unwrap().tree.nodes[0].id
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  count.set(1)
  assert_eq(root.dirty(), Clean)
  assert_eq(wakeups.val, 0)
  assert_eq(root.frame_stats(), before)
  count.set(2)
  assert_eq(root.dirty(), NeedsLayout)
  assert_eq(wakeups.val, 1)
  root.paint(recorder, size~)
  assert_eq(recorder.text.val, Some("1"))
  assert_eq(root.frame_stats().layout_count, before.layout_count + 1)
  assert_eq(root.snapshot().unwrap().tree.nodes[0].id, node_id)
  assert_eq(builds.val, 1)
}

///|
test "text instances keep separate applied strings and owners in different roots" {
  let key = @reactive.Context(@reactive.signal("default"))
  let one = @reactive.signal("one")
  let two = @reactive.signal("two")
  let reads : Array[String] = []
  let create = fn() {
    @view.text(
      @reactive.bind(fn() {
        let next = key.get().get()
        reads.push(next)
        next
      }),
    )
  }
  let a = @runtime.mount(
    create,
    providers=[key.provide(one)],
    text_layout_system=test_text_layout_system(),
  )
  defer a.dispose()
  let b = @runtime.mount(
    create,
    providers=[key.provide(two)],
    text_layout_system=test_text_layout_system(),
  )
  defer b.dispose()
  let first = TextRunRecorder::{ text: Ref(None), }
  let second = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=200.0, height=40.0)
  a.paint(first, size~)
  b.paint(second, size~)
  assert_eq((first.text.val, second.text.val), (Some("one"), Some("two")))
  assert_eq(reads, ["one", "two"])
  ignore(create().layout(size~, text_layout_system=test_text_layout_system()))
  assert_eq(reads, ["one", "two", "default"])
  one.set("updated")
  assert_eq(a.dirty(), NeedsLayout)
  assert_eq(b.dirty(), Clean)
  a.paint(first, size~)
  b.mark_paint_dirty()
  b.paint(second, size~)
  assert_eq((first.text.val, second.text.val), (Some("updated"), Some("two")))
  assert_true(
    a.snapshot().unwrap().tree.nodes[0].id !=
    b.snapshot().unwrap().tree.nodes[0].id,
  )
  a.dispose()
  one.set("ignored")
  two.set("still live")
  b.paint(second, size~)
  assert_eq(second.text.val, Some("still live"))
  assert_eq(reads, ["one", "two", "default", "updated", "still live"])
}

///|
test "text instances retain their own lexical providers" {
  let key = @reactive.Context(@reactive.signal("default"))
  let inner = @reactive.signal("inner")
  let other = @reactive.signal("other")
  let create = fn() { @view.text(@reactive.bind(fn() { key.get().get() })) }
  let a = @runtime.mount(
    fn() { @reactive.provide([key.provide(inner)], create) },
    text_layout_system=test_text_layout_system(),
  )
  defer a.dispose()
  let b = @runtime.mount(
    create,
    providers=[key.provide(other)],
    text_layout_system=test_text_layout_system(),
  )
  defer b.dispose()
  let first = TextRunRecorder::{ text: Ref(None), }
  let second = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=200.0, height=40.0)
  a.paint(first, size~)
  b.paint(second, size~)
  assert_eq((first.text.val, second.text.val), (Some("inner"), Some("other")))
  a.dispose()
  other.set("after original root")
  b.paint(second, size~)
  assert_eq(second.text.val, Some("after original root"))
}

///|
test "detaching a text branch releases its producer and remount reads it once" {
  let visible = @reactive.signal(true)
  let value = @reactive.signal("before")
  let reads = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.show(fn() { visible.get() }, fn() {
          @view.text(
            @reactive.bind(fn() {
              reads.val += 1
              value.get()
            }),
          )
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(reads.val, 1)
  visible.set(false)
  value.set("hidden")
  assert_eq(reads.val, 1)
  visible.set(true)
  assert_eq(reads.val, 2)
  let recorder = TextRunRecorder::{ text: Ref(None), }
  root.paint(recorder, size=Size(width=200.0, height=40.0))
  assert_eq(recorder.text.val, Some("hidden"))
  assert_eq(reads.val, 2)
}

///|
test "frame wakeup sees all applied text values after a batch" {
  let first = @reactive.signal("one")
  let second = @reactive.signal("two")
  let root = @runtime.mount(
    fn() { @view.column([@view.text(first), @view.text(second)]) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=80.0)
  root.paint(text_color_recorder(), size~)
  let frames : Array[Array[String]] = []
  root.set_wakeup(fn() {
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    frames.push(recorder.runs.map(run => run.text))
  })
  @reactive.batch(fn() {
    first.set("FIRST")
    second.set("SECOND")
  })
  assert_eq(frames, [["FIRST", "SECOND"]])
  assert_true(root.snapshot() is Some(_))
}

///|
test "text changed during paint invalidates the frame without paint pulling the source" {
  let value = @reactive.signal("before")
  let reads = Ref(0)
  let change = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text(
          @reactive.bind(fn() {
            reads.val += 1
            value.get()
          }),
        ),
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if change.val {
              change.val = false
              value.set("after")
            }
          }),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=200.0, height=80.0)
  root.paint(recorder, size~)
  assert_eq(recorder.text.val, Some("before"))
  assert_eq(reads.val, 2)
  assert_eq(root.dirty(), NeedsLayout)
  assert_true(root.snapshot() is None)
  root.paint(recorder, size~)
  assert_eq(recorder.text.val, Some("after"))
  assert_eq(reads.val, 2)
  assert_true(root.snapshot() is Some(_))
}

///|
test "standalone layout and paint materialize a dynamic text once per operation" {
  let value = @reactive.signal("before")
  let reads = Ref(0)
  let view = @view.text(
    @reactive.bind(fn() {
      reads.val += 1
      value.get()
    }),
  )
  assert_eq(reads.val, 0)
  let size = @foundation.Size(width=200.0, height=40.0)
  let system = test_text_layout_system()
  ignore(view.layout(size~, text_layout_system=system))
  assert_eq(reads.val, 1)
  let state = @view.LayoutState(text_layout_system=system)
  defer state.dispose()
  let recorder = TextRunRecorder::{ text: Ref(None), }
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(recorder.text.val, Some("before"))
  assert_eq(reads.val, 2)
  value.set("after")
  state.invalidate()
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(recorder.text.val, Some("after"))
  assert_eq(reads.val, 3)
}

///|
test "standalone paint inside a root builder reads before subscriptions mount" {
  let reads = Ref(0)
  let recorder = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=200.0, height=40.0)
  let root = @runtime.mount(
    fn() {
      let view = @view.text(
        @reactive.bind(fn() {
          reads.val += 1
          "during build"
        }),
      )
      let state = @view.LayoutState(
        text_layout_system=test_text_layout_system(),
      )
      defer state.dispose()
      state.paint(view, size~, recorder, focused_path=None)
      view
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(recorder.text.val, Some("during build"))
  assert_eq(reads.val, 2)
  root.paint(recorder, size~)
  assert_eq(recorder.text.val, Some("during build"))
  assert_eq(reads.val, 2)
}

///|
test "mounted low level hosts paint the applied value and release it on disposal" {
  let value = @reactive.signal("before")
  let reads = Ref(0)
  let view = @view.text(
    @reactive.bind(fn() {
      reads.val += 1
      value.get()
    }),
  )
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  let stop = scope.run(fn() {
    view.mount_reactivity(mark_layout_dirty=fn() { state.invalidate() }, mark_paint_dirty=fn() {
      ()
    })
  })
  defer stop()
  assert_eq(reads.val, 1)
  let size = @foundation.Size(width=200.0, height=40.0)
  let recorder = TextRunRecorder::{ text: Ref(None), }
  state.paint(view, size~, recorder, focused_path=None)
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(reads.val, 1)
  value.set("after")
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(recorder.text.val, Some("after"))
  assert_eq(reads.val, 2)
  stop()
  value.set("unmounted")
  assert_eq(reads.val, 2)
  state.invalidate()
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(recorder.text.val, Some("unmounted"))
  assert_eq(reads.val, 3)
}

///|
test "standalone text paint inside a mounted callback samples its own view" {
  let reads = Ref(0)
  let value = @reactive.signal("detached")
  let detached = @view.text(
    @reactive.bind(fn() {
      reads.val += 1
      value.get()
    }),
  )
  let recorder = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=200.0, height=40.0)
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  let root = @runtime.mount(
    fn() {
      @controls.button("Render", on_click=fn() {
        state.invalidate()
        state.paint(detached, size~, recorder, focused_path=None)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(recorder.text.val, Some("detached"))
  assert_eq(reads.val, 1)
  value.set("updated")
  assert_eq(reads.val, 1)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(recorder.text.val, Some("updated"))
  assert_eq(reads.val, 2)
}

///|
test "standalone subtree paint inside its root reuses the applied string" {
  let reads = Ref(0)
  let value = @reactive.signal("mounted")
  let shared = @view.text(
    @reactive.bind(fn() {
      reads.val += 1
      value.get()
    }),
  )
  let recorder = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=200.0, height=80.0)
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("Render", on_click=fn() {
          state.invalidate()
          state.paint(shared, size~, recorder, focused_path=None)
        }),
        shared,
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(recorder.text.val, Some("mounted"))
  assert_eq(reads.val, 1)
  value.set("updated")
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(recorder.text.val, Some("updated"))
  assert_eq(reads.val, 2)
}
