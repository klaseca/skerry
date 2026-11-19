///|
priv struct FixedOverlay {
  frame : @foundation.Rect
  behavior : @foundation.OverlayBehavior
}

///|
impl OverlayPolicy for FixedOverlay with fn layout(
  self,
  crater,
  _viewport,
  _anchor_width,
) {
  with_node_style(crater, force_size(crater.style, self.frame.size))
}

///|
impl OverlayPolicy for FixedOverlay with fn origin(
  self,
  _anchor,
  _size,
  _viewport,
) {
  self.frame.origin
}

///|
impl OverlayPolicy for FixedOverlay with fn contains(
  _self,
  surface,
  _trigger,
  point,
) {
  clip_contains(surface.clip.intersect(surface.frame), point) &&
  point.x >= surface.frame.origin.x + surface.frame.size.width * 0.5
}

///|
impl OverlayPolicy for FixedOverlay with fn behavior(self) {
  self.behavior
}

///|
fn policy_overlay(
  open : @reactive.Signal[Bool],
  behavior : @foundation.OverlayBehavior,
  content : () -> View,
) -> View {
  let (anchor, surface, state) = overlay_session(
    box(style=@style.BoxStyle().width(20.0).height(10.0)),
    Some(open),
    Manual,
    None,
    fn(_close) { content() },
  )
  overlay_view(
    anchor,
    surface,
    {
      policy: FixedOverlay::{
        frame: @foundation.Rect(x=80.0, y=40.0, width=110.0, height=60.0),
        behavior,
      },
      trigger: anchor.node,
      dismiss: fn() { state.change(false) },
    },
    "PolicyLayer",
  )
}

///|
fn policy_text_system() -> @text.TextLayoutSystem {
  @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      let length = input.text.char_length()
      TextMetrics(
        width=length.to_double() * 8.0,
        line_height=16.0,
        baseline=12.0,
        caret_positions=Array::makei(length + 1, i => i.to_double() * 8.0),
      )
    }),
  )
}

///|
test "an additional overlay policy controls layout position and dismissal geometry" {
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let frame = @foundation.Rect(x=80.0, y=40.0, width=110.0, height=60.0)
  let view = scope.run(fn() {
    let (anchor, surface, state) = overlay_session(
      box(style=@style.BoxStyle().width(20.0).height(10.0)),
      Some(@reactive.signal(true)),
      Manual,
      None,
      fn(_close) { empty() },
    )
    overlay_view(
      anchor,
      surface,
      {
        policy: FixedOverlay::{
          frame,
          behavior: @foundation.OverlayBehavior(),
        },
        trigger: anchor.node,
        dismiss: fn() { state.change(false) },
      },
      "FixedOverlay",
    )
  })
  let layout = LayoutState(
    text_layout_system=@text.TextLayoutSystem::from_metrics(
      TextMetricsProvider(measure=fn(_) {
        TextMetrics(width=0.0, line_height=10.0, baseline=8.0, caret_positions=[])
      }),
    ),
  )
  defer layout.dispose()
  let stop = scope.run(fn() {
    view.mount_reactivity(mark_layout_dirty=fn() { layout.invalidate() }, mark_paint_dirty=fn() {
      ()
    })
  })
  defer stop()
  let size = @foundation.Size(width=320.0, height=240.0)
  let target = view.overlay_targets()[0]
  let projection = layout.input_geometry(view, size)
  assert_eq(geometry_at_path(projection, target.path, 0).unwrap().frame, frame)
  assert_eq(target.behavior, @foundation.OverlayBehavior())
  let left = @foundation.Point(x=90.0, y=50.0)
  let right = @foundation.Point(x=180.0, y=50.0)
  for point in [left, right] {
    assert_eq(
      layout.hit_test(view, size~, point~).unwrap().node_id,
      target.node_id,
    )
  }
  assert_false(layout.overlay_contains(view, target, left, size~))
  assert_true(layout.overlay_contains(view, target, right, size~))
  assert_false(
    layout.overlay_contains(
      view,
      target,
      @foundation.Point(x=5.0, y=5.0),
      size~,
    ),
  )
}

///|
test "a nonblocking layer can consume Escape and pass outside presses without dismissing" {
  let open = @reactive.signal(true)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      column([
        @controls.button("background", on_click=fn() { clicks.val += 1 }),
        policy_overlay(
          open,
          @foundation.OverlayBehavior(focus=Cycle, escape=Consume),
          fn() { @controls.button("inside") },
        ),
      ])
    },
    text_layout_system=policy_text_system(),
  )
  defer root.dispose()
  assert_true(
    root.click_at(
      size=Size(width=320.0, height=240.0),
      point=Point(x=5.0, y=5.0),
    ),
  )
  assert_eq(clicks.val, 1)
  assert_true(open.get())
  assert_true(root.key_down(KeyEvent(key=KeyEscape)))
  assert_true(open.get())
  assert_true(root.key_down(KeyEvent(key=KeyEnter)))
  assert_eq(clicks.val, 2)
}

///|
test "pointer blocking can preserve background keyboard focus and cancels background capture" {
  let open = @reactive.signal(false)
  let value = @reactive.signal("")
  let cancels = Ref(0)
  let root = @runtime.mount(
    fn() {
      column([
        @controls.text_input(value~, on_pointer_cancel=fn() { cancels.val += 1 }),
        policy_overlay(
          open,
          @foundation.OverlayBehavior(pointer=BlockOutside),
          fn() { empty() },
        ),
      ])
    },
    text_layout_system=policy_text_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=320.0, height=240.0)
  let point = @foundation.Point(x=5.0, y=5.0)
  assert_true(root.pointer_down(size~, point~))
  open.set(true)
  assert_eq(cancels.val, 1)
  assert_true(root.text_input("a"))
  assert_false(root.pointer_up(size~, point~))
  assert_true(root.click_at(size~, point~))
  assert_true(root.text_input("b"))
  assert_eq(value.get(), "ab")
  assert_true(open.get())
}

///|
test "focus containment can permit background clicks without transferring or clearing focus" {
  let open = @reactive.signal(true)
  let value = @reactive.signal("")
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      column([
        @controls.button("background", on_click=fn() { clicks.val += 1 }),
        element(
          style=@style.BoxStyle().height(20.0),
          painter=Painter::empty(),
          events=ElementEvents(hit_testable=true, on_click=fn() {
            clicks.val += 1
          }),
        ),
        policy_overlay(
          open,
          @foundation.OverlayBehavior(focus=Contain, escape=Consume),
          fn() { @controls.text_input(value~) },
        ),
      ])
    },
    text_layout_system=policy_text_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=320.0, height=240.0)
  assert_true(root.text_input("a"))
  assert_true(root.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(clicks.val, 1)
  assert_true(root.text_input("b"))
  assert_true(root.click_at(size~, point=Point(x=5.0, y=40.0)))
  assert_eq(clicks.val, 2)
  assert_false(root.click_at(size~, point=Point(x=300.0, y=200.0)))
  assert_true(root.text_input("c"))
  assert_eq(value.get(), "abc")
  assert_true(root.key_down(KeyEvent(key=KeyTab)))
  assert_true(root.key_down(KeyEvent(key=KeyEscape)))
  assert_true(open.get())
}

///|
test "keyboard scope excludes later unrelated focus-taking overlays" {
  let open = @reactive.signal(true)
  let other = @reactive.signal(true)
  let value = @reactive.signal("")
  let root = @runtime.mount(
    fn() {
      column([
        policy_overlay(
          open,
          @foundation.OverlayBehavior(focus=Contain, escape=Dismiss),
          fn() { @controls.text_input(value~) },
        ),
        popup(@controls.button("other"), open=other, fn(_close) {
          @controls.button("entry")
        }),
      ])
    },
    text_layout_system=policy_text_system(),
  )
  defer root.dispose()
  assert_true(root.text_input("a"))
  assert_true(root.key_down(KeyEvent(key=KeyTab)))
  assert_true(root.text_input("b"))
  assert_eq(value.get(), "ab")
  assert_true(root.key_down(KeyEvent(key=KeyEscape)))
  assert_false(open.get())
  assert_true(other.get())
}

///|
test "ignored dismissal events continue to a lower layer" {
  for escape in [false, true] {
    let lower = @reactive.signal(true)
    let upper = @reactive.signal(true)
    let root = @runtime.mount(
      fn() {
        column([
          policy_overlay(
            lower,
            @foundation.OverlayBehavior(escape=Dismiss, outside_press=Dismiss),
            fn() { empty() },
          ),
          policy_overlay(upper, @foundation.OverlayBehavior(), fn() { empty() }),
        ])
      },
      text_layout_system=policy_text_system(),
    )
    defer root.dispose()
    if escape {
      assert_true(root.key_down(KeyEvent(key=KeyEscape)))
    } else {
      assert_true(
        root.click_at(
          size=Size(width=320.0, height=240.0),
          point=Point(x=300.0, y=200.0),
        ),
      )
    }
    assert_true(upper.get())
    assert_false(lower.get())
  }
}
