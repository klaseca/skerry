///|
test "key event maps platform text edit shortcuts" {
  debug_inspect(test_key_event(KeyC).text_edit_shortcut(), content="None")
  debug_inspect(
    test_control_key_event(KeyC).text_edit_shortcut(),
    content="Some(CopyShortcut)",
  )
  debug_inspect(
    test_control_key_event(KeyX).text_edit_shortcut(),
    content="Some(CutShortcut)",
  )
  debug_inspect(
    test_control_key_event(KeyV).text_edit_shortcut(),
    content="Some(PasteShortcut)",
  )
  debug_inspect(
    @foundation.KeyEvent(key=KeyV, modifiers=KeyModifiers(meta=true)).text_edit_shortcut(),
    content="Some(PasteShortcut)",
  )
}

///|
fn test_key_event(key : @foundation.Key) -> @foundation.KeyEvent {
  KeyEvent(key~)
}

///|
fn test_control_key_event(key : @foundation.Key) -> @foundation.KeyEvent {
  KeyEvent(key~, modifiers=KeyModifiers(control=true))
}
