///|
// Narrow host adapter: tests exercise the actual shortcut path without touching
// the system clipboard. The writer either succeeds or raises before committing.
priv struct Clipboard {
  read : () -> String? raise
  write : (String) -> Unit raise
}

///|
let system_clipboard : Clipboard = {
  read: () => {
    if @sdl_lib.Clipboard::has_text() {
      Some(@sdl_lib.Clipboard::text())
    } else {
      None
    }
  },
  write: text => @sdl_lib.Clipboard::set_text(text),
}

///|
fn handle_clipboard_shortcut(
  root : @runtime.UiRoot,
  event : @foundation.KeyEvent,
  clipboard~ : Clipboard = system_clipboard,
) -> Bool raise {
  match event.text_edit_shortcut() {
    Some(CopyShortcut) =>
      match root.copy_text() {
        Some(text) => {
          (clipboard.write)(text)
          true
        }
        None => false
      }
    Some(CutShortcut) => {
      // The control validates its change proposal first. A failed host write
      // rejects the default deletion; propagate the original host error after
      // returning through the synchronous, non-raising input callbacks.
      let error : Ref[Error?] = Ref(None)
      let result = root.cut_text(write=fn(text) {
        try {
          (clipboard.write)(text)
          true
        } catch {
          cause => {
            error.val = Some(cause)
            false
          }
        }
      })
      if error.val is Some(cause) {
        raise cause
      }
      result is Some(_)
    }
    Some(PasteShortcut) =>
      match (clipboard.read)() {
        Some(text) => root.paste_text(text)
        None => false
      }
    None => false
  }
}
