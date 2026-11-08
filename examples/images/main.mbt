///|
fn main raise {
  // Run from the repository root. Load resources once, before creating the UI.
  let landscape = @skerry.load_image("examples/images/assets/landscape.jpg")
  let tiles = @skerry.load_image("examples/images/assets/tiles.png")
  @skerry.run(
    @skerry.App(title="Skerry Images", width=640, height=620, content=fn() {
      image_demo(landscape, tiles)
    }),
  )
}

///|
fn image_demo(landscape : @skerry.Image, tiles : @skerry.Image) -> @skerry.View {
  let selected = @skerry.signal(landscape)
  let fit = @skerry.signal(@skerry.ImageFit::Contain)
  let alignment = @skerry.signal(@skerry.ImageAlignment::Center)
  let visible = @skerry.signal(true)
  let style = @skerry.ImageStyle::computed(fn() {
    @skerry.ImageStyle()
    .height(280.0)
    .fit(fit.get())
    .align(alignment.get())
    .frame(@skerry.BoxStyle().background(@skerry.control_surface_token))
  })
  @skerry.scroll_view(
    @skerry.column(
      style=@skerry.FlexStyle().spacing(16.0).padding(@skerry.Insets::all(24.0)),
    ) <| [
      @skerry.text("Images: PNG transparency and JPEG"),
      @skerry.text("Change fit, crop alignment, source or visibility."),
      @skerry.row(style=@skerry.FlexStyle().spacing(8.0)) <| [
        @skerry.button("Contain", on_click=fn() { fit.set(Contain) }),
        @skerry.button("Cover", on_click=fn() { fit.set(Cover) }),
        @skerry.button("Fill", on_click=fn() { fit.set(Fill) }),
      ],
      @skerry.row(style=@skerry.FlexStyle().spacing(8.0)) <| [
        @skerry.button("JPEG", on_click=fn() { selected.set(landscape) }),
        @skerry.button("PNG", on_click=fn() { selected.set(tiles) }),
        @skerry.button("Align", on_click=fn() {
          alignment.set(
            match alignment.get() {
              TopLeft => Center
              Center => BottomRight
              _ => TopLeft
            },
          )
        }),
      ],
      @skerry.checkbox(checked=visible, label="Show image"),
      @skerry.show(fn() { visible.get() }, fn() {
        @skerry.image(selected, style~)
      }),
      @skerry.text(
        "One fixed width, with height from the image's aspect ratio:",
      ),
      @skerry.image(landscape, style=@skerry.ImageStyle().width(240.0)),
    ],
  )
}
