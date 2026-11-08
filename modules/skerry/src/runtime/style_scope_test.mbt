///|
test "style scopes inherit append and isolate typed declarations" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=20, g=150, b=50)
  let blue = @foundation.Color::rgb(r=30, g=60, b=180)
  let font = @foundation.FontSpec::default().size(18.0)
  let component = @controls.ButtonStyle().label(@view.TextStyle().color(blue))
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("outside"),
        @view.style_scope(
          styles=@style.Styles()
            .add(
              @controls.ButtonStyle().surface(
                @style.BoxStyle().radius(10.0).background(green),
              ),
            )
            .add(
              SimpleCardStyle().surface(
                @view.FlexStyle().padding(@foundation.Insets::all(12.0)),
              ),
            ),
        ) <| fn() {
          @view.column([
            @controls.button("outer"),
            @view.style_scope(
              styles=@style.Styles().add(
                @controls.ButtonStyle().surface(
                  @style.BoxStyle().height(56.0).radius(14.0),
                ),
              ),
            ) <| fn() {
              styled_card([
                @controls.button("inner"),
                @controls.button(
                  "local",
                  style=@controls.ButtonStyle().surface(
                    @style.BoxStyle().radius(2.0).background(blue),
                  ),
                ),
              ])
            },
            @controls.button("outer sibling"),
          ])
        },
      ])
    },
    theme=Theme(
      font~,
      palette=@style.Palette::dark(),
      styles=@style.Styles()
        .add(component)
        .add(
          @controls.ButtonStyle().surface(
            @style.BoxStyle()
            .width(180.0)
            .height(48.0)
            .radius(4.0)
            .hovered(@style.Appearance().background(red)),
          ),
        ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=400.0, height=600.0)
  root.paint(renderer, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes.length(), 8)
  for pair in [(1, 4.0), (3, 10.0), (5, 14.0), (6, 2.0), (7, 10.0)] {
    let (index, radius) = pair
    assert_eq(nodes[index].frame.size.width, 180.0)
    assert_eq(nodes[index].computed_style.unwrap().radius, Some(radius))
    assert_eq(nodes[index].theme.font, font)
    assert_eq(
      nodes[index].theme.tokens,
      @style.Theme(palette=@style.Palette::dark()).tokens,
    )
    assert_eq(nodes[index].theme.styles.get()[0], component)
  }
  assert_eq(nodes[1].frame.size.height, 48.0)
  assert_eq(nodes[3].frame.size.height, 48.0)
  assert_eq(nodes[5].frame.size.height, 56.0)
  assert_eq(nodes[6].frame.size.height, 56.0)
  assert_eq(nodes[7].frame.size.height, 48.0)
  assert_eq(nodes[4].padding, @foundation.Insets::all(12.0))
  ignore(
    root.pointer_move(
      size~,
      point=Point(
        x=nodes[3].frame.origin.x + 5.0,
        y=nodes[3].frame.origin.y + 5.0,
      ),
    ),
  )
  root.paint(renderer, size~)
  let hovered = root.snapshot().unwrap().tree.nodes[3]
  assert_true(hovered.state.hovered)
  assert_eq(hovered.computed_style.unwrap().background, Some(green))
  assert_eq(nodes[6].computed_style.unwrap().background, Some(blue))
}

///|
test "consecutive style scopes keep one node and settle before synchronous wakeup" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=20, g=150, b=50)
  let original_id : Ref[Int32?] = Ref(None)
  let builds = Ref(0)
  let seen : Array[@style.Theme] = []
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        styles=@style.Styles().add(
          @controls.ButtonStyle().surface(@style.BoxStyle().radius(10.0)),
        ),
      ) <| fn() {
        @view.style_scope(
          styles=@style.Styles().add(
            @controls.ButtonStyle().surface(
              @style.BoxStyle().padding(@foundation.Insets::all(12.0)),
            ),
          ),
        ) <| fn() {
          builds.val += 1
          let view = @controls.button("button", on_click=fn() {
            seen.push(@environment.current_theme())
          })
          original_id.val = view.node_id_at_path([])
          view
        }
      }
    },
    theme=Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().color(red)),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=220.0, height=80.0)
  root.paint(renderer, size~)
  let initial = root.snapshot().unwrap().tree.nodes
  assert_eq(initial.length(), 1)
  assert_eq(Some(initial[0].id), original_id.val)
  let fonts : Array[Double] = []
  let colors : Array[@foundation.Color?] = []
  root.set_wakeup(fn() {
    root.paint(renderer, size~)
    let node = root.snapshot().unwrap().tree.nodes[0]
    fonts.push(node.computed_style.unwrap().font.unwrap().point_size())
    colors.push(node.computed_style.unwrap().color)
  })
  let font = @foundation.FontSpec::default().size(26.0)
  root.set_theme(
    Theme(
      font~,
      palette=@style.Palette::dark(),
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().color(green)),
      ),
    ),
  )
  root.set_wakeup(fn() { () })
  assert_eq(fonts, [26.0])
  assert_eq(colors, [Some(green)])
  assert_false(root.needs_frame())
  let node = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(Some(node.id), original_id.val)
  assert_eq(node.padding, @foundation.Insets::all(12.0))
  assert_eq(node.computed_style.unwrap().radius, Some(10.0))
  assert_eq(builds.val, 1)
  assert_true(root.click_at(size~, point=Point(x=20.0, y=20.0)))
  assert_eq(seen.length(), 1)
  assert_eq(seen[0].font, font)
  assert_eq(seen[0].tokens, @style.Theme(palette=@style.Palette::dark()).tokens)
  assert_eq(
    (seen[0].styles.get() : ReadOnlyArray[@controls.ButtonStyle]).length(),
    3,
  )
}

///|
test "parent theme updates preserve scope state and distinguish paint from layout" {
  let value = @reactive.signal("abc")
  let builds = Ref(0)
  let initial_styles = @style.Styles()
    .add(
      @controls.TextInputStyle().surface(
        @style.BoxStyle().width(160.0).padding(@foundation.Insets::all(30.0)),
      ),
    )
    .add(@controls.ButtonStyle().surface(@style.BoxStyle().height(40.0)))
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.style_scope(
          styles=@style.Styles().add(
            @controls.TextInputStyle().surface(
              @style.BoxStyle().padding(@foundation.Insets::all(8.0)),
            ),
          ),
        ) <| fn() {
          @view.style_scope(
            styles=@style.Styles().add(
              @controls.ButtonStyle().surface(@style.BoxStyle().radius(12.0)),
            ),
          ) <| fn() {
            builds.val += 1
            @view.column([
              @controls.text_input(value~),
              @controls.button("inside"),
            ])
          }
        },
        @controls.button("outside"),
      ])
    },
    theme=Theme(styles=initial_styles),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=300.0, height=240.0)
  root.paint(renderer, size~)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let paint_styles = initial_styles.add(
    @controls.TextInputStyle().surface(
      @style.BoxStyle().padding(@foundation.Insets::all(40.0)),
    ),
  )
  root.set_theme(Theme(palette=@style.Palette::dark(), styles=paint_styles))
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  let painted = root.snapshot().unwrap()
  assert_eq(painted.frame.layout_count, before.frame.layout_count)
  assert_eq(painted.frame.text_measure_count, before.frame.text_measure_count)
  assert_eq(painted.tree.nodes[2].padding, @foundation.Insets::all(8.0))
  assert_eq(painted.tree.nodes[3].computed_style.unwrap().radius, Some(12.0))
  assert_eq(painted.tree.nodes[4].computed_style.unwrap().radius, Some(6.0))
  let changed_theme = @style.Theme(
    font=@foundation.FontSpec::default().size(20.0),
    palette=@style.Palette::dark(),
    styles=@style.Styles()
      .add(@controls.TextInputStyle().surface(@style.BoxStyle().width(210.0)))
      .add(@controls.ButtonStyle().surface(@style.BoxStyle().height(50.0))),
  )
  root.set_theme(changed_theme)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  let changed = root.snapshot().unwrap()
  assert_eq(changed.tree.nodes[2].frame.size.width, 210.0)
  assert_eq(changed.tree.nodes[2].padding, @foundation.Insets::all(8.0))
  assert_eq(changed.tree.nodes[3].frame.size.height, 50.0)
  assert_eq(changed.tree.nodes[4].frame.size.height, 50.0)
  assert_eq(changed.focused_node_id, before.focused_node_id)
  assert_eq(root.copy_text(), Some("abc"))
  assert_eq(value.get(), "abc")
  assert_eq(builds.val, 1)
  for index in 0..<before.tree.nodes.length() {
    assert_eq(changed.tree.nodes[index].id, before.tree.nodes[index].id)
  }
  root.set_theme(changed_theme)
  assert_false(root.needs_frame())
}

///|
test "pointer input uses scope padding and updated parent font before painting" {
  let value = @reactive.signal("abcd")
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.style_scope(
          styles=@style.Styles().add(
            @controls.TextInputStyle().surface(
              @style.BoxStyle().padding(@foundation.Insets::all(40.0)),
            ),
          ),
        ) <| fn() { @controls.text_input(value~) },
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=260.0, height=140.0)
  root.paint(renderer, size~)
  let id = root.snapshot().unwrap().tree.nodes[1].id
  root.set_theme(
    Theme(
      font=@foundation.FontSpec::default().size(20.0),
      styles=@style.Styles().add(
        @controls.TextInputStyle().surface(
          @style.BoxStyle().width(220.0).padding(@foundation.Insets::all(5.0)),
        ),
      ),
    ),
  )
  assert_true(root.pointer_down(size~, point=Point(x=43.0, y=50.0)))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "Xabcd")
  root.paint(renderer, size~)
  let node = root.snapshot().unwrap().tree.nodes[1]
  assert_eq(node.id, id)
  assert_eq(node.padding, @foundation.Insets::all(40.0))
  assert_eq(node.frame.size.width, 220.0)
  assert_eq(node.computed_style.unwrap().font.unwrap().point_size(), 20.0)
}

///|
test "style scope context and subscriptions end with their dynamic branch" {
  let visible = @reactive.signal(true)
  let builds = Ref(0)
  let reads = Ref(0)
  let cleanups = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @view.style_scope(
          styles=@style.Styles().add(
            @controls.ButtonStyle().surface(@style.BoxStyle().height(44.0)),
          ),
        ) <| fn() {
          builds.val += 1
          @reactive.on_cleanup(fn() { cleanups.val += 1 })
          ignore(
            @reactive.effect(fn() {
              ignore(@environment.current_theme())
              reads.val += 1
            }),
          )
          @controls.button("branch")
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=180.0, height=100.0)
  root.paint(renderer, size~)
  ignore(root.snapshot())
  assert_eq(reads.val, 1)
  root.set_theme(Theme(palette=@style.Palette::dark()))
  assert_eq(reads.val, 2)
  visible.set(false)
  root.paint(renderer, size~)
  assert_eq(cleanups.val, 1)
  root.set_theme(Theme(font=@foundation.FontSpec::default().size(20.0)))
  root.paint(renderer, size~)
  assert_eq(reads.val, 2)
  visible.set(true)
  root.paint(renderer, size~)
  assert_eq(builds.val, 2)
  assert_eq(reads.val, 3)
  let node = root.snapshot().unwrap().tree.nodes[1]
  assert_eq(node.frame.size.height, 44.0)
  assert_eq(node.computed_style.unwrap().font.unwrap().point_size(), 20.0)
  root.dispose()
  assert_eq(cleanups.val, 2)
  root.set_theme(Theme(palette=@style.Palette::dark()))
  assert_eq(reads.val, 3)
  assert_eq(@environment.current_theme(), Theme())
}

///|
test "style scopes can replace base styles or derive them explicitly" {
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        styles=@style.Styles().add(
          @controls.ButtonStyle().surface(@style.BoxStyle().radius(9.0)),
        ),
      ) <| fn() {
        @view.column([
          @view.style_scope(light_theme=@style.Theme(), inherit_styles=false, fn() {
            @controls.button("replace")
          }),
          @view.style_scope(
            light_theme=@reactive.bind(fn() {
              let parent = @environment.current_theme()
              parent.palette(Palette())
            }),
            inherit_styles=false,
            fn() { @controls.button("derive") },
          ),
          @view.style_scope(
            styles=@style.Styles().add(
              @controls.ButtonStyle().surface(@style.BoxStyle().height(52.0)),
            ),
          ) <| fn() { @controls.button("append") },
        ])
      }
    },
    theme=Theme(
      font=@foundation.FontSpec::default().size(20.0),
      palette=@style.Palette::dark(),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=260.0, height=240.0)
  root.paint(renderer, size~)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes.length(), 4)
  assert_eq(nodes[1].computed_style.unwrap().radius, Some(6.0))
  assert_eq(nodes[2].computed_style.unwrap().radius, Some(9.0))
  assert_eq(nodes[3].computed_style.unwrap().radius, Some(9.0))
  assert_eq(nodes[1].theme, Theme())
  assert_eq(nodes[2].theme.tokens, @style.Theme().tokens)
  assert_eq(
    nodes[3].theme.tokens,
    @style.Theme(palette=@style.Palette::dark()).tokens,
  )
  assert_eq(nodes[3].frame.size.height, 52.0)
  root.set_theme(Theme(font=@foundation.FontSpec::default().size(24.0)))
  root.paint(renderer, size~)
  let updated = root.snapshot().unwrap().tree.nodes
  assert_eq(updated[1].theme, Theme())
  assert_eq(updated[2].theme.font.point_size(), 24.0)
  assert_eq(updated[3].theme.font.point_size(), 24.0)
  assert_eq(updated[3].theme.tokens, @style.Theme().tokens)
}
