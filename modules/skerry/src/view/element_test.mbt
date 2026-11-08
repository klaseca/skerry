///|
test "unmeasured leaves use style bounds and padding while measured leaves keep intrinsic size" {
  let width = @reactive.signal(80.0)
  let measurements = Ref(0)
  let font = @foundation.FontSpec::default().size(22.0)
  let measured_font : Ref[@foundation.FontSpec?] = Ref(None)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.element(
            style=@style.BoxStyle().padding(@foundation.Insets::all(4.0)),
            painter=@view.Painter::empty(),
          ),
          @view.element(
            style=@style.BoxStyle()
              .width(width)
              .max_width(60.0)
              .height(40.0)
              .padding(@foundation.Insets::all(4.0)),
            painter=@view.Painter::empty(),
          ),
          @view.element(
            style=@style.BoxStyle().padding(@foundation.Insets::all(4.0)),
            painter=@view.Painter::empty(),
            measure=fn(context) {
              measured_font.val = Some(context.font)
              fn(_, _) {
                measurements.val += 1
                {
                  min_width: 10.0,
                  max_width: 70.0,
                  min_height: 20.0,
                  max_height: 20.0,
                }
              }
            },
          ),
        ],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    theme=@style.Theme(font~),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(measurements.val, 0)
  let renderer = TextRunRecorder::{ text: Ref(None), }
  let size = @foundation.Size(width=120.0, height=140.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  assert_eq(before.tree.nodes[1].frame.size, Size(width=8.0, height=8.0))
  assert_eq(before.tree.nodes[1].content.size, @foundation.Size::zero())
  assert_eq(before.tree.nodes[2].frame.size, Size(width=60.0, height=40.0))
  assert_eq(before.tree.nodes[2].content.size, Size(width=52.0, height=32.0))
  assert_eq(before.tree.nodes[3].frame.size, Size(width=70.0, height=28.0))
  assert_eq(measured_font.val, Some(font))
  assert_true(measurements.val > 0)
  let measured = measurements.val
  assert_eq(root.snapshot(), Some(before))
  assert_eq(measurements.val, measured)
  width.set(30.0)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.tree.nodes[2].id, before.tree.nodes[2].id)
  assert_eq(after.tree.nodes[2].frame.size, Size(width=30.0, height=40.0))
  assert_eq(after.frame.layout_count, before.frame.layout_count + 1)
}
