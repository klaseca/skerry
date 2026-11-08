///|
test "reactive disabled preserves built-in identity geometry and cached layout in both themes" {
  for theme in [@style.Theme(), Theme(palette=@style.Palette::dark())] {
    for kind in 0..<4 {
      let disabled = @reactive.signal(false)
      let root = @runtime.mount(
        fn() { state_test_control(kind, control_test_style(), disabled) },
        theme~,
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let renderer = StyleRecorder()
      let size = @foundation.Size(width=150.0, height=50.0)
      assert_true(root.key_down(test_key_event(KeyTab)))
      root.paint(renderer, size~)
      let before = root.snapshot().unwrap()
      disabled.set(true)
      assert_eq(root.dirty(), NeedsPaint)
      assert_eq(root.snapshot(), None)
      assert_false(root.key_down(test_key_event(KeyEnter)))
      assert_false(root.text_input("ignored"))
      assert_false(root.click_at(size~, point=Point(x=10.0, y=10.0)))
      root.paint(renderer, size~)
      let after = root.snapshot().unwrap()
      assert_eq(after.focused_node_id, None)
      assert_eq(after.tree.nodes[0].state, ControlState(disabled=true))
      assert_eq(after.tree.nodes[0].id, before.tree.nodes[0].id)
      assert_eq(after.tree.nodes[0].frame, before.tree.nodes[0].frame)
      assert_eq(after.frame.layout_count, before.frame.layout_count)
      assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
      assert_eq(
        after.tree.nodes[0].computed_style.unwrap().background,
        Some(renderer.fills[0].0),
      )
      assert_eq(
        renderer.fills[0].0,
        @foundation.Color::rgb(r=150, g=160, b=170),
      )
      disabled.set(false)
      root.paint(renderer, size~)
      assert_false(root.snapshot().unwrap().tree.nodes[0].disabled)
      assert_eq(root.snapshot().unwrap().focused_node_id, None)
      assert_true(root.key_down(test_key_event(KeyTab)))
    }
  }
}

///|
test "disabled text input retains value and caret but releases focus and selection capture" {
  let disabled = @reactive.signal(false)
  let value = @reactive.signal("abcd")
  let blurs = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_blur=fn() { blurs.val += 1 }, disabled~)
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  disabled.set(true)
  assert_eq(blurs.val, 1)
  assert_eq(root.copy_text(), None)
  assert_eq(root.cut_text(), None)
  assert_false(root.paste_text("wrong"))
  assert_false(root.text_input("wrong"))
  assert_false(root.key_down(test_key_event(KeyTab)))
  disabled.set(false)
  assert_false(root.text_input("wrong"))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "abXcd")
  assert_eq(blurs.val, 1)
}

///|
test "disabling an ancestor cancels capture and blur even if cancel re-enables it" {
  let disabled = @reactive.signal(false)
  let events : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.button(
            "press",
            style=@controls.ButtonStyle().surface(control_test_style()),
            on_click=fn() { events.push("click") },
            on_pointer_cancel=fn() {
              events.push("cancel")
              disabled.set(false)
            },
            on_blur=fn() { events.push("blur") },
          ),
        ],
        disabled~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  let point = @foundation.Point(x=10.0, y=10.0)
  assert_true(root.pointer_down(size~, point~))
  disabled.set(true)
  assert_eq(events, ["cancel", "blur"])
  assert_false(root.pointer_cancel())
  assert_false(root.pointer_up(size~, point~))
  assert_false(root.key_down(test_key_event(KeyEnter)))
  root.paint(StyleRecorder(), size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.focused_node_id, None)
  assert_eq(after.captured_node_id, None)
  assert_false(after.tree.nodes[1].state.pressed)
  assert_false(after.tree.nodes[1].disabled)
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_eq(events, ["cancel", "blur", "click"])
}

///|
test "disabled ancestors block underlying pointer targets and skip descendants in tab order" {
  let disabled = @reactive.signal(false)
  let clicks : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.stack([
        @controls.button(
          "behind",
          style=@controls.ButtonStyle().surface(control_test_style()),
          on_click=fn() { clicks.push("behind") },
        ),
        @view.column(
          [
            @controls.button(
              "front",
              style=@controls.ButtonStyle().surface(control_test_style()),
              on_click=fn() { clicks.push("front") },
            ),
          ],
          disabled~,
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  let point = @foundation.Point(x=10.0, y=10.0)
  assert_true(root.click_at(size~, point~))
  disabled.set(true)
  assert_false(root.click_at(size~, point~))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  root.paint(StyleRecorder(), size~)
  let snapshot = root.snapshot().unwrap()
  assert_true(snapshot.tree.nodes[2].disabled)
  assert_true(snapshot.tree.nodes[3].disabled)
  assert_eq(snapshot.focused_node_id, Some(snapshot.tree.nodes[1].id))
  disabled.set(false)
  assert_true(root.click_at(size~, point~))
  assert_eq(clicks, ["front", "behind", "front"])
}

///|
test "interactive property replaces the local source and ends keyboard presses on disable" {
  let first = @reactive.signal(false)
  let second = @reactive.signal(false)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @controls.button(
          "wrapped",
          style=@controls.ButtonStyle().surface(control_test_style()),
          on_click=fn() { clicks.val += 1 },
          disabled=first,
        ),
        disabled=second,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  root.paint(StyleRecorder(), size~)
  let before = root.snapshot().unwrap()
  // The explicit wrapper property replaced the child's local source.
  first.set(true)
  assert_false(root.needs_frame())
  assert_eq(root.snapshot(), Some(before))
  second.set(true)
  assert_false(root.key_up(test_key_event(KeySpace)))
  assert_false(root.key_down(test_key_event(KeyTab)))
  root.paint(StyleRecorder(), size~)
  first.set(false)
  assert_false(root.needs_frame())
  assert_false(root.key_down(test_key_event(KeyTab)))
  second.set(false)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[0].id, before.tree.nodes[0].id)
  assert_false(root.snapshot().unwrap().tree.nodes[0].state.pressed)
  assert_eq(clicks.val, 1)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(clicks.val, 2)
  let enabled = @controls.button("static", disabled=false)

  assert_true(enabled.is_enabled_path([]))
}

///|
test "equal disabled results remain idle snapshots are pure and removed bindings stop" {
  let source = @reactive.signal(0)
  let visible = @reactive.signal(true)
  let reads = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @controls.button(
          "conditional",
          disabled=@reactive.bind(fn() {
            reads.val += 1
            source.get() > 1
          }),
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  root.paint(StyleRecorder(), size~)
  let before = root.snapshot().unwrap()
  let snapshot_reads = reads.val
  assert_eq(root.snapshot(), Some(before))
  assert_eq(reads.val, snapshot_reads)
  source.set(1)
  assert_false(root.needs_frame())
  assert_eq(root.snapshot(), Some(before))
  source.set(2)
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(StyleRecorder(), size~)
  assert_true(root.snapshot().unwrap().tree.nodes[1].disabled)
  assert_false(before.tree.nodes[1].disabled)
  visible.set(false)
  root.paint(StyleRecorder(), size~)
  let detached_reads = reads.val
  source.set(0)
  assert_eq(reads.val, detached_reads)
  assert_false(root.needs_frame())
  visible.set(true)
  root.paint(StyleRecorder(), size~)
  assert_false(root.snapshot().unwrap().tree.nodes[1].disabled)
  root.dispose()
  let disposed_reads = reads.val
  source.set(3)
  assert_eq(reads.val, disposed_reads)
  assert_false(root.needs_frame())
}

///|
test "component instances evaluate disabled in each root and dispose subscriptions independently" {
  let key = @reactive.Context(@reactive.signal(true))
  let first = @reactive.signal(false)
  let second = @reactive.signal(true)
  let create = fn() {
    @controls.button(
      "shared",
      disabled=@reactive.bind(fn() { key.get().get() }),
    )
  }
  let one = @runtime.mount(
    create,
    providers=[key.provide(first)],
    text_layout_system=test_text_layout_system(),
  )
  defer one.dispose()
  let two = @runtime.mount(
    create,
    providers=[key.provide(second)],
    text_layout_system=test_text_layout_system(),
  )
  defer two.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  one.paint(StyleRecorder(), size~)
  two.paint(StyleRecorder(), size~)
  assert_false(one.snapshot().unwrap().tree.nodes[0].disabled)
  assert_true(two.snapshot().unwrap().tree.nodes[0].disabled)
  assert_true(one.key_down(test_key_event(KeyTab)))
  assert_false(two.key_down(test_key_event(KeyTab)))
  one.dispose()
  second.set(false)
  assert_eq(two.dirty(), NeedsPaint)
  two.paint(StyleRecorder(), size~)
  assert_false(two.snapshot().unwrap().tree.nodes[0].disabled)
  assert_true(two.key_down(test_key_event(KeyTab)))
}

///|
test "custom hosts receive paint and disabled transition callbacks without layout work" {
  let disabled = @reactive.signal(false)
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let view = scope.run(fn() { @controls.button("host", disabled~) })
  let layouts = Ref(0)
  let paints = Ref(0)
  let changes : Array[Int32] = []
  let stop = scope.run(fn() {
    view.mount_reactivity(
      mark_layout_dirty=fn() { layouts.val += 1 },
      mark_paint_dirty=fn() { paints.val += 1 },
      on_disabled_change=fn(id) { changes.push(id) },
    )
  })
  disabled.set(true)
  assert_eq(layouts.val, 0)
  assert_eq(paints.val, 1)
  assert_eq(changes, [view.node_id_at_path([]).unwrap()])
  assert_false(view.is_enabled_path([]))
  stop()
  stop()
  disabled.set(false)
  assert_eq(paints.val, 1)
}

///|
test "disable during paint defers snapshots until disabled geometry and appearance agree" {
  let disabled = @reactive.signal(false)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if first.val {
              first.val = false
              disabled.set(true)
            }
          }),
        ),
        @controls.button(
          "paint",
          style=@controls.ButtonStyle().surface(control_test_style()),
          disabled~,
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=90.0)
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot(), None)
  assert_eq(root.dirty(), NeedsPaint)
  let before = root.frame_stats()
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  let node = root.snapshot().unwrap().tree.nodes[2]
  assert_true(node.disabled)
  assert_eq(node.computed_style.unwrap().background, Some(renderer.fills[0].0))
  assert_eq(root.frame_stats().layout_count, before.layout_count)
  assert_false(root.needs_frame())
}

///|
test "disabled blur sees a pending frame and cannot revive focus through observers" {
  let disabled = @reactive.signal(false)
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let blurs = Ref(0)
  let observations : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "blur",
        on_blur=fn() {
          let root = active.val.unwrap()
          observations.push(root.snapshot() is None)
          observations.push(!root.key_down(test_key_event(KeyTab)))
          blurs.val += 1
        },
        disabled~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  active.val = Some(root)
  assert_true(root.key_down(test_key_event(KeyTab)))
  let size = @foundation.Size(width=150.0, height=50.0)
  root.paint(StyleRecorder(), size~)
  let stop = root.observe_frames(fn(event) {
    if event is Invalidated(_) && disabled.peek() {
      disabled.set(false)
      observations.push(!root.key_down(test_key_event(KeyTab)))
    }
  })
  defer stop()
  disabled.set(true)
  assert_eq(blurs.val, 1)
  assert_eq(observations, [true, true, true])
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().focused_node_id, None)
}

///|
test "disabled scroll views use root context block wheel and cancel scrollbar capture" {
  let key = @reactive.Context(@reactive.signal(true))
  let disabled = @reactive.signal(false)
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.fill_box(300.0),
        offset~,
        disabled=@reactive.bind(fn() { key.get().get() }),
      )
    },
    providers=[key.provide(disabled)],
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=100.0)
  assert_true(
    root.scroll_at(
      size~,
      point=Point(x=20.0, y=20.0),
      delta=Point(x=0.0, y=30.0),
    ),
  )
  assert_eq(offset.get(), 30.0)
  root.paint(StyleRecorder(), size~)
  let bar = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar.unwrap()
  let point = @foundation.Point(
    x=bar.thumb.origin.x + 1.0,
    y=bar.thumb.origin.y + 1.0,
  )
  assert_true(root.pointer_down(size~, point~))
  disabled.set(true)
  assert_false(
    root.pointer_move(size~, point=Point(x=point.x, y=point.y + 20.0)),
  )
  assert_false(root.pointer_up(size~, point~))
  assert_false(
    root.scroll_at(
      size~,
      point=Point(x=20.0, y=20.0),
      delta=Point(x=0.0, y=40.0),
    ),
  )
  assert_eq(offset.get(), 30.0)
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().captured_node_id, None)
  disabled.set(false)
  assert_true(
    root.scroll_at(
      size~,
      point=Point(x=20.0, y=20.0),
      delta=Point(x=0.0, y=10.0),
    ),
  )
  assert_eq(offset.get(), 40.0)
}

///|
test "disabled sources materialize once and input paint snapshots do not call producers" {
  let source = @reactive.signal(0)
  let reads = Ref(0)
  let view = @controls.button(
    "cold",
    style=@controls.ButtonStyle().surface(control_test_style()),
    disabled=@reactive.bind(fn() {
      reads.val += 1
      source.get() > 1
    }),
  )
  assert_eq(reads.val, 0)
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(reads.val, 1)
  let size = @foundation.Size(width=150.0, height=50.0)
  let point = @foundation.Point(x=10.0, y=10.0)
  let renderer = StyleRecorder()
  for _ in 0..<3 {
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.pointer_down(size~, point~))
    assert_true(root.pointer_up(size~, point~))
    root.paint(renderer, size~)
    assert_true(root.snapshot() is Some(_))
    assert_eq(reads.val, 1)
  }
  source.set(1)
  assert_eq(reads.val, 2)
  assert_false(root.needs_frame())
  source.set(2)
  assert_eq(reads.val, 3)
  assert_false(root.key_down(test_key_event(KeyTab)))
  assert_false(root.click_at(size~, point~))
  root.paint(renderer, size~)
  assert_true(root.snapshot().unwrap().tree.nodes[0].disabled)
  assert_eq(reads.val, 3)
}

///|
test "all disabled properties commit before invalidation observers can dispatch input" {
  let disabled = @reactive.signal(false)
  let title = @reactive.signal("before")
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text(
          @reactive.bind(fn() { title.get() }),
          style=@view.TextStyle().frame(@style.BoxStyle().height(20.0)),
        ),
        @controls.button(
          "one",
          disabled~,
          style=@controls.ButtonStyle().surface(control_test_style()),
        ),
        @controls.button(
          "two",
          disabled~,
          style=@controls.ButtonStyle().surface(control_test_style()),
          on_click=fn() { clicks.val += 1 },
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=120.0)
  root.paint(StyleRecorder(), size~)
  let node = root.snapshot().unwrap().tree.nodes[3]
  let point = @foundation.Point(
    x=node.frame.origin.x + 5.0,
    y=node.frame.origin.y + 5.0,
  )
  let blocked : Array[Bool] = []
  let stop = root.observe_frames(fn(event) {
    if event is Invalidated(_) && disabled.peek() {
      blocked.push(!root.click_at(size~, point~))
    }
  })
  defer stop()
  @reactive.batch(fn() {
    title.set("after")
    disabled.set(true)
  })
  assert_true(!blocked.is_empty())
  assert_true(blocked.all(value => value))
  assert_eq(clicks.val, 0)
  root.paint(StyleRecorder(), size~)
  assert_true(root.snapshot().unwrap().tree.nodes[2].disabled)
  assert_true(root.snapshot().unwrap().tree.nodes[3].disabled)
}

///|
test "a frame wakeup survives removal of the source that first requested it" {
  let disabled = @reactive.signal(false)
  let visible = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @controls.button("gone", disabled~)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  root.paint(StyleRecorder(), size~)
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  @reactive.batch(fn() {
    disabled.set(true)
    visible.set(false)
  })
  assert_eq(wakeups.val, 1)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(StyleRecorder(), size~)
  disabled.set(false)
  assert_false(root.needs_frame())
  assert_eq(wakeups.val, 1)
}
