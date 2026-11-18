///|
test "merge keeps a component base before incoming projected declarations" {
  let base = @style.BoxStyle().padding(@foundation.Insets::all(4.0))
  let sheet = @style.StyleSheet(
    @style.Styles().add(PanelFrameStyle::{
      surface: @style.BoxStyle().padding(@foundation.Insets::all(8.0)),
    }),
  )
  let incoming = PanelFrameStyle::{ surface: @style.BoxStyle(), }.select(s => {
    s.surface
  })
  let read = fn(value) {
    let layers = @style.StyleDeclaration(value).resolve(sheet)
    let mut padding = None
    for layer in layers {
      if layer.layout.layout.padding is Some(value) {
        padding = Some(value)
      }
    }
    padding
  }
  assert_eq(read(base.merge(incoming)), Some(@foundation.Insets::all(8.0)))
  assert_eq(read(incoming.merge(base)), Some(@foundation.Insets::all(4.0)))
  let explicit = @style.BoxStyle().padding(@foundation.Insets::all(0.0))
  assert_eq(
    read(base.merge(incoming).merge(explicit)),
    Some(@foundation.Insets::all(0.0)),
  )
  assert_eq(
    read(base.merge(incoming.merge(explicit))),
    read(base.merge(incoming).merge(explicit)),
  )
  assert_eq(
    read(base.merge(incoming).merge(@style.BoxStyle())),
    read(base.merge(incoming)),
  )
}

///|
test "frozen composition keeps the same order and declaration boundaries" {
  let sheet = @style.StyleSheet(
    @style.Styles().add(PanelFrameStyle::{
      surface: @style.BoxStyle().padding(@foundation.Insets::all(8.0)),
    }),
  )
  let base = @style.BoxStyle().padding(@foundation.Insets::all(4.0))
  let incoming = PanelFrameStyle::{ surface: @style.BoxStyle(), }.select(s => {
    s.surface
  })
  let freeze = fn(value) { @style.freeze_style(value, sheet) }
  assert_eq(
    @style.style_layers(freeze(base.merge(incoming))),
    @style.style_layers(freeze(base).merge(freeze(incoming))),
  )
  let explicit = @style.BoxStyle().padding(@foundation.Insets::all(0.0))
  assert_eq(
    @style.style_layers(freeze(base.merge(incoming).merge(explicit))),
    @style.style_layers(
      freeze(base).merge(freeze(incoming).merge(freeze(explicit))),
    ),
  )
}

///|
test "literal and computed fragments share state priority while projections retain declarations" {
  let red = @foundation.Color::rgb(r=190, g=20, b=30)
  let blue = @foundation.Color::rgb(r=20, g=40, b=190)
  let base = @style.BoxStyle().hovered(@style.Appearance().background(red))
  let normal = @style.BoxStyle().background(blue)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button(
          "Literal",
          style=@controls.ButtonStyle().surface(base.merge(normal)),
        ),
        @controls.button(
          "Computed",
          style=@controls.ButtonStyle().surface(
            base.merge(@style.BoxStyle::computed(fn() { normal })),
          ),
        ),
        @controls.button(
          "Projected",
          style=@controls.ButtonStyle().surface(
            base.merge(
              PanelFrameStyle::{ surface: normal, }.select(s => s.surface),
            ),
          ),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=240.0, height=180.0)
  root.paint(StyleRecorder(), size~)
  for index in 1..<=3 {
    let node = root.snapshot().unwrap().tree.nodes[index]
    ignore(
      root.pointer_move(
        size~,
        point=@foundation.Point(
          x=node.frame.origin.x + 1.0,
          y=node.frame.origin.y + 1.0,
        ),
      ),
    )
    root.paint(StyleRecorder(), size~)
    let node = root.snapshot().unwrap().tree.nodes[index]
    assert_true(node.state.hovered)
    assert_eq(
      node.computed_style.unwrap().background,
      Some(if index == 3 { blue } else { red }),
    )
  }
}

///|
test "projected theme states do not override a later local normal declaration" {
  let red = @foundation.Color::rgb(r=190, g=20, b=30)
  let blue = @foundation.Color::rgb(r=20, g=40, b=190)
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "Projected",
        style=@controls.ButtonStyle().surface(
          @style.BoxStyle()
          .radius(3.0)
          .merge(
            PanelFrameStyle::{ surface: @style.BoxStyle().background(blue), }.select(s => {
                s.surface
              },
            ),
          ),
        ),
      )
    },
    theme=@style.Theme(
      styles=@style.Styles().add(PanelFrameStyle::{
        surface: @style.BoxStyle().hovered(@style.Appearance().background(red)),
      }),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=240.0, height=80.0)
  ignore(root.pointer_move(size~, point=@foundation.Point(x=5.0, y=5.0)))
  root.paint(StyleRecorder(), size~)
  let node = root.snapshot().unwrap().tree.nodes[0]
  assert_true(node.state.hovered)
  assert_eq(node.computed_style.unwrap().background, Some(blue))
}

///|
test "nested projections retain theme and type origins without sampling on inspection" {
  let reads = Ref(0)
  let projected = OuterPanelStyle::{ panel: PanelStyle(), }
    .select(fn(s) {
      reads.val += 1
      s.panel
    })
    .select(fn(s) {
      reads.val += 1
      s.title
    })
  let sheet = @style.StyleSheet(
    @style.Styles().add(OuterPanelStyle::{
      panel: PanelStyle().title(
        @view.TextStyle().color(@foundation.Color::accent()),
      ),
    }),
  )
  let declaration = @style.StyleDeclaration(projected)
  let layers = declaration.resolve(sheet)
  assert_true(
    layers[0].origin
    is @style.StyleOrigin::Projection(
      from=panel,
      to=text,
      source=@style.StyleOrigin::Projection(
        from=outer,
        to=inner,
        source=@style.StyleOrigin::ThemeRule(rule=0, family~, ..),
      ),
    ) &&
    panel.has_suffix("PanelStyle") &&
    text.has_suffix("TextStyle") &&
    outer.has_suffix("OuterPanelStyle") &&
    inner == panel &&
    family == outer,
  )
  let count = reads.val
  let specified : @view.TextStyle = declaration
    .snapshot(layers)
    .unwrap()
    .get()
    .unwrap()
  assert_eq(specified.color, None)
  ignore(layers[0].origin.to_repr())
  ignore(declaration.snapshot(layers))
  assert_eq(reads.val, count)
}

///|
test "a reactive base stays before projections and resumes when their override is removed" {
  let width = @reactive.signal(40.0)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      @view.column(
        [
          @view.box(
            style=@style.BoxStyle()
              .width(width)
              .height(20.0)
              .merge(
                PanelFrameStyle::{ surface: @style.BoxStyle(), }.select(s => {
                  s.surface
                }),
              ),
          ),
        ],
        style=@view.FlexStyle().align_items(Start),
      )
    },
    theme=@style.Theme(
      styles=@style.Styles().add(PanelFrameStyle::{
        surface: @style.BoxStyle().width(80.0),
      }),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=240.0, height=80.0)
  root.paint(StyleRecorder(), size~)
  let id = root.snapshot().unwrap().tree.nodes[1].id
  width.set(50.0)
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 80.0)
  root.set_theme(@style.Theme())
  root.paint(StyleRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].frame.size.width, 50.0)
  width.set(60.0)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(StyleRecorder(), size~)
  let node = root.snapshot().unwrap().tree.nodes[1]
  assert_eq(node.frame.size.width, 60.0)
  assert_eq(node.id, id)
  assert_eq(builds.val, 1)
}

///|
test "theme origins distinguish lookup sheets without changing value equality" {
  let rules = @style.Styles().add(@style.BoxStyle().radius(8.0))
  let first = @style.StyleSheet(rules)
  let second = @style.StyleSheet(rules)
  let declaration = @style.StyleDeclaration(@style.BoxStyle())
  let a = declaration.resolve(first)[0]
  let b = declaration.resolve(second)[0]
  assert_eq(a, b)
  assert_true(
    a.origin is @style.StyleOrigin::ThemeRule(sheet=a, rule=0, ..) &&
    b.origin is @style.StyleOrigin::ThemeRule(sheet=b, rule=0, ..) &&
    a != b,
  )
}
