///|
priv struct SelectState[T] {
  options : Array[SelectOption[T]]
  selected : @reactive.Signal[T?]
  open : @reactive.Signal[Bool]
  mut opening : SelectOpening
  mut pending : Ref[Bool]?
}

///|
priv enum SelectOpening {
  Current
  First
  Last
  Search(String)
}

///|
/// A single-value selector. None displays the placeholder. Without `selected`,
/// the control owns an initially empty selection. Options are copied once and
/// each SelectOption supplies its value, label and disabled source.
/// Labels and availability remain reactive without rebuilding the options.
/// Arrows/Home/End navigate without changing the model. Enter/Space or a click
/// proposes a selection; a prevented change keeps the list open. Escape and
/// outside presses dismiss without committing. Text input searches by prefix.
/// Option availability is tracked while open, never polled from input or paint.
///
/// ```mbt check
/// test {
///   let selected = @reactive.signal(Some("moonbit"))
///   let control = @controls.select(
///     [
///       @controls.SelectOption("moonbit", label="MoonBit"),
///       @controls.SelectOption("rust", label="Rust"),
///     ],
///     selected~,
///   )
///   ignore(control)
/// }
/// ```
pub fn[T : Eq] select(
  options : ArrayView[SelectOption[T]],
  selected? : @reactive.Signal[T?],
  placeholder~ : &@value.StringValue = "Select…",
  style? : SelectStyle,
  on_change? : (@foundation.ChangeEvent[T?]) -> Unit,
  disabled? : &@value.BoolValue,
  placement~ : @view.PopupPlacement = BottomStart,
) -> @view.View {
  let options = options.to_owned()
  let state : SelectState[T] = {
    options,
    selected: match selected {
      Some(value) => value
      None => @reactive.signal(None)
    },
    open: @reactive.signal(false),
    opening: Current,
    pending: None,
  }
  let placeholder = placeholder.to_binding()
  let disabled : &@value.BoolValue? = if options.is_empty() {
    Some(true)
  } else {
    disabled
  }
  let style = style.unwrap_or(SelectStyle())
  let content = @view.TextContent(
    @reactive.bind(fn() {
      match state.selected.get() {
        Some(value) => {
          for option in state.options {
            if value == option.value {
              return option.label.get()
            }
          }
          placeholder.get()
        }
        None => placeholder.get()
      }
    }),
  )
  let empty = fn() {
    match state.selected.peek() {
      Some(value) => !state.options.any(option => option.value == value)
      None => true
    }
  }
  let anchor = @view.element(
    component_name="Select",
    style~,
    padding=@foundation.Insets::symmetric(horizontal=12.0, vertical=8.0),
    measure=fn(context) {
      let font = if empty() {
        resolve_select_style(
          @foundation.ControlState(),
          context.theme,
          context.font,
          context.styles,
        ).placeholder_font.unwrap()
      } else {
        context.font
      }
      select_measure(content.get(), font, context.text_layout_system)
    },
    painter=select_painter(content, empty),
    events=@view.ElementEvents(
      focusable=true,
      disabled?,
      on_click=fn() {
        state.opening = Current
        state.open.set(!state.open.peek())
      },
      handle_key_down=fn(event) {
        guard select_navigation_event(event) else { return KeyIgnored }
        match event.key {
          KeyEnter | KeySpace if !event.repeat => {
            state.opening = Current
            state.open.set(!state.open.peek())
            KeyHandled
          }
          KeyArrowDown | KeyArrowUp | KeyHome | KeyEnd => {
            state.opening = match event.key {
              KeyHome => First
              KeyEnd => Last
              KeyArrowUp if empty() => Last
              _ => Current
            }
            state.open.set(true)
            KeyHandled
          }
          _ => KeyIgnored
        }
      },
      handle_text_input=fn(text) {
        guard !text.is_empty() else { return false }
        state.opening = Search(text)
        state.open.set(true)
        true
      },
    ),
    reactivity=@view.Reactivity(mount=fn(host) {
      let previous : Ref[(T?, Bool)?] = Ref(None)
      @reactive.render_effect(fn() {
        let value = state.selected.get()
        let next = (value, empty())
        let before = previous.val
        previous.val = Some(next)
        @reactive.untracked(fn() {
          if before is Some(old) && old.1 != next.1 {
            // A placeholder may use another font even when its text equals
            // the selected label. Text equality alone cannot detect this.
            host.invalidate_layout()
          } else if before is Some(old) && old.0 != next.0 {
            host.invalidate_paint()
          }
        })
      })
    }).with_text(content),
  )
  @view.popup(
    anchor,
    open=state.open,
    trigger=Manual,
    placement~,
    match_anchor_width=true,
    fn(close) { select_list(state, style, on_change, close) },
  ).component("Select")
}

///|
// Both the field and options reserve trailing space for their indicator.
fn select_measure(
  text : String,
  font : @foundation.FontSpec,
  system : @text.TextLayoutSystem,
) -> @view.Measure {
  let measure = @view.text_measure(text, font, system)
  fn(width, height) {
    let size = measure((width - 24.0).max(0.0), height)
    {
      ..size,
      min_width: size.min_width + 24.0,
      max_width: size.max_width + 24.0,
    }
  }
}

///|
fn select_navigation_event(event : @foundation.KeyEvent) -> Bool {
  !event.modifiers.control &&
  !event.modifiers.alt &&
  !event.modifiers.meta &&
  !event.modifiers.shift
}
