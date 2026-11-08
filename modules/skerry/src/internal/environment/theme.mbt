///|
// Keep the resolved scheme and theme in one update even when theme values match.
#derive(Eq, Debug)
pub(all) struct ThemeContext {
  color_scheme : @style.ColorScheme
  theme : @style.Theme
}

///|
pub extend ThemeContext with Eq::{equal, not_equal}

///|
pub extend ThemeContext with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct ThemeEnvironment {
  base : @style.Theme
  styles : @style.Styles
  context : ThemeContext
}

///|
pub extend ThemeEnvironment with Eq::{equal, not_equal}

///|
pub extend ThemeEnvironment with Debug::{to_repr}

///|
pub fn ThemeEnvironment::ThemeEnvironment(
  base : @style.Theme,
  color_scheme~ : @style.ColorScheme = Light,
  styles~ : @style.Styles = Styles(),
) -> ThemeEnvironment {
  {
    base,
    styles,
    context: {
      color_scheme,
      theme: { ..base, styles: base.styles.merge(styles), },
    },
  }
}

///|
pub struct ThemeProvider {
  value : @reactive.Signal[ThemeEnvironment]
  sheet : @style.StyleSheet
}

///|
let theme_context : @reactive.Context[ThemeProvider?] = Context(None)

///|
pub fn theme_binding(
  value : @reactive.Signal[ThemeEnvironment],
) -> @reactive.ContextBinding {
  let sheet = @style.StyleSheet(value.peek().context.theme.styles)
  ignore(
    @reactive.render_effect(fn() {
      let styles = value.get().context.theme.styles
      @reactive.untracked(fn() { sheet.set(styles) })
    }),
  )
  theme_context.provide(Some({ value, sheet, }))
}

///|
/// Read the nearest theme from the current component context, or the
/// default theme outside a live scope. The signal read tracks inside an effect;
/// this accessor does not create effects or make plain styles reactive.
pub fn current_theme_environment() -> ThemeEnvironment {
  match current_theme_provider() {
    Some(provider) => provider.value.get()
    None => ThemeEnvironment(Theme())
  }
}

///|
/// Read the effective theme; this does not make an eagerly read Color reactive.
pub fn current_theme() -> @style.Theme {
  current_theme_environment().context.theme
}

///|
/// Concrete scheme of this root, including when light/dark Theme values match.
pub fn current_color_scheme() -> @style.ColorScheme {
  current_theme_environment().context.color_scheme
}

///|
let style_theme_override : Ref[ThemeProvider?] = Ref(None)

///|
pub fn current_theme_provider() -> ThemeProvider? {
  match style_theme_override.val {
    Some(_) as provider => provider
    None => theme_context.get()
  }
}

///|
pub fn ThemeProvider::sheet(self : ThemeProvider) -> @style.StyleSheet {
  self.sheet
}

///|
/// Source evaluation keeps lexical model context while using the consuming
/// node's visual theme, including prebuilt Views inside a later style_scope.
pub fn[T] with_style_theme(provider : ThemeProvider?, read : () -> T) -> T {
  let previous = style_theme_override.val
  style_theme_override.val = provider
  defer {
    style_theme_override.val = previous
  }
  read()
}
