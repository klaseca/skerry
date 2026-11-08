///|
fn main raise {
  @skerry.run(
    App(
      title="Skerry: reusable theme",
      width=620,
      height=600,
      light_theme=light_theme(),
      dark_theme=dark_theme(),
      content=app_view,
    ),
  )
}

///|
fn app_view() -> @skerry.View {
  let app = @skerry.current_app()
  let name = @skerry.signal("")
  let saved = @skerry.signal("")
  let shared = @skerry.BoxStyle()
    .background(@skerry.accent_token)
    .color(@skerry.on_accent_token)
    .grow(1.0)
  @skerry.column(
    style=@skerry.FlexStyle().spacing(14.0).padding(@skerry.Insets::all(24.0)),
  ) <| [
    @skerry.text(
      "Reusable theme",
      style=@skerry.TextStyle().font(@skerry.FontSpec::default().size(24.0)),
    ),
    @skerry.text("Keep typing or selecting text while changing the theme."),
    @skerry.row(style=@skerry.FlexStyle().spacing(12.0)) <| [
      @skerry.button(
        "Shared BoxStyle",
        style=@skerry.ButtonStyle().surface(shared),
      ),
      @skerry.style_scope(
        light_theme=preview_light(),
        dark_theme=preview_dark(),
      ) <| fn() {
        @skerry.button(
          "Same BoxStyle, local theme",
          style=@skerry.ButtonStyle().surface(shared),
        )
      },
    ],
    @skerry.style_scope(
      styles=@skerry.Styles().add(
        @skerry.ButtonStyle().surface(@skerry.BoxStyle().radius(12.0)),
      ),
    ) <| fn() {
      card("Account", [
        @skerry.text_input(value=name, placeholder="Your name"),
        @skerry.button("Save (scoped)", on_click=fn() { saved.set(name.get()) }),
        @skerry.button(
          "Clear (fixed color)",
          style=@skerry.ButtonStyle().surface(
            @skerry.BoxStyle()
            .radius(0.0)
            .background(@skerry.Color::rgb(r=150, g=50, b=60))
            .color(@skerry.Color::white()),
          ),
          on_click=fn() { name.set("") },
        ),
      ])
    },
    @skerry.button(
      @skerry.bind(fn() {
        match app.theme_mode() {
          System => "Theme: System"
          Light => "Theme: Light"
          Dark => "Theme: Dark"
        }
      }),
      on_click=fn() {
        app.set_theme_mode(
          match app.theme_mode() {
            System => Light
            Light => Dark
            Dark => System
          },
        )
      },
    ),
    @skerry.button("Disabled", disabled=true),
    @skerry.text(@skerry.bind(() => "Saved: \{saved.get()}")),
  ]
}
