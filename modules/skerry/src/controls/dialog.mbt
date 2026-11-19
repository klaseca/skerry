///|
/// A centered modal dialog. Activating the anchor opens it; open optionally
/// exposes the same state to its owner. Manual preserves the anchor's handlers.
/// Content is created once per opening and receives a session-scoped close
/// callback. on_change may prevent either opening or closing.
///
/// The backdrop blocks background pointer, wheel and keyboard input. Focus
/// enters the first available control, Tab stays inside, and closing restores
/// the previous focus. Nested popups remain usable above the dialog. Escape and
/// backdrop presses close by default; each can be disabled separately. A close
/// button can always call close, subject to on_change.
///
/// The surface follows the current theme, fits the viewport and scrolls tall
/// content. DialogStyle customizes the surface and backdrop, including edge
/// spacing through backdrop padding. Layout dimensions use logical pixels.
///
/// ```mbt check
/// test {
///   let view = @controls.dialog(@controls.button("Open"), fn(close) {
///     @view.column([
///       @view.text("Save changes?"),
///       @controls.button("Close", on_click=close),
///     ])
///   })
///   ignore(view)
/// }
/// ```
pub fn dialog(
  anchor : @view.View,
  open? : @reactive.Signal[Bool],
  trigger~ : @view.PopupTrigger = Click,
  style? : DialogStyle,
  close_on_escape~ : Bool = true,
  close_on_backdrop~ : Bool = true,
  on_change? : (@foundation.ChangeEvent[Bool]) -> Unit,
  content : (() -> Unit) -> @view.View,
) -> @view.View {
  let style = style.unwrap_or(DialogStyle())
  @view.modal(
    anchor,
    open?,
    trigger~,
    close_on_escape~,
    close_on_backdrop~,
    on_change?,
    style=@view.FlexStyle()
      .align_items(Center)
      .justify_content(Center)
      .surface(
        @style.BoxStyle()
        .background(@foundation.Color::rgba(r=0, g=0, b=0, a=112))
        .padding(@foundation.Insets::all(24.0))
        .merge(style.select(s => s.backdrop)),
      ),
    fn(close) {
      @view.scroll_view(
        content(close),
        style=@style.BoxStyle()
          .width(420.0)
          .min_width(0.0)
          .min_height(0.0)
          .padding(@foundation.Insets::all(24.0))
          .background(@style.surface_token)
          .stroke(@style.border_token)
          .radius(12.0)
          .merge(style.select(s => s.surface)),
        scrollbar_gutter=true,
      ).component("DialogSurface")
    },
  ).component("Dialog")
}
