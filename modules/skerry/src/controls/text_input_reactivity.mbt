///|
// One subscription observes the final text and selection of a batched edit.
// Compare clamped caret positions, matching the painter after external edits.
fn text_input_reactivity(state : TextInputState) -> @view.Reactivity {
  @view.Reactivity(mount=fn(host) {
    let value = state.value
    let previous : Ref[(String, Int32, Int32)?] = Ref(None)
    @reactive.render_effect(fn() {
      let text = value.get()
      let (cursor, anchor) = state.selection.get()
      let length = text.char_length()
      let next = (text, cursor.max(0).min(length), anchor.max(0).min(length))
      let before = previous.val
      previous.val = Some(next)
      @reactive.untracked(fn() {
        match before {
          Some(old) if old.0 != next.0 => host.invalidate_layout()
          Some(old) if old != next => host.invalidate_paint()
          _ => ()
        }
      })
    })
  })
}
