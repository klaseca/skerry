///|
// Concrete style defaults for built-in controls and the local Card component.
fn light_theme() -> @skerry.Theme {
  rounded_theme(Palette(accent=@skerry.Color::rgb(r=91, g=66, b=190)))
}

///|
fn dark_theme() -> @skerry.Theme {
  rounded_theme({
    ..@skerry.Palette::dark(),
    accent: @skerry.Color::rgb(r=199, g=179, b=255),
  })
}

///|
fn rounded_theme(palette : @skerry.Palette) -> @skerry.Theme {
  Theme(
    palette~,
    styles=@skerry.Styles()
      .add(
        @skerry.ButtonStyle().surface(
          @skerry.BoxStyle()
          .height(44.0)
          .padding(@skerry.Insets::symmetric(horizontal=20.0, vertical=10.0))
          .radius(22.0)
          .shrink(0.0),
        ),
      )
      .add(
        @skerry.TextInputStyle().surface(
          @skerry.BoxStyle()
          .height(44.0)
          .padding(@skerry.Insets::symmetric(horizontal=16.0, vertical=10.0))
          .radius(12.0)
          .shrink(0.0),
        ),
      )
      .add(
        CardStyle()
        .surface(
          @skerry.FlexStyle()
          .padding(@skerry.Insets::all(16.0))
          .spacing(12.0)
          .radius(12.0)
          .background(@skerry.surface_token)
          .stroke(@skerry.accent_token),
        )
        .title(
          @skerry.TextStyle()
          .font(@skerry.FontSpec::default().size(20.0))
          .color(@skerry.accent_token),
        ),
      ),
  )
}

///|
fn preview_light() -> @skerry.Theme {
  rounded_theme(Palette(accent=@skerry.Color::rgb(r=25, g=120, b=85)))
}

///|
fn preview_dark() -> @skerry.Theme {
  rounded_theme({
    ..@skerry.Palette::dark(),
    accent: @skerry.Color::rgb(r=130, g=220, b=175),
  })
}
