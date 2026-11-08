///|
test "text is not focusable or hit-testable by default" {
  let root = @runtime.mount(
    fn() {
      @view.text(
        "Label",
        style=@view.TextStyle().frame(
          @style.BoxStyle().width(80.0).height(24.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(
    !root.click_at(
      size=Size(width=120.0, height=60.0),
      point=Point(x=10.0, y=10.0),
    ),
  )
  assert_true(!root.key_down(test_key_event(KeyEnter)))
  root.dispose()
}

///|
test "text defaults to black" {
  let recorder = text_color_recorder()
  let root = @runtime.mount(
    fn() { @view.text("default") },
    text_layout_system=test_text_layout_system(),
  )
  root.paint(recorder, size=Size(width=120.0, height=40.0))
  assert_true(recorder.color.val == Some(@foundation.Color::black()))
}

///|
test "text_of signal update does not rebuild root" {
  let count = @reactive.signal(1)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val = builds.val + 1
      @view.text_of(
        count,
        style=@view.TextStyle().frame(
          @style.BoxStyle().width(80.0).height(24.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  inspect(builds.val, content="1")
  let first = TextRunRecorder::{ text: Ref(None), }
  root.paint(first, size=Size(width=120.0, height=40.0))
  debug_inspect(first.text.val, content="Some(\"1\")")
  assert_true(root.dirty() == Clean)
  count.set(2)
  inspect(builds.val, content="1")
  assert_true(root.dirty() == NeedsLayout)
  let second = TextRunRecorder::{ text: Ref(None), }
  root.paint(second, size=Size(width=120.0, height=40.0))
  debug_inspect(second.text.val, content="Some(\"2\")")
  inspect(builds.val, content="1")
  root.dispose()
}

///|
test "text layout and paint wrap at the explicit width" {
  let style = @style.BoxStyle()
    .font(@foundation.FontSpec::default().size(10.0))
    .width(44.0)
  let view = @view.column([
    @view.text("hello moonbit ui", style=@view.TextStyle().frame(style)),
  ])
  let size = @foundation.Size(width=200.0, height=200.0)
  let layout = view.layout(size~, text_layout_system=test_text_layout_system())
  assert_eq((layout.children[0].width, layout.children[0].height), (44.0, 37.5))
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["hello m", "oonbit ", "ui"])
  assert_eq(recorder.runs.map(run => run.frame.origin.y), [0.0, 12.5, 25.0])
}
