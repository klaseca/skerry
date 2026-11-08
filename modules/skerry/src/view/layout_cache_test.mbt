///|
test "input intrinsic widths shrink after text removal and remain correct on resize" {
  let value = @reactive.signal("")
  let view = @view.column([
    @view.row([
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(
          @style.BoxStyle()
          .font(@foundation.FontSpec::default().size(10.0))
          .padding(@foundation.Insets::all(0.0)),
        ),
      ),
      @view.box(style=@style.BoxStyle().width(10.0).height(10.0)),
    ]),
  ])
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  for _ in 0..<3 {
    for
      (text, width) in [
        (String::make(128, 'x'), 768.0),
        ("", 0.0),
        ("ab", 12.0),
      ] {
      value.set(text)
      state.invalidate()
      for viewport_width in [1000.0, 1200.0, 1000.0] {
        let size = @foundation.Size(width=viewport_width, height=200.0)
        let layout = state.layout(view, size~)
        let row = layout.children[0]
        assert_eq(row.children[0].width, width)
        assert_eq(row.children[1].x, width)
        let count = state.layout_pass_count()
        assert_true(physical_equal(state.layout(view, size~), layout))
        assert_eq(state.layout_pass_count(), count)
      }
    }
  }
}
