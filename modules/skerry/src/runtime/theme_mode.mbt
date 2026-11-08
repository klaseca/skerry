///|
/// Application preference. System follows the host; an unknown host uses Light.
#derive(Eq, Debug)
pub(all) enum ThemeMode {
  Light
  Dark
  System
}

///|
pub extend ThemeMode with Eq::{equal, not_equal}

///|
pub extend ThemeMode with Debug::{to_repr}

///|
pub using @style {type ColorScheme}

///|
let app_context : @reactive.Context[App?] = Context(None)

///|
/// Read the owning App from the current component context. Lookup returns the
/// existing handle without subscriptions; state getters track their own reads.
/// Requires a live App scope; low-level mount does not create an application.
pub fn current_app() -> App {
  app_context.get().unwrap()
}

///|
/// Read the selected preference, with dependency tracking inside an effect.
pub fn App::theme_mode(self : App) -> ThemeMode {
  self.mode.get()
}

///|
/// Change the preference for all roots mounted by this application.
/// Equal preferences request no work. Mode remains System while the host changes.
pub fn App::set_theme_mode(self : App, mode : ThemeMode) -> Unit {
  if self.mode.peek() != mode {
    self.mode.set(mode)
  }
}

///|
fn App::resolve_theme(
  self : App,
  system : @reactive.Signal[ColorScheme?],
) -> @environment.ThemeContext {
  let color_scheme : ColorScheme = match self.mode.get() {
    Light => Light
    Dark => Dark
    System => system.get().unwrap_or(Light)
  }
  let theme = match color_scheme {
    Light => self.light_theme.map(source => source.get()).unwrap_or(Theme())
    Dark =>
      self.dark_theme
      .map(source => source.get())
      .unwrap_or(Theme(palette=@style.Palette::dark()))
  }
  { color_scheme, theme, }
}

///|
/// Hosts report initial scheme to App.mount and later changes here.
/// This is independent of the selected preference; unknown schemes use Light.
pub fn UiRoot::set_system_theme(self : UiRoot, theme : ColorScheme?) -> Unit {
  guard !self.disposed else { return }
  if self.system_theme_value.peek() != theme {
    self.system_theme_value.set(theme)
  }
}
