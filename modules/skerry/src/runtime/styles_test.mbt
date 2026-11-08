///|
struct StyleRecorder {
  fills : Array[(@foundation.Color, Double)]
  strokes : Array[(@foundation.Color, Double, Double)]
  text : Array[@foundation.TextRun]
}

///|
fn StyleRecorder::StyleRecorder() -> StyleRecorder {
  { fills: [], strokes: [], text: [], }
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn clear(self, _) {
  self.fills.clear()
  self.strokes.clear()
  self.text.clear()
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn fill_rect(
  self,
  _,
  color,
) {
  self.fills.push((color, 0.0))
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn fill_rounded_rect(
  self,
  rounded,
  color,
) {
  self.fills.push((color, rounded.radius))
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn stroke_rect(
  self,
  _,
  color,
  width,
) {
  self.strokes.push((color, width, 0.0))
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn stroke_rounded_rect(
  self,
  rounded,
  color,
  width,
) {
  self.strokes.push((color, width, rounded.radius))
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn draw_text(self, run) {
  self.text.push(run)
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn push_clip(_, _) {
  ()
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn pop_clip(_) {
  ()
}

///|
test "text declarations preserve text and frame properties while computed reports painted values" {
  let font = @foundation.FontSpec::default().size(21.0)
  let base = @style.BoxStyle()
    .font(font)
    .background(@foundation.Color::accent())
    .padding(@foundation.Insets::all(9.0))
    .width(80.0)
  let color = @foundation.Color::rgb(r=10, g=20, b=30)
  let style = base.merge(
    @style.BoxStyle().color(color).radius(0.0).width(120.0).align(TextEnd),
  )
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.text("text", style=@view.TextStyle().frame(style)).debug(
          name="text",
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let node = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(
    node.specified_style.unwrap().get(),
    Some(@view.TextStyle().frame(style)),
  )
  assert_eq(node.specified_style.unwrap().layout.layout.width, Some(120.0))
  assert_eq(node.frame.size.width, 200.0)
  assert_eq(node.padding, @foundation.Insets::all(9.0))
  let computed = node.computed_style.unwrap()
  assert_eq(computed.font, Some(font))
  assert_eq(computed.color, Some(renderer.text[0].color))
  assert_eq(computed.font, Some(renderer.text[0].font))
  assert_eq(computed.align, Some(TextEnd))
  assert_eq(computed.background, None)
  assert_eq(computed.spacing, None)
  assert_eq(computed.radius, None)
  assert_eq(renderer.fills.length(), 0)
  assert_eq(
    renderer.text[0].frame.origin.x,
    node.content.origin.x +
    node.content.size.width -
    renderer.text[0].frame.size.width,
  )
  assert_eq(node.debug_name, Some("text"))
}

///|
test "button defaults disabled colors padding and focus match renderer commands" {
  for disabled in [false, true] {
    let root = @runtime.mount(
      fn() { @controls.button("button", disabled~) },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let renderer = StyleRecorder()
    root.paint(renderer, size=Size(width=200.0, height=100.0))
    let node = root.snapshot().unwrap().tree.nodes[0]
    assert_eq(
      node.specified_style,
      Some(StyleDeclaration(@controls.ButtonStyle())),
    )
    assert_eq(
      node.padding,
      @foundation.Insets::symmetric(horizontal=12.0, vertical=8.0),
    )
    let computed = node.computed_style.unwrap()
    assert_eq(computed.background, Some(renderer.fills[0].0))
    assert_eq(computed.radius, Some(renderer.fills[0].1))
    assert_eq(computed.radius, Some(6.0))
    assert_eq(computed.color, Some(renderer.text[0].color))
    assert_eq(computed.font, Some(@foundation.FontSpec::default()))
    assert_eq(computed.align, Some(TextCenter))
    assert_eq(computed.stroke_color, None)
    assert_eq(computed.background.unwrap().a, if disabled { 0.45 } else { 1.0 })
    if !disabled {
      assert_true(root.key_down(test_key_event(KeyTab)))
      root.paint(renderer, size=Size(width=200.0, height=100.0))
      let focused = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
      assert_eq(focused.stroke_color, Some(renderer.strokes[0].0))
      assert_eq(focused.stroke_width, Some(renderer.strokes[0].1))
      assert_eq(root.frame_stats().layout_count, 1)
    }
  }
}

///|
test "checkbox paint only updates reuse layout and focus stroke is captured" {
  let checked = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @controls.checkbox(
        checked~,
        label="check",
        style=@controls.CheckboxStyle().frame(@style.BoxStyle().radius(3.0)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let initial = root.snapshot().unwrap()
  let palette = initial.tree.nodes[0].computed_style.unwrap()
  assert_eq(palette.background, Some(renderer.fills[0].0))
  assert_eq(palette.radius, Some(3.0))
  assert_eq(palette.stroke_color, Some(renderer.strokes[0].0))
  assert_eq(palette.stroke_width, Some(1.0))
  checked.set(true)
  assert_eq(root.dirty(), NeedsPaint)
  assert_true(root.snapshot() is None)
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let selected = root.snapshot().unwrap()
  assert_eq(selected.tree.nodes[0].computed_style, Some(palette))
  assert_eq(palette.marker_color, Some(renderer.fills[1].0))
  assert_eq(selected.frame.layout_count, 1)
  assert_eq(selected.frame.paint_count, 2)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let focused = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
  assert_eq(focused.stroke_color, Some(renderer.strokes[0].0))
  assert_eq(focused.stroke_width, Some(2.0))
  assert_eq(
    initial.tree.nodes[0].computed_style.unwrap().stroke_width,
    Some(1.0),
  )
  assert_eq(root.frame_stats().layout_count, 1)
}

///|
test "radio radius follows painted geometry and marker palette matches selected paint" {
  let root = @runtime.mount(
    fn() {
      @controls.radio(
        selected=@reactive.signal(true),
        style=@controls.RadioStyle().frame(
          @style.BoxStyle().radius(99.0).height(40.0),
        ),
        disabled=true,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  for height in [7.0, 30.0] {
    root.paint(renderer, size=Size(width=100.0, height~))
    let node = root.snapshot().unwrap().tree.nodes[0]
    let computed = node.computed_style.unwrap()
    assert_eq(node.specified_style.unwrap().layout.paint.radius, Some(99.0))
    assert_eq(node.specified_style.unwrap().layout.layout.height, Some(40.0))
    assert_eq(node.frame.size.height, height)
    assert_eq(computed.radius, Some(renderer.fills[0].1))
    assert_eq(computed.radius, Some(height.min(18.0) * 0.5))
    assert_eq(computed.marker_color, Some(renderer.fills[1].0))
    assert_eq(computed.stroke_color, Some(renderer.strokes[0].0))
  }
}

///|
test "text input distinguishes main text and placeholder palette without rereading value" {
  let value = @reactive.signal("")
  let color = @foundation.Color::accent()
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        placeholder="hint",
        style=@controls.TextInputStyle().surface(@style.BoxStyle().color(color)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let palette = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
  assert_eq(palette.color, Some(color))
  assert_eq(palette.placeholder_color, Some(renderer.text[0].color))
  assert_eq(palette.background, Some(renderer.fills[0].0))
  assert_eq(palette.stroke_color, Some(renderer.strokes[0].0))
  value.set("text")
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let populated = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
  assert_eq(populated, palette)
  assert_eq(populated.color, Some(renderer.text[0].color))
}

///|
test "container defaults spacing and decorators preserve specified styles through resize" {
  let style = @view.FlexStyle()
    .spacing(7.0)
    .padding(@foundation.Insets::all(4.0))
    .background(@foundation.Color::surface())
    .radius(5.0)
    .width(120.0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.column(
          [
            @view.stack([
              @view.box(
                style=@style.BoxStyle().background(@foundation.Color::accent()),
              ),
            ]),
          ],
          style~,
        ).debug(name="container"),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let mut id = None
  for width in [200.0, 300.0] {
    root.paint(renderer, size=Size(width~, height=100.0))
    let snapshot = root.snapshot().unwrap()
    let node = snapshot.tree.nodes[0]
    if id is Some(previous) {
      assert_eq(node.id, previous)
    } else {
      id = Some(node.id)
    }
    assert_eq(
      (node.specified_style.unwrap().get() : @view.FlexStyle?),
      Some(style),
    )
    assert_eq(node.frame.size.width, width)
    assert_eq(node.padding, @foundation.Insets::all(4.0))
    let computed = node.computed_style.unwrap()
    assert_eq(computed.spacing, Some(7.0))
    assert_eq(computed.background, Some(renderer.fills[0].0))
    assert_eq(computed.radius, Some(renderer.fills[0].1))
    assert_eq(computed.font, None)
    assert_eq(snapshot.tree.nodes[1].computed_style.unwrap().spacing, None)
    assert_eq(snapshot.tree.nodes[2].computed_style.unwrap().radius, Some(0.0))
  }
}

///|
test "computed style reads keep getters tracking and idle frames unchanged" {
  let text = @reactive.signal("text")
  let checked = @reactive.signal(false)
  let trigger = @reactive.signal(0)
  let getters = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text(
          @reactive.bind(fn() {
            getters.val += 1
            text.get()
          }),
        ),
        @controls.checkbox(checked~),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let read_count = getters.val
  let stats = root.frame_stats()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  let callbacks = Ref(0)
  let stop_observer = root.observe_snapshots(fn(_) { callbacks.val += 1 })
  defer stop_observer()
  let effects = Ref(0)
  let stop_effect = @reactive.effect(fn() {
    ignore(trigger.get())
    effects.val += 1
    ignore(root.snapshot())
  })
  defer stop_effect()
  for _ in 0..<3 {
    ignore(root.snapshot())
  }
  assert_eq(getters.val, read_count)
  assert_eq(root.frame_stats(), stats)
  assert_eq(wakeups.val, 0)
  assert_eq(callbacks.val, 1)
  assert_false(root.needs_frame())
  checked.set(true)
  text.set("updated")
  assert_eq(effects.val, 1)
  snapshot_paint(root)
  let after_paint = getters.val
  trigger.set(1)
  assert_eq(effects.val, 2)
  assert_eq(getters.val, after_paint)
}

///|
test "roots sharing a view retain independent painted focus styles" {
  let create = fn() { @controls.checkbox(label="shared") }
  let a = @runtime.mount(create, text_layout_system=test_text_layout_system())
  defer a.dispose()
  let b = @runtime.mount(create, text_layout_system=test_text_layout_system())
  defer b.dispose()
  assert_true(a.key_down(test_key_event(KeyTab)))
  snapshot_paint(a)
  snapshot_paint(b)
  assert_eq(
    a.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().stroke_width,
    Some(2.0),
  )
  assert_eq(
    b.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().stroke_width,
    Some(1.0),
  )
}

///|
test "a custom host can reuse its focus path without changing painted styles" {
  let view = @view.column([@controls.checkbox(label="check")])
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  let renderer = StyleRecorder()
  let focus = [0]
  state.paint(
    view,
    size=Size(width=200.0, height=100.0),
    renderer,
    focused_path=Some(focus),
  )
  let before = state.snapshot(view).unwrap()
  assert_eq(before.nodes[1].computed_style.unwrap().stroke_width, Some(2.0))
  focus[0] = 99
  assert_eq(state.snapshot(view), Some(before))
  state.invalidate()
  assert_true(state.snapshot(view) is None)
}

///|
test "paint callbacks keep declarations without inferred computed styles and ancestor disabling fades controls" {
  let calls = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.column([
          @view.element(
            style=@style.BoxStyle(),
            painter=@view.Painter(fn(_, _) { calls.val += 1 }),
          ),
          @controls.button("button"),
          @view.empty(),
          @view.show(fn() { false }, @view.empty),
          @view.for_each(fn() { [] }, fn(item : Int32) { item }, fn(_) {
            @view.empty()
          }),
        ]),
        disabled=true,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let snapshot = root.snapshot().unwrap()
  let declared : @style.BoxStyle? = snapshot.tree.nodes[1].specified_style
    .unwrap()
    .get()
  assert_eq(declared, Some(@style.BoxStyle()))
  assert_eq(snapshot.tree.nodes[1].computed_style, None)
  let button = snapshot.tree.nodes[2]
  assert_true(button.disabled)
  assert_eq(
    button.computed_style.unwrap().background,
    Some(renderer.fills[0].0),
  )
  assert_eq(button.computed_style.unwrap().background.unwrap().a, 0.45)
  assert_true(button.state.disabled)
  assert_eq(snapshot.tree.nodes[3].computed_style.unwrap().font, None)
  assert_eq(snapshot.tree.nodes[4].computed_style.unwrap().spacing, Some(0.0))
  assert_eq(snapshot.tree.nodes[5].computed_style.unwrap().spacing, Some(0.0))
  for _ in 0..<3 {
    ignore(root.snapshot())
  }
  assert_eq(calls.val, 1)
}

///|
impl @foundation.SceneRenderer for StyleRecorder with fn draw_image(
  _self,
  _image,
  _placement,
) {
  ()
}
