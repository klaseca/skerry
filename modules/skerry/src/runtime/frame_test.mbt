///|
test "signal changes during paint request another layout frame" {
  let value = @reactive.signal("before")
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if first.val {
              first.val = false
              value.set("after")
            }
          }),
        ),
        @view.text_of(value),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  assert_eq(root.dirty(), @runtime.NeedsLayout)
  root.paint(renderer, size~)
  assert_eq(root.dirty(), @runtime.Clean)
  assert_eq(renderer.text.val, Some("after"))
}

///|
test "paint-only signal changes during paint request another frame" {
  let selected = @reactive.signal(false)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if first.val {
              first.val = false
              selected.set(true)
            }
          }),
        ),
        @controls.checkbox(checked=selected),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  assert_eq(root.dirty(), @runtime.NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.dirty(), @runtime.Clean)
}

///|
test "frame requests coalesce and paint-only updates reuse layout" {
  let value = @reactive.signal("first")
  let checked = @reactive.signal(false)
  let root = @runtime.mount(
    fn() { @view.column([@view.text_of(value), @controls.checkbox(checked~)]) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  assert_true(root.needs_frame())
  root.paint(renderer, size~)
  let stats = root.frame_stats()
  assert_eq(stats.layout_count, 1)
  assert_eq(stats.paint_count, 1)
  assert_eq(stats.present_count, 0)
  assert_eq(stats.presented_frame, 0)
  @reactive.batch(fn() {
    value.set("second")
    value.set("third")
    checked.set(true)
  })
  assert_eq(root.dirty(), @runtime.NeedsLayout)
  assert_eq(root.paint_revision(), 1)
  root.paint(renderer, size~)
  assert_eq(renderer.text.val, Some("third"))
  assert_eq(root.frame_stats().layout_count, 2)
  assert_eq(root.paint_revision(), 2)
  checked.set(false)
  assert_eq(root.dirty(), @runtime.NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, 2)
  assert_eq(root.paint_revision(), 3)
  assert_false(root.needs_frame())
}

///|
test "invalidation during measurement does not restore a stale layout cache" {
  let value = @reactive.signal("first")
  let first = Ref(true)
  let root = @runtime.mount(
    fn() { @view.text_of(value) },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      if first.val {
        first.val = false
        value.set("updated during measurement")
      }
    }),
  )
  defer root.dispose()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=320.0, height=80.0)
  root.paint(renderer, size~)
  assert_eq(root.dirty(), @runtime.NeedsLayout)
  assert_eq(root.frame_stats().layout_count, 1)
  root.paint(renderer, size~)
  assert_eq(root.dirty(), @runtime.Clean)
  assert_eq(root.frame_stats().layout_count, 2)
  assert_eq(renderer.text.val, Some("updated during measurement"))
}

///|
test "recursive paint schedules another frame without reentering the painter" {
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let paints = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          paints.val += 1
          if paints.val == 1 && root_ref.val is Some(root) {
            root.paint(renderer, size~)
          }
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  root.paint(renderer, size~)
  assert_eq(paints.val, 1)
  assert_eq(root.paint_revision(), 1)
  assert_eq(root.dirty(), @runtime.NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(paints.val, 2)
  assert_eq(root.paint_revision(), 2)
  assert_false(root.needs_frame())
}

///|
test "frame observers distinguish painted and presented frames without extra work" {
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let events : Array[@runtime.FrameEvent] = []
  let stop = root.observe_frames(fn(event) { events.push(event) })
  defer stop()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  root.record_present(root.paint_revision())
  assert_eq(events, [
    @runtime.Painted(@runtime.FrameStats::{
      layout_count: 1,
      layout_pass_count: 1,
      text_measure_count: 0,
      text_cache: {
        enabled: true,
        measure_hits: 0,
        layout_hits: 0,
        measure_entries: 0,
        layout_entries: 0,
        payload_bytes: 0,
        evictions: 0,
      },
      paint_count: 1,
      present_count: 0,
      presented_frame: 0,
      last_paint: Some({
        layout_count: 1,
        layout_pass_count: 1,
        text_measure_count: 0,
        layout_ms: None,
        paint_ms: None,
      }),
    }),
    @runtime.Presented(@runtime.FrameStats::{
      layout_count: 1,
      layout_pass_count: 1,
      text_measure_count: 0,
      text_cache: {
        enabled: true,
        measure_hits: 0,
        layout_hits: 0,
        measure_entries: 0,
        layout_entries: 0,
        payload_bytes: 0,
        evictions: 0,
      },
      paint_count: 1,
      present_count: 1,
      presented_frame: 1,
      last_paint: Some({
        layout_count: 1,
        layout_pass_count: 1,
        text_measure_count: 0,
        layout_ms: None,
        paint_ms: None,
      }),
    }),
  ])
  root.mark_paint_dirty()
  root.paint(renderer, size~)
  root.record_present(1)
  assert_eq(root.frame_stats(), @runtime.FrameStats::{
    layout_count: 1,
    layout_pass_count: 1,
    text_measure_count: 0,
    text_cache: {
      enabled: true,
      measure_hits: 0,
      layout_hits: 0,
      measure_entries: 0,
      layout_entries: 0,
      payload_bytes: 0,
      evictions: 0,
    },
    paint_count: 2,
    present_count: 2,
    presented_frame: 1,
    last_paint: Some({
      layout_count: 0,
      layout_pass_count: 0,
      text_measure_count: 0,
      layout_ms: None,
      paint_ms: None,
    }),
  })
  // Wrapped frame labels are valid after the host presents their buffers.
  root.record_present(-1)
  assert_eq(root.frame_stats().presented_frame, -1)
  root.record_present(0)
  assert_eq(root.frame_stats().presented_frame, 0)
  assert_eq(root.frame_stats().present_count, 4)
  assert_true(events[events.length() - 1] is @runtime.Presented(_))
  let before = events.length()
  for _ in 0..<5 {
    ignore(root.frame_stats())
    assert_false(root.needs_frame())
  }
  assert_eq(events.length(), before)
  stop()
  stop()
  root.mark_layout_dirty()
  root.paint(renderer, size~)
  assert_eq(events.length(), before)
}

///|
test "frame observers isolate subscriptions and cleanup from application effects" {
  let trigger = @reactive.signal(0)
  let unrelated = @reactive.signal(0)
  let cleanups = Ref(0)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let stop_observer = root.observe_frames(fn(_) {
    ignore(unrelated.get())
    if first.val {
      first.val = false
      @reactive.on_cleanup(fn() { cleanups.val += 1 })
    }
  })
  defer stop_observer()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let stop_effect = @reactive.effect(fn() {
    ignore(trigger.get())
    root.paint(renderer, size=@foundation.Size(width=160.0, height=80.0))
  })
  defer stop_effect()
  unrelated.set(1)
  assert_eq(root.paint_revision(), 1)
  trigger.set(1)
  assert_eq(root.paint_revision(), 2)
  assert_eq(cleanups.val, 0)
  stop_observer()
  stop_observer()
  assert_eq(cleanups.val, 1)
  root.dispose()
  assert_eq(cleanups.val, 1)
}

///|
test "a replaced observer remains attached when the previous disposer runs" {
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let first_calls = Ref(0)
  let second_calls = Ref(0)
  let first = root.observe_frames(fn(_) { first_calls.val += 1 })
  defer first()
  let second = root.observe_frames(fn(_) { second_calls.val += 1 })
  defer second()
  first()
  root.paint(
    TextRunRecorder::{ text: Ref(None), },
    size=@foundation.Size(width=160.0, height=80.0),
  )
  assert_eq(first_calls.val, 0)
  assert_eq(second_calls.val, 1)
  root.dispose()
  root.mark_paint_dirty()
  root.record_present(1)
  assert_eq(second_calls.val, 1)
}

///|
test "an observer can request another frame without recursive notifications" {
  let root = @runtime.mount(
    fn() { @view.empty() },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let calls = Ref(0)
  let stop = root.observe_frames(fn(event) {
    calls.val += 1
    if event is @runtime.Painted(_) && calls.val == 1 {
      root.mark_paint_dirty()
    }
  })
  defer stop()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  assert_eq(calls.val, 1)
  assert_true(root.needs_frame())
  root.paint(renderer, size~)
  assert_eq(calls.val, 2)
  assert_false(root.needs_frame())
}

///|
test "disposing during paint cancels pending frames and diagnostic delivery" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let calls = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          if root_ref.val is Some(root) {
            root.mark_paint_dirty()
            root.dispose()
          }
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  let stop = root.observe_frames(fn(_) { calls.val += 1 })
  defer stop()
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  assert_true(root.is_disposed())
  assert_false(root.needs_frame())
  assert_eq(root.paint_revision(), 0)
  assert_eq(calls.val, 1)
  root.paint(renderer, size~)
  root.record_present(1)
  root.mark_layout_dirty()
  assert_eq(calls.val, 1)
}
