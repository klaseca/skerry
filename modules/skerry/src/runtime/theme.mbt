///|
pub fn UiRoot::theme(self : UiRoot) -> @style.Theme {
  self.layout_state.theme()
}

///|
/// Update this root's defaults without remounting. Font changes request layout;
/// colors and other appearance changes request paint. Equal themes and disposed
/// roots request no work. Context-dependent subtree themes settle before wakeup.
///
/// ```mbt check
/// test {
///   let system = @text.TextLayoutSystem::from_metrics(
///     TextMetricsProvider(measure=fn(_) {
///       TextMetrics(width=0.0, line_height=20.0, baseline=16.0, caret_positions=[])
///     }),
///   )
///   let root = @runtime.mount(@view.empty, text_layout_system=system)
///   defer root.dispose()
///   let dark = @style.Theme(palette=@style.Palette::dark())
///   root.set_theme(dark)
///   assert_eq(root.theme(), dark)
/// }
/// ```
pub fn UiRoot::set_theme(
  self : UiRoot,
  theme : @style.Theme,
  color_scheme? : ColorScheme,
) -> Unit {
  self.set_theme_context({
    color_scheme: color_scheme.unwrap_or(
      self.theme_environment.peek().context.color_scheme,
    ),
    theme,
  })
}

///|
pub fn UiRoot::color_scheme(self : UiRoot) -> ColorScheme {
  self.theme_environment.peek().context.color_scheme
}

///|
fn UiRoot::set_theme_context(
  self : UiRoot,
  context : @environment.ThemeContext,
) -> Unit {
  guard !self.disposed else { return }
  self.scope.run(fn() {
    @reactive.during_update(fn() {
      if self.layout_state.set_theme(context.theme) {
        if self.layout_state.needs_layout() {
          self.mark_layout_dirty()
        } else {
          self.mark_paint_dirty()
        }
      }
      let environment = @environment.ThemeEnvironment(
        context.theme,
        color_scheme=context.color_scheme,
      )
      if self.theme_environment.peek() != environment {
        self.theme_environment.set(environment)
      }
    })
  })
}
