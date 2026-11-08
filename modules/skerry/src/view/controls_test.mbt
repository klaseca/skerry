///|
struct CheckboxPaintRecorder {
  accent_fills : Ref[Int32]
  text : Ref[String?]
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn clear(
  _self,
  _color,
) {
  ()
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn fill_rect(
  self,
  _rect,
  color,
) {
  if color == @foundation.Color::accent() {
    self.accent_fills.val = self.accent_fills.val + 1
  }
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn stroke_rect(
  _self,
  _rect,
  _color,
  _width,
) {
  ()
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn fill_rounded_rect(
  self,
  _rounded,
  color,
) {
  if color == @foundation.Color::accent() {
    self.accent_fills.val = self.accent_fills.val + 1
  }
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn stroke_rounded_rect(
  _self,
  _rounded,
  _color,
  _width,
) {
  ()
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn draw_text(
  self,
  run,
) {
  self.text.val = Some(run.text)
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn push_clip(
  _self,
  _rect,
) {
  ()
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn pop_clip(_self) {
  ()
}

///|
test "checkbox writes checked signal from pointer and keyboard" {
  let checked = @reactive.signal(false)
  let changes : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @controls.checkbox(checked~, label="Accept", on_change=fn(checked) {
        changes.push(checked.value)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=48.0)
  let first = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(first, size~)
  inspect(first.accent_fills.val, content="0")
  debug_inspect(first.text.val, content="Some(\"Accept\")")
  assert_true(root.click_at(size~, point=Point(x=8.0, y=8.0)))
  inspect(changes.length(), content="1")
  inspect(changes[0], content="true")
  inspect(checked.get(), content="true")
  assert_true(root.dirty() == NeedsPaint)
  let second = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(second, size~)
  inspect(second.accent_fills.val, content="1")
  assert_true(root.key_down(test_key_event(KeySpace)))
  inspect(changes.length(), content="2")
  inspect(changes[1], content="false")
  inspect(checked.get(), content="false")
  root.dispose()
}

///|
test "uncontrolled checkbox keeps local checked state" {
  let changes : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @controls.checkbox(label="Accept", on_change=fn(checked) {
        changes.push(checked.value)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=48.0)
  let first = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(first, size~)
  inspect(first.accent_fills.val, content="0")
  assert_true(root.click_at(size~, point=Point(x=8.0, y=8.0)))
  inspect(changes.length(), content="1")
  inspect(changes[0], content="true")
  let second = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(second, size~)
  inspect(second.accent_fills.val, content="1")
  assert_true(root.key_down(test_key_event(KeySpace)))
  inspect(changes.length(), content="2")
  inspect(changes[1], content="false")
  let third = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(third, size~)
  inspect(third.accent_fills.val, content="0")
  root.dispose()
}

///|
test "radio selects signal from pointer and keyboard" {
  let selected = @reactive.signal(false)
  let changes : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @controls.radio(selected~, label="Option", on_change=fn(selected) {
        changes.push(selected.value)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=48.0)
  let first = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(first, size~)
  inspect(first.accent_fills.val, content="0")
  debug_inspect(first.text.val, content="Some(\"Option\")")
  assert_true(root.click_at(size~, point=Point(x=8.0, y=8.0)))
  inspect(changes.length(), content="1")
  inspect(changes[0], content="true")
  inspect(selected.get(), content="true")
  let second = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(second, size~)
  inspect(second.accent_fills.val, content="1")
  assert_true(root.key_down(test_key_event(KeySpace)))
  inspect(changes.length(), content="1")
  inspect(selected.get(), content="true")
  root.dispose()
}

///|
test "uncontrolled radio keeps local selected state" {
  let changes : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @controls.radio(label="Option", on_change=fn(selected) {
        changes.push(selected.value)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=48.0)
  let first = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(first, size~)
  inspect(first.accent_fills.val, content="0")
  assert_true(root.click_at(size~, point=Point(x=8.0, y=8.0)))
  inspect(changes.length(), content="1")
  inspect(changes[0], content="true")
  let second = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(second, size~)
  inspect(second.accent_fills.val, content="1")
  assert_true(root.key_down(test_key_event(KeySpace)))
  inspect(changes.length(), content="1")
  let third = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(third, size~)
  inspect(third.accent_fills.val, content="1")
  root.dispose()
}

///|
test "radio group selects one value from options" {
  let selected = @reactive.signal("one")
  let changes : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(
        selected,
        ["one", "two"],
        label=fn(value) { if value == "one" { "One" } else { "Two" } },
        style=@view.FlexStyle().spacing(4.0),
        item_style=@controls.RadioStyle().frame(
          @style.BoxStyle().width(160.0).height(24.0),
        ),
        on_change=fn(value) { changes.push(value.value) },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=60.0)
  let first = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(first, size~)
  inspect(first.accent_fills.val, content="1")
  assert_true(root.click_at(size~, point=Point(x=8.0, y=34.0)))
  inspect(selected.get(), content="two")
  inspect(changes.length(), content="1")
  inspect(changes[0], content="two")
  let second = CheckboxPaintRecorder::{ accent_fills: Ref(0), text: Ref(None), }
  root.paint(second, size~)
  inspect(second.accent_fills.val, content="1")
  assert_true(root.key_down(test_key_event(KeySpace)))
  inspect(selected.get(), content="two")
  inspect(changes.length(), content="1")
  root.dispose()
}

///|
impl @foundation.SceneRenderer for CheckboxPaintRecorder with fn draw_image(
  _self,
  _image,
  _placement,
) {
  ()
}
