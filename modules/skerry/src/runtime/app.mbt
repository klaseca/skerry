///|
/// Window dimensions are logical UI units. Native hosts convert them using the
/// display scale and pixel density of the window.
pub(all) struct WindowOptions {
  title : String
  width : Int32
  height : Int32
  // None follows the root theme's surface color at each SDL paint.
  clear : @foundation.Color?
}

///|
pub struct App {
  priv options : WindowOptions
  priv content : () -> @view.View
  priv mode : @reactive.Signal[ThemeMode]
  priv light_theme : @reactive.Binding[@style.Theme]?
  priv dark_theme : @reactive.Binding[@style.Theme]?
  priv providers : Array[@reactive.ContextBinding]
  priv on_mount : ((UiRoot) -> Unit)?
}

///|
pub fn WindowOptions::WindowOptions(
  title~ : String = "Skerry",
  width~ : Int32 = 800,
  height~ : Int32 = 600,
  clear? : @foundation.Color,
) -> WindowOptions {
  { title, width, height, clear, }
}

///|
/// Configure an application. Theme mode is owned by App and defaults to System.
/// Built-in light/dark themes work without application signals or subscriptions.
/// Custom visual defaults can replace either theme independently.
/// Each variant accepts a Theme, Signal, Computed or Binding. Only the selected
/// variant is read; a missing variant uses its corresponding built-in theme.
pub fn App::App(
  title~ : String = "Skerry",
  width~ : Int32 = 800,
  height~ : Int32 = 600,
  clear? : @foundation.Color,
  theme_mode~ : ThemeMode = System,
  light_theme? : &@value.ThemeSource,
  dark_theme? : &@value.ThemeSource,
  providers~ : Array[@reactive.ContextBinding] = [],
  content~ : () -> @view.View,
  on_mount? : (UiRoot) -> Unit,
) -> App {
  {
    options: WindowOptions(title~, width~, height~, clear?),
    mode: @reactive.signal(theme_mode),
    light_theme: light_theme.map(theme => theme.to_binding()),
    dark_theme: dark_theme.map(theme => theme.to_binding()),
    providers: providers.copy(),
    content,
    on_mount,
  }
}

///|
pub fn App::options(self : App) -> WindowOptions {
  self.options
}

///|
pub fn App::mount(
  self : App,
  text_layout_system~ : @text.TextLayoutSystem,
  system_theme? : ColorScheme,
  clock~ : () -> Double = monotonic_milliseconds,
) -> UiRoot {
  let root = mount_configured(
    self.content,
    text_layout_system~,
    clock~,
    providers=self.providers,
    app=self,
    system_theme?,
  )
  if self.on_mount is Some(on_mount) {
    root.scope.run(fn() { on_mount(root) })
  }
  root
}
