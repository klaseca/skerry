///|
fn test_text_input_x_for_caret(text : String, index : Int32) -> Double {
  let layout = test_text_layout_system().layout(
    TextLayoutInput(text~, font=@foundation.FontSpec::default(), max_width=None),
  )
  10.0 + layout.caret_positions[index]
}

///|
test "text input receives focused text events" {
  let value = @reactive.signal("")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        placeholder="Name",
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(120.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(!root.text_input("x"))
  inspect(value.get(), content="")
  assert_true(
    root.click_at(
      size=Size(width=160.0, height=60.0),
      point=Point(x=10.0, y=10.0),
    ),
  )
  assert_true(root.text_input("ab"))
  inspect(value.get(), content="ab")
  assert_true(root.dirty() != Clean)
  assert_true(root.key_down(test_key_event(KeyBackspace)))
  inspect(value.get(), content="a")
  assert_true(root.dirty() != Clean)
  root.dispose()
}

///|
test "text input on_change argument observes edits" {
  let value = @reactive.signal("")
  let changes : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        on_change=fn(next) { changes.push(next.value) },
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(120.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_true(root.key_down(test_key_event(KeyBackspace)))
  inspect(changes.length(), content="0")
  assert_true(root.text_input("a"))
  assert_true(root.key_down(test_key_event(KeyBackspace)))
  inspect(changes.length(), content="2")
  inspect(changes[0], content="a")
  inspect(changes[1], content="")
  root.dispose()
}

///|
test "text input on_submit handles enter with current value" {
  let value = @reactive.signal("")
  let submissions : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        on_submit=fn(text) { submissions.push(text) },
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(120.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=60.0)
  assert_true(!root.key_down(test_key_event(KeyEnter)))
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_true(root.text_input("moon"))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  inspect(submissions.length(), content="1")
  inspect(submissions[0], content="moon")
  root.dispose()
}

///|
test "text input enter without on_submit is unhandled" {
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(120.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_true(!root.key_down(test_key_event(KeyEnter)))
  root.dispose()
}

///|
test "uncontrolled text input keeps local value" {
  let changes : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        placeholder="Name",
        on_change=fn(value) { changes.push(value.value) },
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(120.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=60.0)
  assert_true(!root.text_input("x"))
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  assert_true(root.text_input("ab"))
  assert_true(root.key_down(test_key_event(KeyBackspace)))
  inspect(changes.length(), content="2")
  inspect(changes[0], content="ab")
  inspect(changes[1], content="a")
  let recorder = TextRunRecorder::{ text: Ref(None), }
  root.paint(recorder, size~)
  debug_inspect(recorder.text.val, content="Some(\"a\")")
  root.dispose()
}

///|
struct TextInputPaintRecorder {
  stroke_width : Ref[Double?]
  caret_count : Ref[Int32]
  caret_x : Ref[Double?]
  text_x : Ref[Double?]
  selection_count : Ref[Int32]
  text_count : Ref[Int32]
  clip_count : Ref[Int32]
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn clear(
  _self,
  _color,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn draw_image(
  _self,
  _image,
  _placement,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn fill_rect(
  self,
  rect,
  color,
) {
  if rect.size.width == 1.0 && color == @foundation.Color::accent() {
    self.caret_count.val = self.caret_count.val + 1
    self.caret_x.val = Some(rect.origin.x)
  } else {
    self.selection_count.val = self.selection_count.val + 1
  }
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn stroke_rect(
  _self,
  _rect,
  _color,
  _width,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn fill_rounded_rect(
  _self,
  _rounded,
  _color,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn stroke_rounded_rect(
  self,
  _rounded,
  _color,
  width,
) {
  self.stroke_width.val = Some(width)
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn draw_text(
  self,
  run,
) {
  self.text_x.val = Some(run.frame.origin.x)
  self.text_count.val = self.text_count.val + 1
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn push_clip(
  self,
  _rect,
) {
  self.clip_count.val = self.clip_count.val + 1
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn pop_clip(
  _self,
) {
  ()
}

///|
test "focused text input paints focus border and caret" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        placeholder="Name",
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(120.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let idle_recorder = TextInputPaintRecorder::{
    stroke_width: Ref(None),
    caret_count: Ref(0),
    caret_x: Ref(None),
    text_x: Ref(None),
    selection_count: Ref(0),
    text_count: Ref(0),
    clip_count: Ref(0),
  }
  root.paint(idle_recorder, size=Size(width=160.0, height=60.0))
  debug_inspect(idle_recorder.stroke_width.val, content="Some(1)")
  inspect(idle_recorder.caret_count.val, content="0")
  assert_true(
    root.click_at(
      size=Size(width=160.0, height=60.0),
      point=Point(x=10.0, y=10.0),
    ),
  )
  let focused_recorder = TextInputPaintRecorder::{
    stroke_width: Ref(None),
    caret_count: Ref(0),
    caret_x: Ref(None),
    text_x: Ref(None),
    selection_count: Ref(0),
    text_count: Ref(0),
    clip_count: Ref(0),
  }
  root.paint(focused_recorder, size=Size(width=160.0, height=60.0))
  debug_inspect(focused_recorder.stroke_width.val, content="Some(2)")
  inspect(focused_recorder.caret_count.val, content="1")
  root.dispose()
}

///|
fn text_input_paint_recorder() -> TextInputPaintRecorder {
  {
    stroke_width: Ref(None),
    caret_count: Ref(0),
    caret_x: Ref(None),
    text_x: Ref(None),
    selection_count: Ref(0),
    text_count: Ref(0),
    clip_count: Ref(0),
  }
}

///|
test "text input paints one clipped line" {
  let value = @reactive.signal("one two three four five six seven")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(120.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let recorder = text_input_paint_recorder()
  root.paint(recorder, size=Size(width=160.0, height=60.0))
  inspect(recorder.text_count.val, content="1")
  // The root viewport and the text input's single-line clip are both active.
  assert_eq(recorder.clip_count.val, 2)
  root.dispose()
}

///|
test "text input drag selection replaces selected text" {
  let value = @reactive.signal("hello world")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  let selection_end_x = test_text_input_x_for_caret("hello world", 5)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.pointer_move(size~, point=Point(x=selection_end_x, y=18.0)))
  assert_true(root.pointer_up(size~, point=Point(x=selection_end_x, y=18.0)))
  assert_true(root.text_input("x"))
  inspect(value.get(), content="x world")
  root.dispose()
}

///|
test "text input cancellation ends dragging and preserves selected text" {
  for lose_focus in [false, true] {
    let value = @reactive.signal("hello world")
    let root = @runtime.mount(
      fn() {
        @controls.text_input(
          value~,
          style=@controls.TextInputStyle().surface(
            @style.BoxStyle().width(180.0).height(36.0),
          ),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=220.0, height=60.0)
    assert_true(root.pointer_down(size~, point=Point(x=10.0, y=18.0)))
    assert_true(
      root.pointer_move(
        size~,
        point=Point(x=test_text_input_x_for_caret("hello world", 5), y=18.0),
      ),
    )
    if lose_focus {
      root.focus_lost()
      assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
    } else {
      assert_true(root.pointer_cancel())
    }
    let state = @view.LayoutState(text_layout_system=test_text_layout_system())
    // A control must also ignore moves delivered directly after cancellation.
    assert_true(
      state.pointer_move_path(
        root.view(),
        size~,
        [],
        point=Point(x=test_text_input_x_for_caret("hello world", 11), y=18.0),
      ),
    )
    assert_eq(root.copy_text(), Some("hello"))
    assert_true(root.text_input("x"))
    assert_eq(value.get(), "x world")
  }
}

///|
test "text input arrow left moves caret before inserted text" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_key_event(KeyArrowLeft)))
  assert_true(root.text_input("x"))
  inspect(value.get(), content="abxc")
  root.dispose()
}

///|
test "text input shift arrow selects text for replacement" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_shift_key_event(KeyArrowLeft)))
  assert_true(root.key_down(test_shift_key_event(KeyArrowLeft)))
  let recorder = text_input_paint_recorder()
  root.paint(recorder, size~)
  inspect(recorder.selection_count.val, content="1")
  assert_true(root.text_input("x"))
  inspect(value.get(), content="ax")
  root.dispose()
}

///|
test "text input shift home selects text to start" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_shift_key_event(KeyHome)))
  assert_true(root.text_input("x"))
  inspect(value.get(), content="x")
  root.dispose()
}

///|
test "text input control a selects all text" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  let recorder = text_input_paint_recorder()
  root.paint(recorder, size~)
  inspect(recorder.selection_count.val, content="1")
  assert_true(root.text_input("x"))
  inspect(value.get(), content="x")
  root.dispose()
}

///|
test "text input copy cut and paste focused selection" {
  let value = @reactive.signal("abc")
  let changes : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        on_change=fn(next) { changes.push(next.value) },
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.copy_text() is None)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  debug_inspect(root.copy_text(), content="Some(\"abc\")")
  debug_inspect(root.cut_text(), content="Some(\"abc\")")
  inspect(value.get(), content="")
  assert_true(root.paste_text("xy"))
  inspect(value.get(), content="xy")
  inspect(changes.length(), content="2")
  inspect(changes[0], content="")
  inspect(changes[1], content="xy")
  root.dispose()
}

///|
test "text input copy and cut without selection are empty commands" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.copy_text() is None)
  assert_true(root.cut_text() is None)
  assert_true(!root.paste_text(""))
  inspect(value.get(), content="abc")
  root.dispose()
}

///|
test "text input control arrows move by word" {
  let value = @reactive.signal("hello world moon")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(220.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=260.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_control_key_event(KeyArrowLeft)))
  assert_true(root.text_input("wide "))
  inspect(value.get(), content="hello world wide moon")
  assert_true(root.key_down(test_control_key_event(KeyArrowLeft)))
  assert_true(root.key_down(test_control_key_event(KeyArrowRight)))
  assert_true(root.text_input("bright "))
  inspect(value.get(), content="hello world wide bright moon")
  root.dispose()
}

///|
test "text input control backspace deletes previous word" {
  let value = @reactive.signal("hello world")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_control_key_event(KeyBackspace)))
  inspect(value.get(), content="hello ")
  assert_true(root.key_down(test_control_key_event(KeyBackspace)))
  inspect(value.get(), content="")
  root.dispose()
}

///|
test "text input control shift arrow selects word" {
  let value = @reactive.signal("hello world")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(
    root.key_down(
      KeyEvent(
        key=KeyArrowLeft,
        modifiers=KeyModifiers(control=true, shift=true),
      ),
    ),
  )
  let recorder = text_input_paint_recorder()
  root.paint(recorder, size~)
  inspect(recorder.selection_count.val, content="1")
  assert_true(root.text_input("moon"))
  inspect(value.get(), content="hello moon")
  root.dispose()
}

///|
test "text input plain key a is not handled by key down" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  root.paint(text_input_paint_recorder(), size~)
  assert_true(root.dirty() == Clean)
  assert_true(!root.key_down(test_key_event(KeyA)))
  assert_true(root.dirty() == Clean)
  inspect(value.get(), content="abc")
  root.dispose()
}

///|
test "text input home delete and end edit from caret" {
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=18.0)))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_true(root.key_down(test_key_event(KeyDelete)))
  inspect(value.get(), content="bc")
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_true(root.text_input("d"))
  inspect(value.get(), content="bcd")
  root.dispose()
}

///|
test "text input caret uses caret positions with spaces" {
  let value = @reactive.signal("a  b")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(180.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=220.0, height=60.0)
  let expected_x = test_text_input_x_for_caret("a  b", 3)
  assert_true(root.pointer_down(size~, point=Point(x=expected_x, y=18.0)))
  assert_true(root.pointer_up(size~, point=Point(x=expected_x, y=18.0)))
  let recorder = text_input_paint_recorder()
  root.paint(recorder, size~)
  guard recorder.caret_x.val is Some(x) else { fail("expected caret") }
  assert_true((x - expected_x).abs() < 0.1)
  root.dispose()
}

///|
test "text input scrolls repeated input to keep caret visible" {
  let value = @reactive.signal("")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        placeholder="Name",
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle().width(80.0).height(36.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=120.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  for _ in 0..<20 {
    assert_true(root.text_input("a"))
  }
  let recorder = text_input_paint_recorder()
  root.paint(recorder, size~)
  guard recorder.caret_x.val is Some(caret_x) else { fail("expected caret") }
  guard recorder.text_x.val is Some(text_x) else { fail("expected text") }
  assert_true(caret_x >= 10.0 && caret_x <= 103.0)
  assert_true(text_x < 10.0)
  root.dispose()
}

///|
test "nested interactive click handlers do not activate on text input submit" {
  for depth in [1, 2, 3] {
    let clicks = Ref(0)
    let keys = Ref(0)
    let submitted : Array[String] = []
    let mut control = @controls.text_input(value=@reactive.signal("abc"), on_submit=fn(
      value,
    ) {
      submitted.push(value)
    })
    for _ in 0..<depth {
      control = @view.interactive(control, on_click=fn() { clicks.val += 1 }, on_key_down=fn(
        _,
      ) {
        keys.val += 1
      })
    }
    let root = @runtime.mount(
      fn() { control },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.key_down(test_key_event(KeyEnter)))
    assert_eq(submitted, ["abc"])
    assert_true(root.key_down(test_key_event(KeyArrowLeft)))
    assert_eq(keys.val, depth * 2)
    assert_eq(clicks.val, 0)
  }
}

///|
impl @foundation.SceneRenderer for TextInputPaintRecorder with fn draw_line(
  _,
  _,
  _,
  _,
  _,
) {
  ()
}
