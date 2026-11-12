///|
fn keyboard_test_dispatcher(
  root : @runtime.UiRoot,
  window_id~ : UInt32 = 1,
) -> EventDispatcher {
  EventDispatcher(root, window_id~, geometry=fn() {
    let size = @foundation.Size(width=160.0, height=80.0)
    { window_size: size, logical_size: size, }
  })
}

///|
fn keyboard_test_key(
  dispatcher : EventDispatcher,
  key : @foundation.Key,
  down~ : Bool = true,
  repeat~ : Bool = false,
  window_id~ : UInt32 = 1,
  which~ : UInt32 = 1,
  control~ : Bool = false,
) -> Unit raise {
  // SDL_keycode.h and SDL_scancode.h; key identity is independent of its text.
  let (keycode, scancode) = match key {
    KeySpace => (0x20U, 44)
    KeyEnter => (0x0DU, 40)
    KeyTab => (0x09U, 43)
    KeyArrowDown => (0x40000051U, 81)
    KeyA => (0x61U, 4)
    _ => abort("unsupported keyboard fixture")
  }
  let event = input_test_event(
    if down {
      @sdl_sys.EVENT_KEY_DOWN
    } else {
      @sdl_sys.EVENT_KEY_UP
    },
    window_id,
    keycode~,
  )
  let raw = event.key()
  raw.set_scancode(scancode)
  raw.set_which(which)
  raw.set_repeat(repeat)
  raw.set_mod(if control { 0x0040U } else { 0U })
  raw.set_down(down)
  assert_true(dispatcher.dispatch(event))
}

///|
fn keyboard_test_active(state : SdlAppState) -> Int32? raise {
  state.sync_frame()
  let mut index = 0
  for node in state.root.snapshot().unwrap().tree.nodes {
    if node.component_name == "SelectOption" {
      if node.state.focused {
        return Some(index)
      }
      index += 1
    }
  }
  None
}

///|
test "SDL consumed Space text does not reopen Select or reset focus during repeat" {
  for key in [@foundation.KeySpace, KeyEnter] {
    for initial in [None, Some(1)] {
      let selected = @reactive.signal(initial)
      let proposals : Array[Int32?] = []
      with_render_state(
        fn(_) {
          @controls.select(
            [0, 1, 2].map(value => {
              @controls.SelectOption(value, label=value.to_string())
            }),
            selected~,
            on_change=fn(event) { proposals.push(event.value) },
          )
        },
        (state, _) => {
          let root = state.root
          let dispatcher = keyboard_test_dispatcher(root)
          keyboard_test_key(dispatcher, KeyTab)
          keyboard_test_key(dispatcher, KeyTab, down=false)
          state.sync_frame()
          let field = root.snapshot().unwrap().focused_node_id
          assert_true(field is Some(_))
          keyboard_test_key(dispatcher, key)
          if key == KeySpace {
            assert_false(dispatcher.text_input(" "))
          }
          keyboard_test_key(dispatcher, key, down=false)
          assert_eq(keyboard_test_active(state), Some(initial.unwrap_or(0)))
          keyboard_test_key(dispatcher, KeyArrowDown)
          keyboard_test_key(dispatcher, KeyArrowDown, down=false)
          let next = initial.unwrap_or(0) + 1
          assert_eq(keyboard_test_active(state), Some(next))
          keyboard_test_key(dispatcher, key)
          assert_true(root.view().popup_targets().is_empty())
          if key == KeySpace {
            assert_false(dispatcher.text_input(" "))
          }
          keyboard_test_key(dispatcher, key, repeat=true)
          if key == KeySpace {
            assert_false(dispatcher.text_input(" "))
          }
          keyboard_test_key(dispatcher, key, down=false)
          assert_true(root.view().popup_targets().is_empty())
          assert_eq(selected.peek(), Some(next))
          assert_eq(proposals, [Some(next)])
          state.sync_frame()
          assert_eq(root.snapshot().unwrap().focused_node_id, field)
        },
      )
    }
  }
}

///|
test "SDL consumed Space preserves active Select option after a vetoed proposal" {
  let selected = @reactive.signal(Some(0))
  let proposals = Ref(0)
  with_render_state(
    fn(_) {
      @controls.select(
        [" Leading space", "Second", "Third"].mapi((value, label) => {
          @controls.SelectOption(value, label~)
        }),
        selected~,
        on_change=fn(event) {
          proposals.val += 1
          event.prevent_default()
        },
      )
    },
    (state, _) => {
      let root = state.root
      let dispatcher = keyboard_test_dispatcher(root)
      keyboard_test_key(dispatcher, KeyTab)
      keyboard_test_key(dispatcher, KeyTab, down=false)
      keyboard_test_key(dispatcher, KeyEnter)
      keyboard_test_key(dispatcher, KeyEnter, down=false)
      keyboard_test_key(dispatcher, KeyArrowDown)
      keyboard_test_key(dispatcher, KeyArrowDown, down=false)
      assert_eq(keyboard_test_active(state), Some(1))
      for repeat in [false, true] {
        keyboard_test_key(dispatcher, KeySpace, repeat~)
        assert_false(dispatcher.text_input(" "))
        assert_eq(keyboard_test_active(state), Some(1))
        assert_eq(selected.peek(), Some(0))
        assert_eq(proposals.val, 1)
      }
      keyboard_test_key(dispatcher, KeySpace, down=false)
      assert_eq(root.view().popup_targets().length(), 1)
    },
  )
}

///|
test "SDL command consumption follows the physical key through focus changes and permits independent text" {
  let value = @reactive.signal("")
  let slot : Ref[@runtime.UiRoot?] = Ref(None)
  let activations = Ref(0)
  let root = input_test_root(fn() {
    @view.column([
      @controls.button("Focus input", on_click=fn() {
        activations.val += 1
        ignore(slot.val.unwrap().key_down(@foundation.KeyEvent(key=KeyTab)))
      }),
      @controls.text_input(value~),
    ])
  })
  defer root.dispose()
  slot.val = Some(root)
  let dispatcher = keyboard_test_dispatcher(root)
  keyboard_test_key(dispatcher, KeyTab)
  keyboard_test_key(dispatcher, KeyTab, down=false)
  keyboard_test_key(dispatcher, KeySpace)
  // A release on another keyboard must not release the consumed physical key.
  keyboard_test_key(dispatcher, KeySpace, down=false, which=2)
  assert_false(dispatcher.text_input("arbitrary text from a handled key"))
  assert_eq(value.peek(), "")
  assert_eq(activations.val, 1)
  // No key event is required for an independent committed string.
  assert_true(dispatcher.text_input("漢字 😀"))
  assert_eq(value.peek(), "漢字 😀")
  // The focused text field ignores this keydown, but the original command owns
  // its repeats until release. Its text must still not leak into the field.
  keyboard_test_key(dispatcher, KeySpace, repeat=true)
  assert_false(dispatcher.text_input(" "))
  assert_eq(value.peek(), "漢字 😀")
  // A fresh press is allowed even if the old keyup was lost.
  keyboard_test_key(dispatcher, KeySpace)
  assert_true(dispatcher.text_input(" "))
  keyboard_test_key(dispatcher, KeySpace, down=false)
  assert_eq(value.peek(), "漢字 😀 ")
  keyboard_test_key(dispatcher, KeyA, control=true)
  assert_false(dispatcher.text_input("a"))
  keyboard_test_key(dispatcher, KeyA, control=true, down=false)
  assert_true(dispatcher.text_input("replacement"))
  assert_eq(value.peek(), "replacement")
}

///|
test "SDL nontext keys and other windows do not discard text commits and focus loss clears consumption" {
  let first = @reactive.signal("")
  let second = @reactive.signal("")
  let root = input_test_root(fn() { @controls.text_input(value=first) })
  defer root.dispose()
  let other = input_test_root(fn() { @controls.text_input(value=second) })
  defer other.dispose()
  let dispatcher = keyboard_test_dispatcher(root)
  let other_dispatcher = keyboard_test_dispatcher(other, window_id=2)
  keyboard_test_key(dispatcher, KeyTab)
  assert_true(dispatcher.text_input(" "))
  keyboard_test_key(dispatcher, KeyTab, down=false)
  assert_eq(first.peek(), " ")
  keyboard_test_key(other_dispatcher, KeyTab, window_id=2)
  keyboard_test_key(other_dispatcher, KeyTab, down=false, window_id=2)
  keyboard_test_key(dispatcher, KeyA, control=true)
  keyboard_test_key(dispatcher, KeyA, control=true, down=false, window_id=2)
  let focus_event = input_test_event(@sdl_sys.EVENT_WINDOW_FOCUS_LOST, 2)
  assert_true(dispatcher.dispatch(focus_event))
  assert_true(other_dispatcher.text_input("other window"))
  assert_false(dispatcher.text_input("discarded command text"))
  assert_eq(first.peek(), " ")
  assert_eq(second.peek(), "other window")
  keyboard_test_key(dispatcher, KeyA, control=true, repeat=true)
  assert_true(
    dispatcher.dispatch(input_test_event(@sdl_sys.EVENT_WINDOW_FOCUS_LOST, 1)),
  )
  // Focus is restored through the logical API; no native keydown accompanies
  // this independent text commit after returning to the application.
  assert_true(root.key_down(@foundation.KeyEvent(key=KeyTab)))
  assert_true(dispatcher.text_input("after focus loss"))
  assert_true(first.peek().contains("after focus loss"))
}
