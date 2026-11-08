///|
// This component uses only public primitive APIs, as an external library would.
fn external_toggle(
  label : &@value.StringValue,
  disabled~ : &@value.BoolValue = false,
  on_change~ : (@foundation.ChangeEvent[Bool]) -> Unit = fn(_) { () },
) -> @view.View {
  let state = @reactive.signal(false)
  let label = @view.TextContent(label)
  let activate = fn() {
    let value = state
    let next = !value.peek()
    ignore(
      @view.dispatch_change(label.id, next, Some(on_change), fn() {
        value.set(next)
      }),
    )
  }
  @view.element(
    component_name="Toggle",
    style=@style.BoxStyle().width(100.0).height(40.0),
    measure=fn(context) {
      @view.text_measure(label.get(), context.font, context.text_layout_system)
    },
    painter=@view.Painter(fn(context, frame) {
      let text = label.get() + (if state.peek() { ":on" } else { ":off" })
      context.draw_text(
        text,
        frame,
        context.font,
        context.theme.resolve(@style.text_token),
        TextStart,
      )
    }),
    events=@view.ElementEvents(
      focusable=true,
      editable=true,
      disabled~,
      on_click=activate,
      handle_key_down=fn(event) {
        if event.key is KeySpace {
          activate()
          KeyActivated
        } else {
          KeyIgnored
        }
      },
    ),
    reactivity=@view.Reactivity::paint(fn() { ignore(state.get()) }).with_text(
      label,
    ),
  )
}

///|
fn extension_system() -> @text.TextLayoutSystem {
  @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      let length = input.text.char_length()
      TextMetrics(
        width=length.to_double() * 8.0,
        line_height=20.0,
        baseline=15.0,
        caret_positions=Array::makei(length + 1, i => i.to_double() * 8.0),
      )
    }),
  )
}

///|
struct ExtensionRecorder {
  text : Ref[String]
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn clear(_, _) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn fill_rect(_, _, _) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn stroke_rect(
  _,
  _,
  _,
  _,
) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn fill_rounded_rect(
  _,
  _,
  _,
) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn stroke_rounded_rect(
  _,
  _,
  _,
  _,
) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn push_clip(_, _) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn pop_clip(_) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn draw_image(_, _, _) {
  ()
}

///|
impl @foundation.SceneRenderer for ExtensionRecorder with fn draw_text(
  self,
  run,
) {
  self.text.val = run.text
}

///|
test "an external control shares primitive lifecycle input and reactive text contracts" {
  let reads = Ref(0)
  let title = @reactive.signal("before")
  let create = fn() {
    external_toggle(
      @reactive.bind(fn() {
        reads.val += 1
        title.get()
      }),
    )
  }
  assert_eq(reads.val, 0)
  let first = @runtime.mount(create, text_layout_system=extension_system())
  defer first.dispose()
  let second = @runtime.mount(create, text_layout_system=extension_system())
  defer second.dispose()
  assert_eq(reads.val, 2)
  let size = @foundation.Size(width=100.0, height=40.0)
  let recorder = ExtensionRecorder::{ text: Ref(""), }
  first.paint(recorder, size~)
  assert_eq(recorder.text.val, "before:off")
  let before = first.frame_stats().layout_count
  assert_true(first.click_at(size~, point=Point(x=10.0, y=10.0)))
  first.paint(recorder, size~)
  assert_eq(recorder.text.val, "before:on")
  assert_eq(first.frame_stats().layout_count, before)
  second.paint(recorder, size~)
  assert_eq(recorder.text.val, "before:off")
  assert_eq(reads.val, 2)
  assert_true(second.key_down(KeyEvent(key=KeyTab)))
  assert_true(second.key_down(KeyEvent(key=KeySpace)))
  second.paint(recorder, size~)
  assert_eq(recorder.text.val, "before:on")
  title.set("after")
  first.paint(recorder, size~)
  assert_eq(recorder.text.val, "after:on")
  assert_eq(first.frame_stats().layout_count, before + 1)
  assert_eq(reads.val, 4)
  first.dispose()
  title.set("live")
  second.paint(recorder, size~)
  assert_eq(recorder.text.val, "live:on")
  assert_eq(reads.val, 5)
}

///|
test "external change proposals revalidate disabled state independently of component name" {
  let blocked = @reactive.signal(false)
  let proposals = Ref(0)
  let root = @runtime.mount(
    fn() {
      external_toggle("value", disabled=blocked, on_change=fn(_) {
        proposals.val += 1
        blocked.set(true)
      })
    },
    text_layout_system=extension_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=40.0)
  let recorder = ExtensionRecorder::{ text: Ref(""), }
  root.paint(recorder, size~)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  root.paint(recorder, size~)
  assert_eq(proposals.val, 1)
  assert_eq(recorder.text.val, "value:off")
  assert_eq(root.snapshot().unwrap().tree.nodes[0].component_name, "Toggle")
  assert_false(root.click_at(size~, point=Point(x=10.0, y=10.0)))
}

///|
test "a pointer-only element shares applied style geometry and opts into diagnostics" {
  let width = @reactive.signal(80.0)
  let paints = Ref(0)
  let pointer : Ref[(@foundation.Point, @foundation.Size, @foundation.Insets)?] = Ref(
    None,
  )
  let padding = @foundation.Insets::all(6.0)
  let color = @foundation.Color::accent()
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          component_name="Checkbox",
          style=@style.BoxStyle().width(width).height(30.0).padding(padding),
          painter=@view.Painter(fn(context, frame) {
            paints.val += 1
            context.fill_box(frame, color, 0.0)
          }).with_computed_style(fn(context) {
            @diagnostics.ComputedStyle(
              background=color,
              radius=context.frame.size.width,
              indicator_size=context.content.size,
              spacing=3.0,
            )
          }),
          events=@view.ElementEvents(handle_pointer_down=fn(context) {
            pointer.val = Some(
              (context.position, context.size, context.padding),
            )
          }),
        ),
      ])
    },
    text_layout_system=extension_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=80.0)
  let recorder = ExtensionRecorder::{ text: Ref(""), }
  root.paint(recorder, size~)
  let before = root.snapshot().unwrap()
  assert_eq(
    before.tree.nodes[1].computed_style.unwrap().background,
    Some(color),
  )
  assert_eq(before.tree.nodes[1].component_name, "Checkbox")
  let computed = before.tree.nodes[1].computed_style.unwrap()
  assert_eq(computed.radius, Some(80.0))
  assert_eq(computed.indicator_size, Some(before.tree.nodes[1].content.size))
  assert_eq(computed.spacing, Some(3.0))
  assert_eq(before.tree.nodes[1].frame.size.width, 80.0)
  assert_false(before.tree.nodes[1].focusable)
  assert_true(before.tree.nodes[1].hit_testable)
  assert_eq(paints.val, 1)
  assert_eq(root.snapshot(), Some(before))
  assert_eq(paints.val, 1)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=12.0)))
  assert_eq(
    pointer.val,
    Some((Point(x=10.0, y=12.0), Size(width=80.0, height=30.0), padding)),
  )
  ignore(root.pointer_up(size~, point=Point(x=10.0, y=12.0)))
  width.set(120.0)
  root.paint(recorder, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.tree.nodes[1].id, before.tree.nodes[1].id)
  assert_eq(after.tree.nodes[1].frame.size.width, 120.0)
  assert_eq(after.frame.layout_count, before.frame.layout_count + 1)
}
