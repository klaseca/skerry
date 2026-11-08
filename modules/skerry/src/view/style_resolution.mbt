///|
priv struct AppliedStyles {
  mut mounted : Bool
  mut rules : @style.Styles?
  mut layers : ReadOnlyArray[@style.StyleDeclaration]?
  mut sheet : @style.StyleSheet
  mut provider : @environment.ThemeProvider?
}

///|
priv struct NodeStyles {
  specified : @style.StyleDeclaration
  read : @reactive.Binding[ReadOnlyArray[@style.StyleDeclaration]]
  state : AppliedStyles
}

///|
fn NodeStyles::NodeStyles(specified : @style.StyleDeclaration) -> NodeStyles {
  let state = AppliedStyles::{
    mounted: false,
    rules: None,
    layers: None,
    sheet: @style.StyleSheet(@style.Styles()),
    provider: None,
  }
  {
    specified,
    state,
    read: @reactive.bind(fn() {
      @environment.with_style_theme(state.provider, fn() {
        specified.resolve(state.sheet)
      })
    }),
  }
}

///|
fn NodeStyles::layers(
  self : NodeStyles,
  theme : @style.Theme,
) -> ReadOnlyArray[@style.StyleDeclaration] {
  let applied = self.state
  if applied.mounted && applied.layers is Some(layers) {
    return layers
  }
  if applied.rules != Some(theme.styles) || applied.layers is None {
    applied.layers = Some(
      @reactive.untracked(fn() {
        self.specified.resolve(StyleSheet(theme.styles))
      }),
    )
    applied.rules = Some(theme.styles)
  }
  applied.layers.unwrap()
}

///|
fn NodeStyles::mount(self : NodeStyles, host : MountContext) -> () -> Unit {
  let applied = self.state
  applied.mounted = true
  if host.style_sheet is Some(sheet) {
    applied.sheet = sheet
  }
  applied.provider = host.style_theme
  let owner = @reactive.Scope::current()
  let producer : Ref[(() -> Unit)?] = Ref(None)
  let materialize = fn() {
    let layers = self.read.get()
    @reactive.untracked(fn() {
      guard applied.mounted else { return }
      let before = applied.layers
      applied.layers = Some(layers)
      if before is Some(before) && before != layers {
        if styles_layout_changed(before, layers) {
          (host.mark_layout_dirty)()
        } else {
          (host.mark_paint_dirty)()
        }
      }
    })
  }
  let observe = self.specified.observe(applied.sheet, fn(dynamic) {
    match (dynamic, producer.val) {
      (true, None) => {
        let start = fn() { @reactive.render_effect(materialize) }
        producer.val = Some(
          match owner {
            Some(owner) => owner.run(start)
            None => start()
          },
        )
      }
      (false, previous) => {
        if previous is Some(stop) {
          stop()
          producer.val = None
        }
        match owner {
          Some(owner) => owner.run(materialize)
          None => @reactive.untracked(materialize)
        }
      }
      _ => ()
    }
  })
  fn() {
    observe()
    if producer.val is Some(stop) {
      stop()
      producer.val = None
    }
    applied.mounted = false
    applied.layers = None
    applied.rules = None
    applied.provider = None
    applied.sheet = @style.StyleSheet(@style.Styles())
  }
}

///|
fn styles_layout_changed(
  before : ReadOnlyArray[@style.StyleDeclaration],
  after : ReadOnlyArray[@style.StyleDeclaration],
) -> Bool {
  let summarize = fn(layers : ReadOnlyArray[@style.StyleDeclaration]) {
    let mut style = @style.BoxStyle()
    let mut metrics = @style.StyleMetrics()
    for layer in layers {
      style = style.merge(layer.layout)
      metrics = metrics.merge(layer.metrics)
    }
    (style, metrics)
  }
  let (a, am) = summarize(before)
  let (b, bm) = summarize(after)
  a.layout != b.layout ||
  a.flex != b.flex ||
  a.text.font != b.text.font ||
  am != bm
}

///|
priv struct StyleTree {
  id : Int32
  theme : @style.Theme?
  styles : NodeStyles?
  children : Array[StyleTree]
}

///|
fn UiNode::style_tree(self : UiNode) -> StyleTree {
  {
    id: self.id,
    theme: self.provided_theme(),
    styles: self.styles,
    children: self.children.val.map(child => child.style_tree()),
  }
}

///|
fn StyleTree::layout_changed(
  self : StyleTree,
  previous : StyleContext,
  next : StyleContext,
) -> Bool {
  let previous = previous.for_node(self.id, self.theme, self.styles)
  let next = next.for_node(self.id, self.theme, self.styles)
  if previous.style.layout != next.style.layout ||
    previous.style.flex != next.style.flex ||
    previous.resolved_font() != next.resolved_font() ||
    previous.metrics != next.metrics {
    return true
  }
  self.children.any(child => child.layout_changed(previous, next))
}

///|
fn LayoutState::theme_layout_changed(
  self : LayoutState,
  next : @style.Theme,
  overrides : Map[Int32, @style.Theme],
) -> Bool {
  match self.style_tree {
    Some(tree) =>
      tree.layout_changed(
        StyleContext(self.theme, self.theme_overrides),
        StyleContext(next, overrides),
      )
    None => true
  }
}
