///|
test "dialog parts follow scoped theme and reactive local declarations without rebuilding" {
  let open = @reactive.signal(true)
  let width = @reactive.signal(300.0)
  let padding = @reactive.signal(10.0)
  let creates = Ref(0)
  let reads = Ref(0)
  let surface_color = @foundation.Color::rgb(r=20, g=40, b=60)
  let backdrop_color = @foundation.Color::rgba(r=10, g=15, b=20, a=100)
  let theme = @style.Theme(
    styles=@style.Styles().add(
      @controls.DialogStyle()
      .surface(@style.BoxStyle().background(surface_color).width(500.0))
      .backdrop(
        @style.BoxStyle()
        .background(backdrop_color)
        .padding(@foundation.Insets::all(8.0)),
      ),
    ),
  )
  let root = @runtime.mount(
    fn() {
      @view.style_scope(light_theme=theme, fn() {
        @controls.dialog(
          popup_test_button("open"),
          open~,
          style=@controls.DialogStyle::computed(fn() {
            reads.val += 1
            @controls.DialogStyle().surface(
              @style.BoxStyle()
              .width(width)
              .padding(@foundation.Insets::all(padding.get())),
            )
          }),
          fn(_close) {
            creates.val += 1
            popup_test_button("inside")
          },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  root.paint(ScrollRecorder(), size~)
  let surface = dialog_surface(root)
  assert_eq(surface.frame.size.width, 300.0)
  assert_eq(surface.padding.top, 10.0)
  assert_eq(surface.computed_style.unwrap().background, Some(surface_color))
  let backdrop = root.snapshot().unwrap().tree.nodes
    .iter()
    .filter(node => node.component_name == "Modal")
    .to_array()[0]
  assert_eq(backdrop.computed_style.unwrap().background, Some(backdrop_color))
  assert_eq(backdrop.padding.top, 8.0)
  width.set(360.0)
  padding.set(0.0)
  root.paint(ScrollRecorder(), size~)
  let updated = dialog_surface(root)
  assert_eq(updated.id, surface.id)
  assert_eq(updated.frame.size.width, 360.0)
  assert_eq(updated.padding.top, 0.0)
  assert_eq(creates.val, 1)
  let before = reads.val
  ignore(root.snapshot())
  ignore(root.snapshot())
  assert_eq(reads.val, before)
}

///|
test "dialog default surface follows light and dark palettes" {
  let root = @runtime.mount(
    fn() {
      @controls.dialog(popup_test_button("open"), open=@reactive.signal(true), fn(
        _close,
      ) {
        @view.text("Theme")
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  root.paint(ScrollRecorder(), size~)
  let first = dialog_surface(root)
  assert_eq(
    first.computed_style.unwrap().background,
    Some(@style.Theme().resolve(@style.surface_token)),
  )
  let dark = @style.Theme(palette=@style.Palette::dark())
  root.set_theme(dark)
  root.paint(ScrollRecorder(), size~)
  let second = dialog_surface(root)
  assert_eq(first.id, second.id)
  assert_eq(
    second.computed_style.unwrap().background,
    Some(dark.resolve(@style.surface_token)),
  )
  assert_false(
    first.computed_style.unwrap().background ==
    second.computed_style.unwrap().background,
  )
}

///|
test "dialog custom maximum and minimum dimensions stay within viewport" {
  let root = @runtime.mount(
    fn() {
      @controls.dialog(
        popup_test_button("open"),
        open=@reactive.signal(true),
        style=@controls.DialogStyle().surface(
          @style.BoxStyle()
          .width(500.0)
          .min_width(300.0)
          .max_width(320.0)
          .height(500.0)
          .min_height(300.0)
          .max_height(320.0),
        ),
        fn(_close) { @view.text("Content") },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(ScrollRecorder(), size=Size(width=640.0, height=480.0))
  assert_eq(dialog_surface(root).frame.size, Size(width=320.0, height=320.0))
  root.paint(ScrollRecorder(), size=Size(width=200.0, height=160.0))
  assert_eq(dialog_surface(root).frame.size, Size(width=152.0, height=112.0))
}
