///|
fn form_view(model : FormModel) -> @skerry.View {
  let app = @skerry.current_app()
  let field_style = @skerry.BoxStyle().height(44.0).min_width(0.0).shrink(0.0)
  @skerry.scroll_view(
    @skerry.column(
      style=@skerry.FlexStyle().spacing(14.0).padding(@skerry.Insets::all(24.0)),
    ) <| [
      @skerry.text(
        "Contact form",
        style=@skerry.TextStyle()
          .font(@skerry.FontSpec::default().size(26.0))
          .shrink(0.0),
      ),
      @skerry.text(
        "Fill in both fields and accept to enable Save. Enter also submits.",
        style=@skerry.TextStyle().shrink(0.0),
      ),
      @skerry.text("Name", style=@skerry.TextStyle().shrink(0.0)),
      @skerry.text_input(
        value=model.name,
        placeholder="Your name",
        style=@skerry.TextInputStyle().surface(field_style),
        on_change=fn(_) { model.changed() },
        on_blur=fn() { model.name_touched.set(true) },
        on_submit=fn(_) { model.submit() },
      ).debug(name="name"),
      validation_message(fn() {
        if model.name_touched.get() || model.attempted.get() {
          model.name_error()
        } else {
          None
        }
      }),
      @skerry.text("Email", style=@skerry.TextStyle().shrink(0.0)),
      @skerry.text_input(
        value=model.email,
        placeholder="name@example.com",
        style=@skerry.TextInputStyle().surface(field_style),
        on_change=fn(_) { model.changed() },
        on_blur=fn() { model.email_touched.set(true) },
        on_submit=fn(_) { model.submit() },
      ).debug(name="email"),
      validation_message(fn() {
        if model.email_touched.get() || model.attempted.get() {
          model.email_error()
        } else {
          None
        }
      }),
      @skerry.text("Email format", style=@skerry.TextStyle().shrink(0.0)),
      @skerry.radio_group(
        model.format,
        [PlainText, Html],
        label=fn(format) { format.label() },
        style=@skerry.FlexStyle().spacing(4.0).shrink(0.0),
        item_style=@skerry.RadioStyle().frame(
          @skerry.BoxStyle().height(28.0).min_width(0.0).shrink(0.0),
        ),
        on_change=fn(_) { model.changed() },
      ).debug(name="email-format"),
      @skerry.checkbox(
        checked=model.accepted,
        label="I agree to save these details",
        style=@skerry.CheckboxStyle().frame(@skerry.BoxStyle().shrink(0.0)),
        on_change=fn(_) { model.changed() },
      ),
      validation_message(fn() {
        if model.attempted.get() && !model.accepted.get() {
          Some("Accept before saving.")
        } else {
          None
        }
      }),
      @skerry.row(style=@skerry.FlexStyle().spacing(12.0).shrink(0.0)) <| [
        @skerry.button(
          @skerry.computed(fn() {
            if model.submitted.get() is Some(_) {
              "Saved"
            } else {
              "Save"
            }
          }),
          on_click=fn() { model.submit() },
          style=@skerry.ButtonStyle().surface(
            @skerry.BoxStyle().width(120.0).height(40.0),
          ),
          disabled=@skerry.computed(fn() { !model.valid() }),
        ).debug(name="save"),
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
      ],
      @skerry.text(
        @skerry.bind(fn() { model.submitted.get().unwrap_or("") }),
        style=@skerry.TextStyle().shrink(0.0),
      ).debug(name="result"),
    ],
  ).component("ContactForm")
}

///|
fn validation_message(message : () -> String?) -> @skerry.View {
  @skerry.text(
    @skerry.bind(fn() { message().unwrap_or("") }),
    style=@skerry.TextStyle().shrink(0.0),
  ).component("ValidationMessage")
}
