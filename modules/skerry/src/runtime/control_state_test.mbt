///|
fn control_test_style() -> @style.BoxStyle {
  @style.BoxStyle()
  .width(100.0)
  .height(40.0)
  .shrink(0.0)
  .hovered(
    @style.Appearance().background(@foundation.Color::rgb(r=10, g=20, b=30)),
  )
  .focused(@style.Appearance().stroke(@foundation.Color::black(), width=3.0))
  .pressed(
    @style.Appearance().background(@foundation.Color::rgb(r=60, g=70, b=80)),
  )
  .pressed(
    @style.Appearance().color(@foundation.Color::rgb(r=90, g=100, b=110)),
  )
  .pressed(
    @style.Appearance().stroke(
      @foundation.Color::rgb(r=120, g=130, b=140),
      width=4.0,
    ),
  )
  .disabled(
    @style.Appearance().background(@foundation.Color::rgb(r=150, g=160, b=170)),
  )
  .disabled(
    @style.Appearance().color(@foundation.Color::rgb(r=180, g=190, b=200)),
  )
  .disabled(@style.Appearance().stroke(@foundation.Color::black(), width=0.0))
}

///|
fn state_test_control(
  kind : Int32,
  style : @style.BoxStyle,
  disabled : &@value.BoolValue,
) -> @view.View {
  match kind {
    0 =>
      @controls.button(
        "button",
        style=@controls.ButtonStyle().surface(style),
        on_click=fn() { () },
        disabled~,
      )
    1 =>
      @controls.checkbox(
        label="checkbox",
        style=@controls.CheckboxStyle().frame(style),
        disabled~,
      )
    2 =>
      @controls.radio(
        label="radio",
        style=@controls.RadioStyle().frame(style),
        disabled~,
      )
    _ =>
      @controls.text_input(
        value=@reactive.signal("value"),
        style=@controls.TextInputStyle().surface(style),
        disabled~,
      )
  }
}

///|
test "all built-in controls share state palettes and paint-only pointer transitions" {
  for kind in 0..<4 {
    let measures = Ref(0)
    let style = control_test_style()
    let root = @runtime.mount(
      fn() { state_test_control(kind, style, false) },
      text_layout_system=test_text_layout_system(on_measure=fn() {
        measures.val += 1
      }),
    )
    defer root.dispose()
    let size = @foundation.Size(width=150.0, height=50.0)
    let renderer = StyleRecorder()
    root.paint(renderer, size~)
    let baseline = root.frame_stats()
    let measured = measures.val
    let before = root.snapshot().unwrap().tree.nodes[0]
    let frame = before.frame
    ignore(root.pointer_move(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(root.dirty(), NeedsPaint)
    root.paint(renderer, size~)
    let hovered = root.snapshot().unwrap().tree.nodes[0]
    assert_true(hovered.state.hovered)
    assert_false(hovered.state.pressed)
    assert_eq(hovered.specified_style, before.specified_style)
    assert_eq(renderer.fills[0].0, @foundation.Color::rgb(r=10, g=20, b=30))
    // Moving within the same target causes no frame request.
    ignore(root.pointer_move(size~, point=Point(x=11.0, y=11.0)))
    assert_eq(root.dirty(), Clean)
    assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(root.dirty(), NeedsPaint)
    root.paint(renderer, size~)
    let pressed = root.snapshot().unwrap().tree.nodes[0]
    assert_true(
      pressed.state.hovered && pressed.state.pressed && pressed.state.focused,
    )
    let palette = pressed.computed_style.unwrap()
    assert_eq(
      palette.background,
      Some(@foundation.Color::rgb(r=60, g=70, b=80)),
    )
    assert_eq(palette.color, Some(@foundation.Color::rgb(r=90, g=100, b=110)))
    assert_eq(
      palette.stroke_color,
      Some(@foundation.Color::rgb(r=120, g=130, b=140)),
    )
    assert_eq(palette.stroke_width, Some(4.0))
    assert_eq(palette.background, Some(renderer.fills[0].0))
    assert_eq(palette.color, Some(renderer.text[0].color))
    assert_eq(palette.stroke_color, Some(renderer.strokes[0].0))
    assert_eq(palette.stroke_width, Some(renderer.strokes[0].1))
    assert_true(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(root.dirty(), NeedsPaint)
    root.paint(renderer, size~)
    let released = root.snapshot().unwrap().tree.nodes[0]
    assert_false(released.state.pressed)
    assert_true(released.state.hovered && released.state.focused)
    assert_eq(released.computed_style.unwrap().stroke_width, Some(3.0))
    root.pointer_leave()
    root.paint(renderer, size~)
    assert_false(root.snapshot().unwrap().tree.nodes[0].state.hovered)
    assert_eq(root.frame_stats().layout_count, baseline.layout_count)
    assert_eq(root.frame_stats().layout_pass_count, baseline.layout_pass_count)
    assert_eq(root.snapshot().unwrap().tree.nodes[0].frame, frame)
    assert_eq(measures.val, measured)
    assert_eq(root.frame_stats().last_paint.unwrap().layout_count, 0)
  }
}

///|
test "dragging outside clears pressed but retains capture and never activates another node" {
  let clicks : Array[Int32] = []
  let root = @runtime.mount(
    fn() {
      @view.column(
        Array::makei(2, index => {
          @controls.button(
            "button",
            style=@controls.ButtonStyle().surface(control_test_style()),
            on_click=fn() { clicks.push(index) },
          )
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=100.0)
  let renderer = StyleRecorder()
  let inside = @foundation.Point(x=10.0, y=10.0)
  let other = @foundation.Point(x=10.0, y=50.0)
  assert_true(root.pointer_down(size~, point=inside))
  root.pointer_leave()
  root.paint(renderer, size~)
  assert_false(root.snapshot().unwrap().tree.nodes[1].state.pressed)
  assert_true(root.pointer_move(size~, point=other))
  root.paint(renderer, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_false(nodes[1].state.hovered || nodes[1].state.pressed)
  assert_true(nodes[2].state.hovered)
  assert_false(nodes[2].state.pressed)
  assert_true(root.pointer_move(size~, point=inside))
  root.paint(renderer, size~)
  assert_true(root.snapshot().unwrap().tree.nodes[1].state.pressed)
  assert_true(root.pointer_up(size~, point=other))
  assert_eq(clicks, [])
  assert_true(root.pointer_down(size~, point=inside))
  assert_true(root.pointer_cancel())
  root.paint(renderer, size~)
  assert_false(root.snapshot().unwrap().tree.nodes[1].state.pressed)
  assert_true(root.snapshot().unwrap().tree.nodes[1].state.hovered)
  assert_false(root.pointer_up(size~, point=inside))
  assert_true(root.pointer_down(size~, point=inside))
  assert_true(root.pointer_up(size~, point=inside))
  assert_eq(clicks, [0])
  root.focus_lost()
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].state, ControlState())
}

///|
test "activation key press is paint-only and ends on matching keyup blur and removal" {
  let visible = @reactive.signal(true)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @controls.button(
          "button",
          style=@controls.ButtonStyle().surface(control_test_style()),
          on_click=fn() { clicks.val += 1 },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  let renderer = StyleRecorder()
  root.paint(renderer, size~)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  let baseline = root.frame_stats().layout_count
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_eq(clicks.val, 1)
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  let state = root.snapshot().unwrap().tree.nodes[1].state
  assert_true(state.pressed && state.focused)
  assert_false(state.hovered)
  assert_false(root.key_up(test_key_event(KeyEnter)))
  assert_true(root.key_up(test_key_event(KeySpace)))
  root.paint(renderer, size~)
  assert_false(root.snapshot().unwrap().tree.nodes[1].state.pressed)
  assert_eq(clicks.val, 1)
  assert_eq(root.frame_stats().layout_count, baseline)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  root.focus_lost()
  assert_false(root.key_up(test_key_event(KeyEnter)))
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].state, ControlState())
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  visible.set(false)
  assert_false(root.key_up(test_key_event(KeyEnter)))
  visible.set(true)
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].state, ControlState())
}

///|
test "disabled appearance wins for local and ancestor disabled controls" {
  for kind in 0..<4 {
    for inherited in [false, true] {
      let root = @runtime.mount(
        fn() {
          let control = state_test_control(
            kind,
            control_test_style(),
            !inherited,
          )
          if inherited {
            @view.interactive(control, disabled=true)
          } else {
            control
          }
        },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let size = @foundation.Size(width=150.0, height=50.0)
      let renderer = StyleRecorder()
      root.paint(renderer, size~)
      let layouts = root.frame_stats().layout_count
      ignore(root.pointer_move(size~, point=Point(x=10.0, y=10.0)))
      assert_false(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
      assert_false(root.key_down(test_key_event(KeyTab)))
      root.paint(renderer, size~)
      let node = root.snapshot().unwrap().tree.nodes[0]
      assert_eq(node.state, ControlState(disabled=true))
      assert_eq(
        renderer.fills[0].0,
        @foundation.Color::rgb(r=150, g=160, b=170),
      )
      assert_eq(
        renderer.text[0].color,
        @foundation.Color::rgb(r=180, g=190, b=200),
      )
      assert_eq(
        node.computed_style.unwrap().background,
        Some(renderer.fills[0].0),
      )
      assert_eq(
        node.computed_style.unwrap().color,
        Some(renderer.text[0].color),
      )
      assert_eq(node.computed_style.unwrap().stroke_width, Some(0.0))
      assert_eq(renderer.strokes.length(), 0)
      assert_eq(root.frame_stats().layout_count, layouts)
    }
  }
}

///|
test "default disabled palette fades descendants and only action controls shade their background" {
  for kind in 0..<4 {
    let style = @style.BoxStyle().width(100.0).height(40.0)
    let normal = fn() { state_test_control(kind, style, false) }
    let enabled = @runtime.mount(
      normal,
      text_layout_system=test_text_layout_system(),
    )
    defer enabled.dispose()
    let disabled = @runtime.mount(
      fn() { @view.interactive(@view.column([normal()]), disabled=true) },
      text_layout_system=test_text_layout_system(),
    )
    defer disabled.dispose()
    let size = @foundation.Size(width=150.0, height=50.0)
    let renderer = StyleRecorder()
    disabled.paint(renderer, size~)
    let node = disabled.snapshot().unwrap().tree.nodes[1]
    assert_true(node.state.disabled)
    assert_eq(node.computed_style.unwrap().background.unwrap().a, 0.45)
    assert_eq(node.computed_style.unwrap().color.unwrap().a, 0.45)
    assert_eq(renderer.fills[0].0.a, 0.45)
    enabled.paint(renderer, size~)
    let base = renderer.fills[0].0
    ignore(enabled.pointer_move(size~, point=Point(x=10.0, y=10.0)))
    enabled.paint(renderer, size~)
    let hover = renderer.fills[0].0
    if kind == 3 {
      assert_eq(hover, base)
    } else {
      assert_true(base != hover)
    }
    assert_true(enabled.pointer_down(size~, point=Point(x=10.0, y=10.0)))
    enabled.paint(renderer, size~)
    if kind == 3 {
      assert_eq(renderer.fills[0].0, base)
      assert_eq(renderer.strokes[0].0, @style.Palette().accent)
      assert_eq(renderer.strokes[0].1, 1.0)
      assert_eq(renderer.strokes[1].0, @style.Palette().accent)
      assert_eq(renderer.strokes[1].1, 2.0)
    } else {
      assert_true(renderer.fills[0].0 != hover)
    }
  }
}

///|
test "component instances have independent pointer keyboard and focus states in two roots" {
  let create = fn() {
    @controls.button(
      "shared",
      style=@controls.ButtonStyle().surface(control_test_style()),
      on_click=fn() { () },
    )
  }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  let renderer = StyleRecorder()
  assert_true(first.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  first.paint(renderer, size~)
  second.paint(renderer, size~)
  assert_true(first.snapshot().unwrap().tree.nodes[0].state.pressed)
  assert_eq(second.snapshot().unwrap().tree.nodes[0].state, ControlState())
  assert_true(
    first.snapshot().unwrap().tree.nodes[0].id !=
    second.snapshot().unwrap().tree.nodes[0].id,
  )
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(second.key_down(test_key_event(KeySpace)))
  second.paint(renderer, size~)
  first.focus_lost()
  first.paint(renderer, size~)
  assert_eq(first.snapshot().unwrap().tree.nodes[0].state, ControlState())
  assert_true(second.snapshot().unwrap().tree.nodes[0].state.pressed)
  first.dispose()
  assert_true(second.key_up(test_key_event(KeySpace)))
  second.paint(renderer, size~)
  assert_true(second.snapshot().unwrap().tree.nodes[0].state.focused)
  assert_false(second.snapshot().unwrap().tree.nodes[0].state.pressed)
}

///|
test "stationary pointer follows scroll geometry and never hovers content through the scrollbar" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column(
          Array::makei(3, _ => {
            @controls.button(
              "button",
              style=@controls.ButtonStyle().surface(
                @style.BoxStyle().height(40.0).shrink(0.0),
              ),
            )
          }),
        ),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=50.0)
  let renderer = StyleRecorder()
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  root.paint(renderer, size~)
  let layouts = root.frame_stats().layout_count
  assert_true(root.snapshot().unwrap().tree.nodes[2].state.pressed)
  offset.set(40.0)
  root.paint(renderer, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_false(nodes[2].state.hovered || nodes[2].state.pressed)
  assert_true(nodes[3].state.hovered)
  assert_false(nodes[3].state.pressed)
  assert_true(root.pointer_move(size~, point=Point(x=95.0, y=10.0)))
  root.paint(renderer, size~)
  for node in root.snapshot().unwrap().tree.nodes {
    assert_false(node.state.hovered || node.state.pressed)
  }
  assert_true(root.pointer_up(size~, point=Point(x=95.0, y=10.0)))
  assert_eq(root.frame_stats().layout_count, layouts)
}

///|
test "keyed reorder and removal reconcile hovered and pressed node identities" {
  let keys = @reactive.signal([1, 2])
  let clicks : Array[Int32] = []
  let cancelled = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.for_each(fn() { keys.get() }, fn(key) { key }, fn(key) {
        @controls.button(
          "button",
          style=@controls.ButtonStyle().surface(control_test_style()),
          on_click=fn() { clicks.push(key()) },
          on_pointer_cancel=fn() { cancelled.val += 1 },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=100.0)
  let renderer = StyleRecorder()
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  root.paint(renderer, size~)
  let id = root.snapshot().unwrap().tree.nodes[1].id
  keys.set([2, 1])
  root.paint(renderer, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[2].id, id)
  assert_true(nodes[2].state.focused)
  assert_false(nodes[2].state.pressed || nodes[2].state.hovered)
  assert_true(nodes[1].state.hovered)
  assert_false(nodes[1].state.pressed)
  assert_true(root.pointer_move(size~, point=Point(x=10.0, y=50.0)))
  root.paint(renderer, size~)
  assert_true(root.snapshot().unwrap().tree.nodes[2].state.pressed)
  keys.set([2])
  root.paint(renderer, size~)
  assert_eq(cancelled.val, 1)
  assert_false(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(clicks, [])
  root.paint(renderer, size~)
  assert_false(root.snapshot().unwrap().tree.nodes[1].state.pressed)
}

///|
test "disabling a mounted shared control ends its press and reenabling retains only pointer hover" {
  let disabled = @reactive.signal(false)
  let cancels = Ref(0)
  let shared = @controls.button(
    "button",
    style=@controls.ButtonStyle().surface(control_test_style()),
    on_click=fn() { () },
    on_pointer_cancel=fn() { cancels.val += 1 },
  )
  let root = @runtime.mount(
    fn() {
      @view.show(
        fn() {
          ignore(disabled.get())
          true
        },
        fn() { @view.interactive(shared, disabled~) },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  root.paint(renderer, size~)
  disabled.set(true)
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[1].state,
    ControlState(disabled=true),
  )
  assert_eq(cancels.val, 1)
  assert_false(root.key_up(test_key_event(KeyEnter)))
  assert_false(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
  disabled.set(false)
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[1].state,
    ControlState(hovered=true),
  )
}

///|
test "hover projection follows resize translation clipping and z order" {
  let root = @runtime.mount(
    fn() {
      @view.row([
        @controls.button(
          "first",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().grow(1.0).min_width(0.0),
          ),
        ),
        @controls.button(
          "second",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().grow(1.0).min_width(0.0),
          ),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  ignore(
    root.pointer_move(
      size=Size(width=100.0, height=50.0),
      point=Point(x=75.0, y=10.0),
    ),
  )
  root.paint(renderer, size=Size(width=100.0, height=50.0))
  assert_true(root.snapshot().unwrap().tree.nodes[2].state.hovered)
  root.paint(renderer, size=Size(width=300.0, height=50.0))
  assert_true(root.snapshot().unwrap().tree.nodes[1].state.hovered)
  assert_false(root.snapshot().unwrap().tree.nodes[2].state.hovered)
  let clipped = @runtime.mount(
    fn() {
      @view.stack([
        @controls.button(
          "under",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(100.0).height(40.0),
          ),
        ),
        @view.column(
          [
            @controls.button(
              "over",
              style=@controls.ButtonStyle().surface(
                @style.BoxStyle().width(100.0).height(40.0),
              ),
            ),
          ],
          style=@view.FlexStyle().surface(
            @style.BoxStyle().width(30.0).height(40.0),
          ),
        )
        .translated(Point(x=20.0, y=0.0))
        .clip(),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer clipped.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  ignore(clipped.pointer_move(size~, point=Point(x=25.0, y=10.0)))
  clipped.paint(renderer, size~)
  assert_true(clipped.snapshot().unwrap().tree.nodes[3].state.hovered)
  assert_false(clipped.snapshot().unwrap().tree.nodes[1].state.hovered)
  ignore(clipped.pointer_move(size~, point=Point(x=60.0, y=10.0)))
  clipped.paint(renderer, size~)
  assert_true(clipped.snapshot().unwrap().tree.nodes[1].state.hovered)
  assert_false(clipped.snapshot().unwrap().tree.nodes[3].state.hovered)
}

///|
test "custom painters see root-local state and snapshots read the last painted values" {
  let states : Array[@foundation.ControlState] = []
  let focused = Ref(false)
  let root = @runtime.mount(
    fn() {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(context, _) {
          focused.val = context.focused
          states.push(context.state)
        }),
        events=@view.ElementEvents(focusable=true, on_click=fn() { () }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  assert_true(root.snapshot() is None)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(before.tree.nodes[0].state, ControlState())
  assert_eq(after.tree.nodes[0].state, states[1])
  assert_eq(focused.val, states[1].focused)
  assert_true(after.tree.nodes[0].state.pressed)
  for _ in 0..<3 {
    ignore(root.snapshot())
  }
  assert_eq(states.length(), 2)
}
