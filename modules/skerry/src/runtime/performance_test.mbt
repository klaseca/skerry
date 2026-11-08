///|
fn performance_paint(root : @runtime.UiRoot, width~ : Double = 80.0) -> Unit {
  root.paint(
    TextRunRecorder::{ text: Ref(None), },
    size=Size(width~, height=100.0),
  )
}

///|
test "performance counts provider calls and actual reflow passes" {
  let measures = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text(
          "a long wrapped line",
          style=@view.TextStyle().frame(@style.BoxStyle().width(35.0)),
        ),
        @view.box(style=@style.BoxStyle().height(10.0)),
      ])
    },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      measures.val += 1
    }),
  )
  defer root.dispose()
  assert_eq(root.frame_stats().last_paint, None)
  performance_paint(root)
  let first = root.frame_stats()
  let paint = first.last_paint.unwrap()
  assert_eq(first.text_measure_count, measures.val)
  assert_true(first.text_measure_count > 1)
  assert_eq(first.layout_count, 1)
  assert_true(first.layout_pass_count > first.layout_count)
  assert_eq(paint.layout_count, first.layout_count)
  assert_eq(paint.layout_pass_count, first.layout_pass_count)
  assert_eq(paint.text_measure_count, first.text_measure_count)
  assert_eq(paint.layout_ms, None)
  assert_eq(paint.paint_ms, None)
  assert_true(root.snapshot() is Some(_))
  root.mark_paint_dirty()
  performance_paint(root)
  let second = root.frame_stats()
  assert_eq(second.layout_count, first.layout_count)
  assert_eq(second.layout_pass_count, first.layout_pass_count)
  assert_eq(second.text_measure_count, measures.val)
  let paint_only = second.last_paint.unwrap()
  assert_eq(paint_only.layout_count, 0)
  assert_eq(paint_only.layout_pass_count, 0)
  assert_eq(paint_only.text_measure_count, 0)
  assert_true(second.text_cache.layout_hits > first.text_cache.layout_hits)
  assert_eq(
    paint_only.text_measure_count,
    second.text_measure_count - first.text_measure_count,
  )
  performance_paint(root, width=120.0)
  assert_eq(root.frame_stats().layout_count, 2)
  assert_true(root.frame_stats().last_paint.unwrap().layout_pass_count > 0)
  assert_eq(first.last_paint, Some(paint))
}

///|
test "input layout contributes to totals but not cached paint work" {
  let measures = Ref(0)
  let root = @runtime.mount(
    fn() { @controls.button("test") },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      measures.val += 1
    }),
  )
  defer root.dispose()
  let size = @foundation.Size(width=80.0, height=100.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  let input = root.frame_stats()
  assert_eq(input.layout_count, 1)
  assert_true(input.layout_pass_count >= 1)
  assert_eq(input.text_measure_count, measures.val)
  assert_true(input.text_measure_count > 0)
  assert_eq(input.last_paint, None)
  performance_paint(root)
  let painted = root.frame_stats()
  assert_eq(painted.layout_count, input.layout_count)
  assert_eq(painted.layout_pass_count, input.layout_pass_count)
  assert_eq(painted.last_paint.unwrap().layout_count, 0)
  assert_eq(painted.last_paint.unwrap().layout_pass_count, 0)
  assert_eq(painted.text_measure_count, measures.val)
}

///|
test "separate roots sharing a metrics provider have independent counters" {
  let calls = Ref(0)
  let system = test_text_layout_system(on_measure=fn() { calls.val += 1 })
  let create = fn() { @view.text("shared text") }
  let first = @runtime.mount(create, text_layout_system=system)
  defer first.dispose()
  let second = @runtime.mount(create, text_layout_system=system)
  defer second.dispose()
  performance_paint(first)
  let first_stats = first.frame_stats()
  assert_eq(second.frame_stats().text_measure_count, 0)
  performance_paint(second, width=120.0)
  let second_stats = second.frame_stats()
  assert_eq(first.frame_stats(), first_stats)
  assert_eq(
    calls.val,
    first_stats.text_measure_count + second_stats.text_measure_count,
  )
  ignore(system.layout(TextLayoutInput(text="standalone")))
  assert_eq(system.measure_count(), 1)
  assert_eq(first.frame_stats(), first_stats)
  assert_eq(second.frame_stats(), second_stats)
}

///|
test "profiling excludes layout from drawing and observer time" {
  let now = Ref(0.0)
  let clocks = Ref(0)
  let measures = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text(
          "wrapped text",
          style=@view.TextStyle().frame(@style.BoxStyle().width(35.0)),
        ),
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) { now.val += 7.0 }),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      measures.val += 1
      now.val += 2.0
    }),
    clock=fn() {
      clocks.val += 1
      now.val
    },
  )
  defer root.dispose()
  let events : Array[@runtime.FrameEvent] = []
  let stop = root.observe_frames(
    fn(event) {
      events.push(event)
      now.val += 100.0
    },
    timings=true,
  )
  defer stop()
  assert_eq(clocks.val, 0)
  performance_paint(root)
  let stats = root.frame_stats()
  let paint = stats.last_paint.unwrap()
  assert_true(paint.layout_ms.unwrap() > 0.0)
  assert_true(paint.paint_ms.unwrap() >= 7.0)
  assert_eq(
    paint.layout_ms.unwrap() + paint.paint_ms.unwrap(),
    measures.val.to_double() * 2.0 + 7.0,
  )
  assert_eq(clocks.val, 4)
  assert_eq(events, [Painted(stats)])
  let before = (clocks.val, measures.val, now.val)
  for _ in 0..<3 {
    ignore(root.frame_stats())
    ignore(root.snapshot())
  }
  assert_eq((clocks.val, measures.val, now.val), before)
  root.record_present(stats.paint_count)
  root.record_present(stats.paint_count)
  assert_eq(clocks.val, before.0)
  assert_eq(measures.val, before.1)
  assert_eq(root.frame_stats().last_paint, stats.last_paint)
  assert_eq(root.frame_stats().present_count, 2)
  performance_paint(root)
  let next = root.frame_stats().last_paint.unwrap()
  assert_eq(next.layout_ms, Some(0.0))
  assert_eq(next.layout_count, 0)
  assert_eq(next.layout_pass_count, 0)
  assert_eq(
    next.paint_ms,
    Some(next.text_measure_count.to_double() * 2.0 + 7.0),
  )
}

///|
test "replacing and disposing profiling observers stops clock reads" {
  let clocks = Ref(0)
  let root = @runtime.mount(
    @view.empty,
    text_layout_system=test_text_layout_system(),
    clock=fn() {
      clocks.val += 1
      0.0
    },
  )
  defer root.dispose()
  performance_paint(root)
  assert_eq(clocks.val, 0)
  let first = root.observe_frames(fn(_) { () }, timings=true)
  let second = root.observe_frames(fn(_) { () }, timings=true)
  first()
  first()
  performance_paint(root)
  assert_eq(clocks.val, 2)
  assert_eq(root.frame_stats().last_paint.unwrap().paint_ms, Some(0.0))
  let plain = root.observe_frames(fn(_) { () })
  defer plain()
  second()
  performance_paint(root)
  assert_eq(clocks.val, 2)
  assert_eq(root.frame_stats().last_paint.unwrap().paint_ms, None)
  let timed = root.observe_frames(fn(_) { () }, timings=true)
  performance_paint(root)
  assert_eq(clocks.val, 4)
  timed()
  timed()
  performance_paint(root)
  assert_eq(clocks.val, 4)
  assert_eq(root.frame_stats().last_paint.unwrap().layout_ms, None)
  ignore(root.observe_frames(fn(_) { () }, timings=true))
  root.dispose()
  root.paint(
    TextRunRecorder::{ text: Ref(None), },
    size=Size(width=80.0, height=100.0),
  )
  assert_eq(clocks.val, 4)
}

///|
test "profiling clocks and diagnostic reads do not subscribe application effects" {
  let clock_signal = @reactive.signal(0.0)
  let clocks = Ref(0)
  let effects = Ref(0)
  let wakeups = Ref(0)
  let root = @runtime.mount(
    @view.empty,
    text_layout_system=test_text_layout_system(),
    clock=fn() {
      clocks.val += 1
      clock_signal.get()
    },
  )
  defer root.dispose()
  root.set_wakeup(fn() { wakeups.val += 1 })
  let stop = root.observe_frames(fn(_) { () }, timings=true)
  defer stop()
  let effect = @reactive.effect(fn() {
    effects.val += 1
    performance_paint(root)
    ignore(root.frame_stats())
    ignore(root.snapshot())
  })
  defer effect()
  assert_eq(effects.val, 1)
  assert_eq(wakeups.val, 0)
  let before = clocks.val
  clock_signal.set(1.0)
  assert_eq(effects.val, 1)
  assert_eq(clocks.val, before)
  assert_false(root.needs_frame())
  stop()
  assert_eq(wakeups.val, 0)
}

///|
test "changing profiling during paint suppresses partial times" {
  let now = Ref(0.0)
  let cancel : Ref[(() -> Unit)?] = Ref(None)
  let clocks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          now.val += 7.0
          if cancel.val is Some(stop) {
            stop()
          }
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
    clock=fn() {
      clocks.val += 1
      now.val
    },
  )
  defer root.dispose()
  let stop = root.observe_frames(fn(_) { () }, timings=true)
  cancel.val = Some(stop)
  performance_paint(root)
  let stats = root.frame_stats().last_paint.unwrap()
  assert_eq(stats.layout_ms, None)
  assert_eq(stats.paint_ms, None)
  assert_eq(stats.layout_count, 1)
  assert_eq(stats.layout_pass_count, 1)
  let before = clocks.val
  performance_paint(root)
  assert_eq(clocks.val, before)
}

///|
test "nested input layout during measurement is not timed twice" {
  let now = Ref(0.0)
  let calls = Ref(0)
  let first = Ref(true)
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let root = @runtime.mount(
    fn() { @view.text("nested layout") },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      calls.val += 1
      now.val += 1.0
      if first.val && root_ref.val is Some(root) {
        first.val = false
        ignore(
          root.click_at(
            size=Size(width=80.0, height=100.0),
            point=Point(x=5.0, y=5.0),
          ),
        )
      }
    }),
    clock=fn() { now.val },
  )
  defer root.dispose()
  root_ref.val = Some(root)
  let stop = root.observe_frames(fn(_) { () }, timings=true)
  defer stop()
  performance_paint(root)
  let stats = root.frame_stats()
  let paint = stats.last_paint.unwrap()
  assert_eq(stats.layout_count, 2)
  assert_eq(stats.text_measure_count, calls.val)
  assert_eq(paint.layout_count, 2)
  assert_eq(
    paint.layout_ms.unwrap() + paint.paint_ms.unwrap(),
    calls.val.to_double(),
  )
  assert_true(paint.paint_ms.unwrap() >= 0.0)
  assert_true(root.snapshot() is Some(_))
}

///|
test "disposal during paint does not replace the previous completed frame stats" {
  let dispose_next = Ref(false)
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let root = @runtime.mount(
    fn() {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          if dispose_next.val && root_ref.val is Some(root) {
            root.dispose()
          }
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  performance_paint(root)
  let before = root.frame_stats()
  dispose_next.val = true
  performance_paint(root)
  let after = root.frame_stats()
  assert_true(root.is_disposed())
  assert_eq(after.paint_count, before.paint_count)
  assert_eq(after.last_paint, before.last_paint)
}
