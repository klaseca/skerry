///|
priv struct TextInputSpec {
  state : TextInputState
  placeholder : @view.TextContent
}

///|
priv struct TextInputState {
  value : @reactive.Signal[String]
  selection : @reactive.Signal[(Int32, Int32)]
  mut scroll_x : Double
  mut selecting : Bool
}

///|
fn TextInputState::TextInputState(
  value : @reactive.Signal[String],
) -> TextInputState {
  let cursor = value.peek().char_length()
  {
    value,
    selection: @reactive.signal((cursor, cursor)),
    scroll_x: 0.0,
    selecting: false,
  }
}

///|
fn TextInputState::cursor(self : TextInputState) -> Int32 {
  self.selection.peek().0
}

///|
fn TextInputState::anchor(self : TextInputState) -> Int32 {
  self.selection.peek().1
}

///|
fn TextInputState::set_selection(
  self : TextInputState,
  cursor : Int32,
  anchor : Int32,
) -> Unit {
  let next = (cursor, anchor)
  if self.selection.peek() != next {
    self.selection.set(next)
  }
}

///|
/// `on_change` receives a proposal before the default write; prevent_default()
/// cancels it. Without value, the input owns its state.
/// The placeholder accepts a String source; it updates without changing the
/// input value or selection. Hidden placeholder changes do not request a frame.
pub fn text_input(
  value? : @reactive.Signal[String],
  placeholder~ : &@value.StringValue = "",
  style? : TextInputStyle,
  on_change? : (@foundation.ChangeEvent[String]) -> Unit,
  on_submit? : (String) -> Unit,
  on_focus? : () -> Unit,
  on_blur? : () -> Unit,
  on_key_down? : (@foundation.KeyEvent) -> Unit,
  on_text_input? : (String) -> Unit,
  on_pointer_down? : (@foundation.PointerEvent) -> Unit,
  on_pointer_move? : (@foundation.PointerEvent) -> Unit,
  on_pointer_up? : (@foundation.PointerEvent) -> Unit,
  on_pointer_cancel? : () -> Unit,
  disabled? : &@value.BoolValue,
) -> @view.View {
  let placeholder = placeholder.to_binding()
  let style = style.unwrap_or(TextInputStyle())
  let value = match value {
    Some(model) => model
    None => @reactive.signal("")
  }
  let state = TextInputState(value)
  let spec = { state, placeholder: @view.TextContent(placeholder), }
  @view.element(
    component_name="TextInput",
    style~,
    padding=@foundation.Insets::symmetric(horizontal=10.0, vertical=8.0),
    measure=fn(context) {
      let font = if text_input_value(spec).is_empty() {
        resolved_text_input_style(context.styles).placeholder.font.unwrap_or(
          context.font,
        )
      } else {
        context.font
      }
      text_input_measure_func(spec, context.text_layout_system, font)
    },
    painter=text_input_painter(spec),
    events=@view.ElementEvents(
      focusable=true,
      editable=true,
      disabled?,
      on_focus?,
      on_blur?,
      on_key_down?,
      on_text_input?,
      on_pointer_down?,
      on_pointer_move?,
      on_pointer_up?,
      on_pointer_cancel?,
      handle_pointer_down=fn(event) {
        let cursor = text_input_hit_index(spec, event)
        state.begin_selection(cursor)
      },
      handle_pointer_move=fn(event) {
        if state.selecting {
          state.select_to(text_input_hit_index(spec, event))
        }
      },
      handle_pointer_up=fn(event) {
        if state.selecting {
          state.select_to(text_input_hit_index(spec, event))
        }
        state.end_selection()
      },
      handle_pointer_cancel=fn() { state.end_selection() },
      handle_key_down=fn(event) {
        let value = state.value
        let handled = match event.key {
          KeyBackspace => {
            if event.modifiers.control {
              ignore(
                text_input_update(
                  spec.placeholder.id,
                  value,
                  state,
                  on_change,
                  text_input_backspace_word,
                ),
              )
            } else {
              ignore(
                text_input_update(
                  spec.placeholder.id,
                  value,
                  state,
                  on_change,
                  text_input_backspace,
                ),
              )
            }
            true
          }
          KeyDelete => {
            if event.modifiers.control {
              ignore(
                text_input_update(
                  spec.placeholder.id,
                  value,
                  state,
                  on_change,
                  text_input_delete_word,
                ),
              )
            } else {
              ignore(
                text_input_update(
                  spec.placeholder.id,
                  value,
                  state,
                  on_change,
                  text_input_delete,
                ),
              )
            }
            true
          }
          KeyArrowLeft => {
            if event.modifiers.shift {
              if event.modifiers.control {
                state.extend_word_left(value.get())
              } else {
                state.extend_left(value.get())
              }
            } else if event.modifiers.control {
              state.move_word_left(value.get())
            } else {
              state.move_left(value.get())
            }
            true
          }
          KeyArrowRight => {
            if event.modifiers.shift {
              if event.modifiers.control {
                state.extend_word_right(value.get())
              } else {
                state.extend_right(value.get())
              }
            } else if event.modifiers.control {
              state.move_word_right(value.get())
            } else {
              state.move_right(value.get())
            }
            true
          }
          KeyHome => {
            if event.modifiers.shift {
              state.extend_to_start(value.get())
            } else {
              state.move_to_start(value.get())
            }
            true
          }
          KeyEnd => {
            if event.modifiers.shift {
              state.extend_to_end(value.get())
            } else {
              state.move_to_end(value.get())
            }
            true
          }
          KeyA =>
            if event.modifiers.control || event.modifiers.meta {
              state.select_all(value.get())
              true
            } else {
              false
            }
          KeyEnter =>
            match on_submit {
              Some(handler) => {
                handler(value.get())
                true
              }
              None => false
            }
          _ => false
        }
        if handled {
          KeyHandled
        } else {
          KeyIgnored
        }
      },
      handle_text_input=fn(text) {
        let value = state.value
        if !text.is_empty() {
          ignore(
            text_input_update(spec.placeholder.id, value, state, on_change, fn(
              current,
              state,
            ) {
              text_input_insert(current, state, text)
            }),
          )
          true
        } else {
          false
        }
      },
      handle_text_edit=fn(command) {
        let value = state.value
        match command {
          CopyText =>
            match text_input_selected_text(value.get(), state) {
              Some(text) => TextEditText(text)
              None => TextEditIgnored
            }
          CutText =>
            match text_input_selected_text(value.get(), state) {
              Some(text) =>
                if text_input_update(
                    spec.placeholder.id,
                    value,
                    state,
                    on_change,
                    text_input_delete,
                    before_apply=fn() { @environment.write_cut_clipboard(text) },
                  ) {
                  TextEditText(text)
                } else {
                  TextEditIgnored
                }
              None => TextEditIgnored
            }
          PasteText(text) =>
            if text.is_empty() {
              TextEditIgnored
            } else {
              ignore(
                text_input_update(
                  spec.placeholder.id,
                  value,
                  state,
                  on_change,
                  fn(current, state) { text_input_insert(current, state, text) },
                ),
              )
              TextEditHandled
            }
        }
      },
    ),
    reactivity=text_input_reactivity(state).with_text(spec.placeholder, needs_layout=fn() {
      state.value.peek().is_empty()
    }),
  )
}

///|
fn text_input_value(spec : TextInputSpec) -> String {
  spec.state.value.get()
}

///|
fn text_input_display_text(spec : TextInputSpec) -> String {
  let value = text_input_value(spec)
  if value.is_empty() {
    spec.placeholder.get()
  } else {
    value
  }
}

///|
fn TextInputState::begin_selection(
  self : TextInputState,
  cursor : Int32,
) -> Unit {
  self.set_selection(cursor, cursor)
  self.selecting = true
}

///|
fn TextInputState::select_to(self : TextInputState, cursor : Int32) -> Unit {
  self.set_selection(cursor, self.anchor())
}

///|
fn TextInputState::end_selection(self : TextInputState) -> Unit {
  self.selecting = false
}

///|
fn TextInputState::clamp_to_text(self : TextInputState, text : String) -> Unit {
  let length = text.char_length()
  self.set_selection(
    self.cursor().max(0).min(length),
    self.anchor().max(0).min(length),
  )
}

///|
fn TextInputState::selection_start(self : TextInputState) -> Int32 {
  self.cursor().min(self.anchor())
}

///|
fn TextInputState::selection_end(self : TextInputState) -> Int32 {
  self.cursor().max(self.anchor())
}

///|
fn TextInputState::has_selection(self : TextInputState) -> Bool {
  self.cursor() != self.anchor()
}

///|
fn TextInputState::move_left(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  let cursor = if self.has_selection() {
    self.selection_start()
  } else {
    (self.cursor() - 1).max(0)
  }
  self.set_selection(cursor, cursor)
}

///|
fn TextInputState::move_right(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  let length = text.char_length()
  let cursor = if self.has_selection() {
    self.selection_end()
  } else if self.cursor() < length {
    self.cursor() + 1
  } else {
    length
  }
  self.set_selection(cursor, cursor)
}

///|
fn TextInputState::move_word_left(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  let cursor = if self.has_selection() {
    self.selection_start()
  } else {
    text_input_previous_word_boundary(text, self.cursor())
  }
  self.set_selection(cursor, cursor)
}

///|
fn TextInputState::move_word_right(
  self : TextInputState,
  text : String,
) -> Unit {
  self.clamp_to_text(text)
  let cursor = if self.has_selection() {
    self.selection_end()
  } else {
    text_input_next_word_boundary(text, self.cursor())
  }
  self.set_selection(cursor, cursor)
}

///|
fn TextInputState::move_to_start(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  self.set_selection(0, 0)
}

///|
fn TextInputState::move_to_end(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  let length = text.char_length()
  self.set_selection(length, length)
}

///|
fn TextInputState::extend_left(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  self.set_selection((self.cursor() - 1).max(0), self.anchor())
}

///|
fn TextInputState::extend_right(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  let length = text.char_length()
  if self.cursor() < length {
    self.set_selection(self.cursor() + 1, self.anchor())
  }
}

///|
fn TextInputState::extend_word_left(
  self : TextInputState,
  text : String,
) -> Unit {
  self.clamp_to_text(text)
  self.set_selection(
    text_input_previous_word_boundary(text, self.cursor()),
    self.anchor(),
  )
}

///|
fn TextInputState::extend_word_right(
  self : TextInputState,
  text : String,
) -> Unit {
  self.clamp_to_text(text)
  self.set_selection(
    text_input_next_word_boundary(text, self.cursor()),
    self.anchor(),
  )
}

///|
fn TextInputState::extend_to_start(
  self : TextInputState,
  text : String,
) -> Unit {
  self.clamp_to_text(text)
  self.set_selection(0, self.anchor())
}

///|
fn TextInputState::extend_to_end(self : TextInputState, text : String) -> Unit {
  self.clamp_to_text(text)
  self.set_selection(text.char_length(), self.anchor())
}

///|
fn TextInputState::select_all(self : TextInputState, text : String) -> Unit {
  let length = text.char_length()
  self.set_selection(self.cursor(), 0)
  self.set_selection(length, self.anchor())
}

///|
// Edit proposals contain no signals and never mutate the live caret/selection.
priv struct TextInputEdit {
  mut cursor : Int32
  mut anchor : Int32
}

///|
fn TextInputEdit::clamp_to_text(self : TextInputEdit, text : String) -> Unit {
  let length = text.char_length()
  self.cursor = self.cursor.max(0).min(length)
  self.anchor = self.anchor.max(0).min(length)
}

///|
fn TextInputEdit::set_selection(
  self : TextInputEdit,
  cursor : Int32,
  anchor : Int32,
) -> Unit {
  self.cursor = cursor
  self.anchor = anchor
}

///|
fn text_input_update(
  id : Int32,
  value : @reactive.Signal[String],
  state : TextInputState,
  on_change : ((@foundation.ChangeEvent[String]) -> Unit)?,
  transform : (String, TextInputEdit) -> String,
  before_apply~ : () -> Bool = fn() { true },
) -> Bool {
  let current = value.get()
  let selection = state.selection.peek()
  let edit = TextInputEdit::{ cursor: selection.0, anchor: selection.1, }
  let next = transform(current, edit)
  let applied = Ref(false)
  let apply = fn() {
    guard before_apply() else { return }
    applied.val = true
    @reactive.batch(fn() {
      // A handler may navigate without canceling the proposed text change.
      if state.selection.peek() == selection {
        state.set_selection(edit.cursor, edit.anchor)
      }
      if value.peek() != next {
        value.set(next)
      }
      state.clamp_to_text(next)
    })
  }
  if next == current {
    ignore(@view.dispatch_change(id, next, None, apply))
  } else {
    ignore(@view.dispatch_change(id, next, on_change, apply))
  }
  applied.val
}

///|
fn text_input_insert(
  text : String,
  state : TextInputEdit,
  inserted : String,
) -> String {
  state.clamp_to_text(text)
  let start = state.cursor.min(state.anchor)
  let end = state.cursor.max(state.anchor)
  let result = replace_char_range(text, start, end, inserted)
  let cursor = start + inserted.char_length()
  state.set_selection(cursor, cursor)
  result
}

///|
fn text_input_backspace(text : String, state : TextInputEdit) -> String {
  state.clamp_to_text(text)
  if state.cursor != state.anchor {
    let start = state.cursor.min(state.anchor)
    let end = state.cursor.max(state.anchor)
    state.set_selection(start, start)
    replace_char_range(text, start, end, "")
  } else if state.cursor > 0 {
    let cursor = state.cursor - 1
    state.set_selection(cursor, cursor)
    replace_char_range(text, cursor, cursor + 1, "")
  } else {
    text
  }
}

///|
fn text_input_delete(text : String, state : TextInputEdit) -> String {
  state.clamp_to_text(text)
  if state.cursor != state.anchor {
    let start = state.cursor.min(state.anchor)
    let end = state.cursor.max(state.anchor)
    state.set_selection(start, start)
    replace_char_range(text, start, end, "")
  } else {
    let length = text.char_length()
    if state.cursor < length {
      let cursor = state.cursor
      state.set_selection(cursor, cursor)
      replace_char_range(text, cursor, cursor + 1, "")
    } else {
      text
    }
  }
}

///|
fn text_input_backspace_word(text : String, state : TextInputEdit) -> String {
  state.clamp_to_text(text)
  if state.cursor != state.anchor {
    text_input_backspace(text, state)
  } else if state.cursor > 0 {
    let end = state.cursor
    let start = text_input_previous_word_boundary(text, end)
    state.set_selection(start, start)
    replace_char_range(text, start, end, "")
  } else {
    text
  }
}

///|
fn text_input_delete_word(text : String, state : TextInputEdit) -> String {
  state.clamp_to_text(text)
  if state.cursor != state.anchor {
    text_input_delete(text, state)
  } else {
    let start = state.cursor
    let end = text_input_next_word_boundary(text, start)
    state.set_selection(start, start)
    if end > start {
      replace_char_range(text, start, end, "")
    } else {
      text
    }
  }
}

///|
fn text_input_selected_text(text : String, state : TextInputState) -> String? {
  state.clamp_to_text(text)
  if state.has_selection() {
    Some(text_char_range(text, state.selection_start(), state.selection_end()))
  } else {
    None
  }
}

///|
fn text_input_previous_word_boundary(text : String, cursor : Int32) -> Int32 {
  let chars = text.to_array()
  let mut index = cursor.max(0).min(chars.length())
  while index > 0 && text_input_is_separator(chars[index - 1]) {
    index = index - 1
  }
  while index > 0 && !text_input_is_separator(chars[index - 1]) {
    index = index - 1
  }
  index
}

///|
fn text_input_next_word_boundary(text : String, cursor : Int32) -> Int32 {
  let chars = text.to_array()
  let mut index = cursor.max(0).min(chars.length())
  while index < chars.length() && text_input_is_separator(chars[index]) {
    index = index + 1
  }
  while index < chars.length() && !text_input_is_separator(chars[index]) {
    index = index + 1
  }
  while index < chars.length() && text_input_is_separator(chars[index]) {
    index = index + 1
  }
  index
}

///|
fn text_input_is_separator(char : Char) -> Bool {
  match char {
    ' ' | '\t' | '\n' | '\r' => true
    _ => false
  }
}

///|
fn replace_char_range(
  text : String,
  start : Int32,
  end : Int32,
  replacement : String,
) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let insert_at = start.max(0).min(chars.length())
  for index, char in chars {
    if index == insert_at {
      push_string_chars(out, replacement)
    }
    if index < start || index >= end {
      out.push(char)
    }
  }
  if insert_at == chars.length() {
    push_string_chars(out, replacement)
  }
  String::from_array(out)
}

///|
fn text_char_range(text : String, start : Int32, end : Int32) -> String {
  let chars = text.to_array()
  let from = start.max(0).min(chars.length())
  let to = end.max(from).min(chars.length())
  let out : Array[Char] = []
  for index in from..<to {
    out.push(chars[index])
  }
  String::from_array(out)
}

///|
fn push_string_chars(out : Array[Char], text : String) -> Unit {
  for char in text {
    out.push(char)
  }
}

///|
fn text_input_hit_index(
  spec : TextInputSpec,
  event : @view.PointerContext,
) -> Int32 {
  let layout = event.text_layout_system.layout(
    TextLayoutInput(
      text=text_input_value(spec),
      font=event.font,
      max_width=None,
    ),
  )
  // A font/width change can be followed by input before the next paint. Resolve
  // the same caret scroll as the painter before translating the pointer.
  update_text_input_scroll(
    spec,
    @foundation.Rect::from_size(event.size).inset(event.padding),
    layout,
    event.font,
  )
  let content_width = (event.size.width -
  event.padding.left -
  event.padding.right).max(0.0)
  let x = (event.position.x -
  event.padding.left +
  spec.state.scroll_x -
  text_input_alignment_offset(layout, content_width, event.align)).max(0.0)
  closest_caret_index(layout.caret_positions, x)
}

///|
fn closest_caret_index(carets : Array[Double], x : Double) -> Int32 {
  if carets.is_empty() {
    0
  } else {
    let mut best = 0
    let mut best_distance = abs_double(carets[0] - x)
    for index in 1..<carets.length() {
      let distance = abs_double(carets[index] - x)
      if distance < best_distance {
        best = index
        best_distance = distance
      }
    }
    best
  }
}

///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn text_input_measure_func(
  spec : TextInputSpec,
  text_layout_system : @text.TextLayoutSystem,
  font : @foundation.FontSpec,
) -> @view.Measure {
  fn(_available_width, _available_height) {
    // Text input paints one unwrapped line and scrolls it horizontally.
    let size = text_layout_system.layout(
        TextLayoutInput(
          text=text_input_display_text(spec),
          font~,
          max_width=None,
        ),
      ).size
    {
      min_width: size.width,
      max_width: size.width,
      min_height: size.height,
      max_height: size.height,
    }
  }
}
