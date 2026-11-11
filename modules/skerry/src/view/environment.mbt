///|
priv struct ThemeSpec {
  initial : @style.Theme
  source : () -> @style.Theme
  provider : @environment.ThemeProvider
}

///|
/// Apply light/dark themes and/or concrete style defaults to this subtree. Content
/// runs once and keeps its node identity. Missing variants inherit the parent
/// base theme; additional declarations follow outer scopes, then local BoxStyle.
/// Set inherit_styles=false to isolate this subtree from outer class overlays.
/// Each variant accepts a Theme, Signal, Computed or Binding. A missing variant
/// inherits the parent base theme for the current scheme, not the other variant.
/// A binding may read current_theme() in the parent context. When copying that
/// effective theme including its styles, use inherit_styles=false to avoid
/// appending the same additional declarations again.
/// Build inside an active component/App scope. Signal reads in theme sources are
/// tracked; font/metric changes reflow and appearance changes only repaint.
pub fn style_scope(
  light_theme? : &@value.ThemeSource,
  dark_theme? : &@value.ThemeSource,
  styles~ : @style.Styles = Styles(),
  inherit_styles~ : Bool = true,
  content : () -> View,
) -> View {
  let light_theme = light_theme.map(theme => theme.to_binding())
  let dark_theme = dark_theme.map(theme => theme.to_binding())
  let parent = @reactive.Scope::current().unwrap()
  let scope = parent.child()
  scope.run(fn() {
    let value = @reactive.signal(@environment.current_theme_environment())
    ignore(
      @reactive.render_effect(fn() {
        let next = parent.track(fn() {
          let inherited = @environment.current_theme_environment()
          let selected = match inherited.context.color_scheme {
            Light => light_theme
            Dark => dark_theme
          }
          let base = match selected {
            Some(source) => source.get().inherit_tokens(inherited.base)
            None => inherited.base
          }
          @environment.ThemeEnvironment(
            base,
            color_scheme=inherited.context.color_scheme,
            styles=if inherit_styles {
              inherited.styles.merge(styles)
            } else {
              styles
            },
          )
        })
        if value.peek() != next {
          value.set(next)
        }
      }),
    )
    @reactive.provide([@environment.theme_binding(value)], fn() {
      let view = content()
      let geometry = view.node.geometry.unwrap_or({
        translation: Point(x=0.0, y=0.0),
        clip_frame: false,
        popup: None,
        scroll: None,
        theme: None,
      })
      // The closest provider owns a node returned by consecutive scopes.
      if geometry.theme is Some(_) {
        return view
      }
      view_from_node({
        ..view.node,
        geometry: Some({
          ..geometry,
          theme: Some({
            initial: value.peek().context.theme,
            source: fn() { value.get().context.theme },
            provider: @environment.current_theme_provider().unwrap(),
          }),
        }),
      })
    })
  })
}

///|
/// Custom hosts forward View.mount_reactivity's on_theme_change here, then
/// request a frame when it returns true. Effective metric changes invalidate layout;
/// needs_layout() distinguishes them from appearance changes. Text metrics stay
/// cached, keyed by their font and width.
pub fn LayoutState::set_theme_override(
  self : LayoutState,
  node_id : Int32,
  theme : @style.Theme?,
) -> Bool {
  guard !self.disposed && self.theme_overrides.get(node_id) != theme else {
    false
  }
  let overrides = self.theme_overrides.copy()
  match theme {
    Some(value) => overrides.set(node_id, value)
    None => ignore(overrides.remove(node_id))
  }
  let layout_changed = self.theme_layout_changed(self.theme, overrides)
  match theme {
    Some(value) => self.theme_overrides.set(node_id, value)
    None => ignore(self.theme_overrides.remove(node_id))
  }
  if layout_changed {
    self.invalidate()
  }
  self.painted = false
  true
}
