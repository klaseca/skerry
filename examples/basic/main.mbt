///|
fn main raise {
  @skerry.run(App(title="Skerry", width=800, height=480, content=app_view))
}

///|
fn app_view() -> @skerry.View {
  let app = @skerry.current_app()
  let count = @skerry.signal(0)
  let name = @skerry.signal("")
  let accepted = @skerry.signal(false)
  let large_text = @skerry.signal(false)
  let input_appearance = @skerry.Appearance().radius(10.0)
  let font_theme = @skerry.bind(fn() {
    {
      ..@skerry.current_theme(),
      font: @skerry.FontSpec::default().size(
        if large_text.get() {
          22.0
        } else {
          16.0
        },
      ),
    }
  })
  @skerry.style_scope(
    light_theme=font_theme,
    dark_theme=font_theme,
    inherit_styles=false,
    fn() {
      @skerry.column(
        style=@skerry.FlexStyle()
          .spacing(12.0)
          .padding(@skerry.Insets::all(24.0)),
      ) <| [
        @skerry.text(
          "Skerry",
          style=@skerry.TextStyle()
            .align_self(Center)
            .shrink(0.0)
            .font(@skerry.FontSpec::default().size(24.0)),
        ),
        @skerry.row(
          style=@skerry.FlexStyle()
            .spacing(12.0)
            .height(56.0)
            .shrink(0.0)
            .justify_content(SpaceBetween)
            .align_items(Center),
        ) <| [
          @skerry.text_input(
            value=name,
            placeholder="Type here",
            style=@skerry.TextInputStyle().surface(
              @skerry.BoxStyle()
              .appearance(input_appearance)
              .grow(1.0)
              .min_width(0.0)
              .max_width(600.0)
              .height(44.0)
              .hovered(
                @skerry.Appearance().stroke(
                  @skerry.Color::rgb(r=100, g=116, b=139),
                ),
              )
              .focused(
                @skerry.Appearance().stroke(@skerry.Color::accent(), width=2.0),
              ),
            ),
          ),
          @skerry.button(
            "Run",
            on_click=fn() { count.update(fn(n) { n + 1 }) },
            style=@skerry.ButtonStyle().surface(
              @skerry.BoxStyle()
              .width(120.0)
              .height(44.0)
              .shrink(0.0)
              .background(@skerry.Color::rgb(r=56, g=92, b=219))
              .color(@skerry.Color::white())
              .stroke(@skerry.Color::rgb(r=31, g=64, b=164))
              .hovered(
                @skerry.Appearance().background(
                  @skerry.Color::rgb(r=49, g=86, b=205),
                ),
              )
              .pressed(
                @skerry.Appearance().background(
                  @skerry.Color::rgb(r=42, g=73, b=183),
                ),
              )
              .focused(
                @skerry.Appearance().stroke(@skerry.Color::white(), width=2.0),
              )
              .radius(10.0),
            ),
          ),
        ],
        @skerry.interactive(
          @skerry.text(
            @skerry.bind(fn() {
              if large_text.get() {
                "Text size: 22px (activate for 16px). Tab changes focus."
              } else {
                "Text size: 16px (activate for 22px). Tab changes focus."
              }
            }),
            style=@skerry.TextStyle().shrink(0.0),
          ),
          on_click=fn() { large_text.update(fn(value) { !value }) },
        ),
        @skerry.row(
          style=@skerry.FlexStyle()
            .spacing(16.0)
            .shrink(0.0)
            .align_items(Center),
        ) <| [
          @skerry.text_of(
            count,
            style=@skerry.TextStyle()
              .min_width(32.0)
              .font(@skerry.FontSpec::default().size(18.0)),
          ),
          @skerry.checkbox(checked=accepted, label="Accept"),
          @skerry.radio(label="Choice"),
          @skerry.interactive(
            on_click=fn() {
              app.set_theme_mode(
                match app.theme_mode() {
                  System => Light
                  Light => Dark
                  Dark => System
                },
              )
            },
            @skerry.text(
              @skerry.bind(fn() {
                match app.theme_mode() {
                  System => "Theme: System"
                  Light => "Theme: Light"
                  Dark => "Theme: Dark"
                }
              }),
            ),
          ),
          @skerry.button(
            "Disabled",
            style=@skerry.ButtonStyle().surface(
              @skerry.BoxStyle().width(104.0).height(32.0).shrink(0.0),
            ),
            disabled=true,
          ),
        ],
        @skerry.scroll_view(
          @skerry.column(style=@skerry.FlexStyle().spacing(8.0)) <| Array::makei(
            20,
            index => {
              @skerry.text(
                "Scrollable row \{index + 1}",
                style=@skerry.TextStyle().shrink(0.0),
              )
            },
          ),
          style=@skerry.BoxStyle()
            .grow(1.0)
            .min_height(0.0)
            .padding(@skerry.Insets::all(12.0))
            .stroke(@skerry.Color::rgb(r=203, g=213, b=225))
            .radius(10.0),
        ),
      ]
    },
  )
}
