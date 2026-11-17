///|
fn select_test_nodes(
  root : @runtime.UiRoot,
) -> Array[@diagnostics.NodeSnapshot] {
  root.paint(StyleRecorder(), size=Size(width=320.0, height=400.0))
  root.snapshot().unwrap().tree.nodes
  .iter()
  .filter(node => node.component_name == "SelectOption")
  .to_array()
}

///|
fn select_test_active(root : @runtime.UiRoot) -> Int32? {
  for index, node in select_test_nodes(root) {
    if node.state.focused {
      return Some(index)
    }
  }
  None
}

///|
fn select_test_open(root : @runtime.UiRoot) -> Unit raise {
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
}

///|
test "select separates keyboard navigation from committing the model" {
  let selected = @reactive.signal(Some(1))
  let changes : Array[Int32?] = []
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1, 2].map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        selected~,
        on_change=fn(event) { changes.push(event.value) },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  assert_eq(select_test_active(root), Some(1))
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(select_test_active(root), Some(2))
  assert_eq(selected.peek(), Some(1))
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(select_test_active(root), Some(0))
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_eq(select_test_active(root), Some(2))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_eq(select_test_active(root), Some(0))
  assert_true(changes.is_empty())
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(selected.peek(), Some(0))
  assert_eq(changes, [Some(0)])
  assert_true(root.view().popup_targets().is_empty())
  root.paint(StyleRecorder(), size=Size(width=320.0, height=400.0))
  assert_eq(
    root.snapshot().unwrap().focused_node_id,
    root.view().node_id_at_path([0]),
  )
}

///|
test "select owns its selection and restores it when reopened" {
  let changes : Array[String?] = []
  let root = @runtime.mount(
    fn() {
      @controls.select(
        ["One", "Two"].map(fn(value) {
          @controls.SelectOption(value, label=value)
        }),
        on_change=fn(event) { changes.push(event.value) },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  assert_eq(select_test_active(root), Some(0))
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_eq(changes, [Some("Two")])
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(select_test_active(root), Some(1))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(changes, [Some("Two")])
}

///|
test "select veto keeps the list open while Escape cancels navigation" {
  let selected = @reactive.signal(Some(0))
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1].map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        selected~,
        on_change=fn(event) { event.prevent_default() },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(selected.peek(), Some(0))
  assert_eq(select_test_active(root), Some(1))
  assert_eq(root.view().popup_targets().length(), 1)
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(root.view().popup_targets().is_empty())
  assert_eq(selected.peek(), Some(0))
}

///|
test "select searches Unicode labels with prefix timeout and repeated-letter cycling" {
  let now = Ref(0.0)
  let selected : @reactive.Signal[String?] = @reactive.signal(None)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        ["Apple", "Apricot", "Banana", "Blueberry", "Вишня"].map(fn(
          value,
        ) {
          @controls.SelectOption(value, label=value)
        }),
        selected~,
      )
    },
    clock=fn() { now.val },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  assert_true(root.text_input("b"))
  assert_eq(select_test_active(root), Some(2))
  assert_true(root.text_input("b"))
  assert_eq(select_test_active(root), Some(3))
  now.val = 1000.0
  assert_true(root.text_input("a"))
  assert_eq(select_test_active(root), Some(0))
  assert_true(root.text_input("p"))
  assert_true(root.text_input("r"))
  assert_eq(select_test_active(root), Some(1))
  now.val = 2000.0
  assert_true(root.text_input("В"))
  assert_eq(select_test_active(root), Some(4))
  assert_true(root.text_input("unmatched"))
  assert_false(root.needs_frame())
  assert_true(root.text_input("b"))
  assert_eq(select_test_active(root), Some(2))
  assert_eq(selected.peek(), None)
}

///|
test "select applies option availability without polling producers from input or paint" {
  let blocked = @reactive.signal([0, 2])
  let reads = Ref(0)
  let selected = @reactive.signal(Some(0))
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1, 2].map(fn(value) {
          @controls.SelectOption(
            value,
            label=value.to_string(),
            disabled=@reactive.bind(fn() {
              reads.val += 1
              blocked.get().contains(value)
            }),
          )
        }),
        selected~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(reads.val, 0)
  select_test_open(root)
  assert_eq(reads.val, 3)
  assert_eq(select_test_active(root), Some(1))
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(select_test_active(root), Some(1))
  assert_eq(reads.val, 3)
  blocked.set([1])
  let after = reads.val
  assert_eq(select_test_active(root), Some(2))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_eq(select_test_active(root), Some(0))
  assert_eq(reads.val, after)
}

///|
test "select reveals active rows and keeps its list the width of the field" {
  let selected = @reactive.signal(Some(15))
  let root = @runtime.mount(
    fn() {
      @controls.select(
        Array::makei(30, i => i).map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        selected~,
        style=@controls.SelectStyle()
          .surface(@style.BoxStyle().width(260.0))
          .list(@style.BoxStyle().max_height(120.0))
          .option(
            @controls.ButtonStyle().surface(@style.BoxStyle().height(30.0)),
          ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let nodes = select_test_nodes(root)
  assert_eq(select_test_active(root), Some(15))
  let snapshot = root.snapshot().unwrap()
  let list = snapshot.tree.nodes
    .iter()
    .filter(node => node.scroll is Some(_))
    .to_array()[0]
  assert_eq(list.frame.size.width, 260.0)
  assert_true(list.frame.size.height <= 120.0)
  assert_true(list.scroll.unwrap().offset > 0.0)
  assert_true(nodes[15].frame.origin.y >= list.content.origin.y)
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_eq(select_test_active(root), Some(29))
  let last = root.snapshot().unwrap().tree.nodes
    .iter()
    .filter(node => node.scroll is Some(_))
    .to_array()[0]
  assert_true(last.scroll.unwrap().offset > list.scroll.unwrap().offset)
  assert_eq(selected.peek(), Some(15))
}

///|
test "select pointer commits a typed option and outside presses only dismiss" {
  let selected : @reactive.Signal[String?] = @reactive.signal(None)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.select(
          ["One", "Two"].map(fn(value) {
            @controls.SelectOption(value, label=value)
          }),
          selected~,
        ),
        @controls.button("Background", on_click=fn() { clicks.val += 1 }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let option = select_test_nodes(root)[1]
  let size = @foundation.Size(width=320.0, height=400.0)
  let point = @foundation.Point(
    x=option.frame.origin.x + 8.0,
    y=option.frame.origin.y + 8.0,
  )
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_eq(selected.peek(), Some("Two"))
  assert_true(root.view().popup_targets().is_empty())
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(root.view().popup_targets().length(), 1)
  assert_true(root.pointer_down(size~, point=Point(x=300.0, y=350.0)))
  ignore(root.pointer_up(size~, point=Point(x=300.0, y=350.0)))
  assert_true(root.view().popup_targets().is_empty())
  assert_eq(selected.peek(), Some("Two"))
  assert_eq(clicks.val, 0)
}

///|
test "select revalidates removed or disabled options before applying a proposal" {
  for remove in [false, true] {
    let visible = @reactive.signal(true)
    let blocked = @reactive.signal(false)
    let selected = @reactive.signal(Some(0))
    let root = @runtime.mount(
      fn() {
        @view.show(fn() { visible.get() }, fn() {
          @controls.select(
            [0, 1].map(fn(value) {
              @controls.SelectOption(
                value,
                label=value.to_string(),
                disabled=@reactive.bind(fn() { value == 1 && blocked.get() }),
              )
            }),
            selected~,
            on_change=fn(_) {
              if remove {
                visible.set(false)
              } else {
                blocked.set(true)
              }
            },
          )
        })
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    select_test_open(root)
    assert_true(root.key_down(test_key_event(KeyArrowDown)))
    assert_true(root.key_down(test_key_event(KeyEnter)))
    assert_eq(selected.peek(), Some(0))
    if remove {
      assert_true(root.view().popup_targets().is_empty())
    }
  }
}

///|
test "select does not activate with horizontal arrows modifiers or repeat" {
  let selected = @reactive.signal(Some(0))
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1].map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        selected~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  for key in ([KeyArrowRight, KeyArrowLeft] : Array[@foundation.Key]) {
    assert_true(root.key_down(test_key_event(key)))
    assert_eq(selected.peek(), Some(0))
    assert_eq(select_test_active(root), Some(0))
  }
  assert_false(root.key_down(test_control_key_event(KeyArrowDown)))
  assert_false(root.key_down(test_shift_key_event(KeyArrowDown)))
  assert_true(root.key_down(KeyEvent(key=KeyEnter, repeat=true)))
  assert_eq(root.view().popup_targets().length(), 1)
  assert_true(root.key_down(KeyEvent(key=KeyArrowDown, repeat=true)))
  assert_eq(select_test_active(root), Some(1))
  assert_eq(selected.peek(), Some(0))
}

///|
test "select closed keyboard entry handles edges search and an unknown model value" {
  let selected = @reactive.signal(Some("Unknown"))
  let root = @runtime.mount(
    fn() {
      @controls.select(
        ["Apple", "Banana", "Cherry"].map(fn(value) {
          @controls.SelectOption(value, label=value)
        }),
        selected~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyArrowUp)))
  assert_eq(select_test_active(root), Some(2))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  selected.set(Some("Banana"))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_eq(select_test_active(root), Some(0))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_eq(select_test_active(root), Some(2))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(root.text_input("b"))
  assert_eq(select_test_active(root), Some(1))
  assert_eq(selected.peek(), Some("Banana"))
}

///|
test "select empty options are disabled and all-disabled lists dismiss safely" {
  let empty = @runtime.mount(
    fn() {
      @controls.select(
        ([] : Array[Int32]).map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer empty.dispose()
  assert_false(empty.key_down(test_key_event(KeyTab)))
  assert_false(
    empty.click_at(
      size=Size(width=320.0, height=400.0),
      point=Point(x=8.0, y=8.0),
    ),
  )
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1].map(fn(value) {
          @controls.SelectOption(value, label=value.to_string(), disabled=true)
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  assert_eq(select_test_active(root), None)
  assert_eq(root.view().popup_targets().length(), 1)
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(root.view().popup_targets().is_empty())
}

///|
test "select disabled state suspends the open list and preserves its selection" {
  let blocked = @reactive.signal(false)
  let selected = @reactive.signal(Some(1))
  let changes = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1].map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        selected~,
        disabled=blocked,
        on_change=fn(_) { changes.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  blocked.set(true)
  assert_true(root.view().popup_targets().is_empty())
  assert_false(root.key_down(test_key_event(KeyEnter)))
  assert_eq(selected.peek(), Some(1))
  blocked.set(false)
  assert_eq(root.view().popup_targets().length(), 1)
  assert_eq(select_test_active(root), Some(1))
  assert_eq(changes.val, 0)
}

///|
test "select disposes option sources on close and reads reactive labels from their applied values" {
  let labels = @reactive.signal(["Apple", "Banana"])
  let label_reads = Ref(0)
  let disabled_reads = Ref(0)
  let dependency = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1].map(fn(index) {
          @controls.SelectOption(
            index,
            label=@reactive.bind(fn() {
              label_reads.val += 1
              labels.get()[index]
            }),
            disabled=@reactive.bind(fn() {
              disabled_reads.val += 1
              dependency.get()
            }),
          )
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(label_reads.val, 0)
  select_test_open(root)
  assert_eq(label_reads.val, 2)
  labels.set(["Apple", "Cherry"])
  let reads = label_reads.val
  assert_true(root.text_input("c"))
  assert_eq(select_test_active(root), Some(1))
  assert_eq(label_reads.val, reads)
  assert_true(root.key_down(test_key_event(KeyEscape)))
  let disabled_before = disabled_reads.val
  labels.set(["One", "Two"])
  dependency.set(true)
  assert_eq(label_reads.val, reads)
  assert_eq(disabled_reads.val, disabled_before)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(select_test_active(root), None)
  root.dispose()
  let after = label_reads.val
  labels.set(["Three", "Four"])
  assert_eq(label_reads.val, after)
}

///|
test "select newer nested proposal and owner writes supersede an older change" {
  for nested in [false, true] {
    let active : Ref[@runtime.UiRoot?] = Ref(None)
    let selected = @reactive.signal(Some(0))
    let proposals : Array[Int32?] = []
    let root = @runtime.mount(
      fn() {
        @controls.select(
          [0, 1, 2].map(fn(value) {
            @controls.SelectOption(value, label=value.to_string())
          }),
          selected~,
          on_change=fn(event) {
            proposals.push(event.value)
            if event.value == Some(1) {
              if nested {
                ignore(
                  active.val.unwrap().key_down(test_key_event(KeyArrowDown)),
                )
                ignore(active.val.unwrap().key_down(test_key_event(KeyEnter)))
              } else {
                selected.set(Some(2))
              }
            }
          },
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    active.val = Some(root)
    select_test_open(root)
    assert_true(root.key_down(test_key_event(KeyArrowDown)))
    assert_true(root.key_down(test_key_event(KeyEnter)))
    assert_eq(selected.peek(), Some(2))
    assert_eq(proposals, if nested { [Some(1), Some(2)] } else { [Some(1)] })
  }
}

///|
test "select external model updates paint selection without moving active focus" {
  let selected = @reactive.signal(Some(0))
  let proposals = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1, 2].map(fn(option) {
          @controls.SelectOption(option, label="Same label")
        }),
        selected~,
        on_change=fn(_) { proposals.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let nodes = select_test_nodes(root)
  let layout = root.frame_stats().layout_count
  assert_eq(
    nodes[0].computed_style.unwrap().background,
    Some(nodes[0].theme.resolve(@style.selection_token)),
  )
  selected.set(Some(2))
  assert_true(root.needs_frame())
  let nodes = select_test_nodes(root)
  assert_eq(select_test_active(root), Some(0))
  assert_eq(
    nodes[2].computed_style.unwrap().background,
    Some(nodes[2].theme.resolve(@style.selection_token)),
  )
  assert_eq(root.frame_stats().layout_count, layout)
  assert_eq(proposals.val, 0)
}

///|
test "select shared models keep independent popup sessions across roots" {
  let selected = @reactive.signal(Some(0))
  let create = fn() {
    @controls.select(
      [0, 1, 2].map(fn(value) {
        @controls.SelectOption(value, label=value.to_string())
      }),
      selected~,
    )
  }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  select_test_open(first)
  assert_true(second.view().popup_targets().is_empty())
  select_test_open(second)
  assert_true(first.key_down(test_key_event(KeyArrowDown)))
  assert_true(first.key_down(test_key_event(KeyEnter)))
  assert_eq(selected.peek(), Some(1))
  assert_eq(select_test_active(second), Some(0))
  first.dispose()
  assert_true(second.key_down(test_key_event(KeyEnd)))
  assert_true(second.key_down(test_key_event(KeyEnter)))
  assert_eq(selected.peek(), Some(2))
}

///|
test "select repeatedly closes sessions and remounts fresh options without closed subscriptions" {
  let dependency = @reactive.signal(0)
  let reads = Ref(0)
  let selected = @reactive.signal(Some("MoonBit"))
  let root = @runtime.mount(
    fn() {
      @controls.select(
        ["MoonBit", "Rust", "Go"].map(fn(value) {
          @controls.SelectOption(
            value,
            label=value,
            disabled=@reactive.bind(fn() {
              ignore(dependency.get())
              reads.val += 1
              false
            }),
          )
        }),
        selected~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  let mut previous = None
  for cycle in 0..<25 {
    assert_true(root.key_down(test_key_event(KeyEnter)))
    let options = select_test_nodes(root)
    assert_eq(options.length(), 3)
    assert_true(Some(options[0].id) != previous)
    previous = Some(options[0].id)
    assert_eq(select_test_active(root), Some(0))
    assert_true(root.key_down(test_key_event(KeyEnd)))
    assert_eq(select_test_active(root), Some(2))
    assert_true(root.key_down(test_key_event(KeyEscape)))
    assert_true(root.view().popup_targets().is_empty())
    assert_eq(selected.peek(), Some("MoonBit"))
    let count = reads.val
    dependency.set(cycle + 1)
    assert_eq(reads.val, count)
  }
  root.dispose()
  let count = reads.val
  dependency.set(100)
  assert_eq(reads.val, count)
}
