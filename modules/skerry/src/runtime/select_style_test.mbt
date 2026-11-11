///|
test "select projects global theme rules and reactive parts into its floating list" {
  let height = @reactive.signal(32.0)
  let field = @foundation.Color::rgb(r=30, g=40, b=50)
  let normal = @foundation.Color::rgb(r=60, g=70, b=80)
  let chosen = @foundation.Color::rgb(r=90, g=100, b=110)
  let list = @foundation.Color::rgb(r=120, g=130, b=140)
  let selected = @reactive.signal(Some(0))
  let rules = @style.Styles().add(
    @controls.SelectStyle()
    .surface(@style.BoxStyle().width(230.0).background(field))
    .list(@style.BoxStyle().background(list).max_height(100.0))
    .option(
      @controls.ButtonStyle().surface(
        @style.BoxStyle().background(normal).height(height),
      ),
    )
    .selected(
      @controls.ButtonStyle().surface(@style.BoxStyle().background(chosen)),
    ),
  )
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1, 2].map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        selected~,
      )
    },
    theme=Theme(styles=rules),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let nodes = select_test_nodes(root)
  assert_eq(nodes[0].computed_style.unwrap().background, Some(chosen))
  assert_eq(nodes[1].computed_style.unwrap().background, Some(normal))
  assert_eq(nodes[1].frame.size.height, 32.0)
  let tree = root.snapshot().unwrap().tree.nodes
  let anchor = tree
    .iter()
    .filter(node => node.component_name == "Select")
    .to_array()[0]
  assert_eq(anchor.frame.size.width, 230.0)
  assert_eq(anchor.computed_style.unwrap().background, Some(field))
  let viewport = tree.iter().filter(node => node.scroll is Some(_)).to_array()[0]
  assert_eq(viewport.computed_style.unwrap().background, Some(list))
  assert_eq(viewport.frame.size.width, 230.0)
  let id = nodes[1].id
  height.set(45.0)
  let nodes = select_test_nodes(root)
  assert_eq(nodes[1].id, id)
  assert_eq(nodes[1].frame.size.height, 45.0)
  assert_eq(select_test_active(root), Some(0))
  assert_eq(selected.peek(), Some(0))
  root.set_theme(Theme(palette=@style.Palette::dark(), styles=rules))
  let nodes = select_test_nodes(root)
  assert_eq(nodes[0].computed_style.unwrap().background, Some(chosen))
  assert_eq(nodes[1].id, id)
}

///|
test "select measures its placeholder font even when text equals the selected label" {
  let selected : @reactive.Signal[Int32?] = @reactive.signal(None)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0].map(fn(option) { @controls.SelectOption(option, label="Same") }),
        selected~,
        placeholder="Same",
        style=@controls.SelectStyle().placeholder(
          @view.TextStyle().font(@foundation.FontSpec::default().size(30.0)),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  ignore(select_test_nodes(root))
  let before = root.frame_stats().layout_count
  let anchor = root.snapshot().unwrap().tree.nodes[1]
  assert_eq(
    anchor.computed_style.unwrap().placeholder_font,
    Some(@foundation.FontSpec::default().size(30.0)),
  )
  selected.set(Some(0))
  ignore(select_test_nodes(root))
  assert_eq(root.frame_stats().layout_count, before + 1)
  selected.set(None)
  ignore(select_test_nodes(root))
  assert_eq(root.frame_stats().layout_count, before + 2)
}

///|
test "select supports structural values and locally scoped theme projections" {
  let first : (Int32, String) = (1, "First")
  let second : (Int32, String) = (2, "Second")
  let selected = @reactive.signal(Some(first))
  let color = @foundation.Color::accent()
  let theme = @style.Theme(
    styles=@style.Styles().add(
      @controls.SelectStyle().selected(
        @controls.ButtonStyle().surface(@style.BoxStyle().background(color)),
      ),
    ),
  )
  let root = @runtime.mount(
    fn() {
      @view.style_scope(light_theme=theme, fn() {
        @controls.select(
          [first, second].map(fn(value) {
            @controls.SelectOption(value, label=value.1)
          }),
          selected~,
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  assert_eq(
    select_test_nodes(root)[0].computed_style.unwrap().background,
    Some(color),
  )
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(selected.peek(), Some(second))
}

///|
test "select follows field width changes and remains bounded on a small viewport" {
  let width = @reactive.signal(200.0)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        Array::makei(20, i => i).map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        style=@controls.SelectStyle().surface(@style.BoxStyle().width(width)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  ignore(select_test_nodes(root))
  width.set(280.0)
  ignore(select_test_nodes(root))
  let tree = root.snapshot().unwrap().tree.nodes
  let surface = tree
    .iter()
    .filter(node => node.popup_anchor is Some(_))
    .to_array()[0]
  assert_eq(surface.frame.size.width, 280.0)
  let size = @foundation.Size(width=100.0, height=100.0)
  root.paint(StyleRecorder(), size~)
  let tree = root.snapshot().unwrap().tree.nodes
  let surface = tree
    .iter()
    .filter(node => node.popup_anchor is Some(_))
    .to_array()[0]
  assert_eq(surface.frame.size.width, 100.0)
  assert_true(surface.frame.size.height <= 100.0)
  assert_true(root.key_down(test_key_event(KeyEnd), size~))
  root.paint(StyleRecorder(), size~)
  let tree = root.snapshot().unwrap().tree.nodes
  let viewport = tree.iter().filter(node => node.scroll is Some(_)).to_array()[0]
  let last = tree
    .iter()
    .filter(node => node.component_name == "SelectOption")
    .to_array()
    .last()
    .unwrap()
  assert_true(last.frame.origin.y >= viewport.content.origin.y)
  assert_true(
    last.frame.origin.y + last.frame.size.height <=
    viewport.content.origin.y + viewport.content.size.height + 0.01,
  )
}
