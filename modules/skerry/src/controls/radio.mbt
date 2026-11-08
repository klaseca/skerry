///|
priv struct RadioSpec {
  specified_style : RadioStyle
  selected : () -> Bool
  label : @view.TextContent
}

///|
/// Without a model, the control owns its state. on_change runs before the
/// default write and can cancel it with prevent_default().
/// The label accepts the same String sources as text and button.
pub fn radio(
  selected? : @reactive.Signal[Bool],
  label~ : &@value.StringValue = "",
  style? : RadioStyle,
  on_change? : (@foundation.ChangeEvent[Bool]) -> Unit,
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
  let label = label.to_binding()
  let selected = match selected {
    Some(model) => model
    None => @reactive.signal(false)
  }
  let spec = radio_spec(fn() { selected.get() }, label, style)
  radio_view(
    spec,
    on_select=fn() {
      if !selected.get() {
        ignore(
          @view.dispatch_change(spec.label.id, true, on_change, fn() {
            selected.set(true)
          }),
        )
      }
    },
    on_focus?,
    on_blur?,
    on_key_down?,
    on_text_input?,
    on_pointer_down?,
    on_pointer_move?,
    on_pointer_up?,
    on_pointer_cancel?,
    disabled?,
  )
}

///|
priv struct RadioGroupState {
  mut pending : Ref[Bool]?
}

///|
/// on_change receives the proposed option before updating selected and can
/// cancel that write with prevent_default().
/// Tab enters at the selected enabled option (otherwise the first enabled one).
/// Unmodified arrows move focus and propose a selection, wrapping at the ends.
/// item_disabled is tracked per option when mounted; input reads its applied value.
/// Build each option's label once. The result can be a plain String or a
/// reactive String source, independently of the writable selected model.
pub fn[T : Eq, L : @value.StringValue] radio_group(
  selected : @reactive.Signal[T],
  options : Array[T],
  label~ : (T) -> L,
  style? : @view.FlexStyle,
  item_style? : RadioStyle,
  item_disabled? : (T) -> Bool,
  on_change? : (@foundation.ChangeEvent[T]) -> Unit,
  disabled? : &@value.BoolValue,
) -> @view.View {
  let options = options.copy()
  let state = RadioGroupState::{ pending: None, }
  let children : Array[@view.View] = []
  for option in options {
    let value = option
    let disabled : &@value.BoolValue? = item_disabled.map(predicate => {
      @reactive.bind(fn() { predicate(value) })
    })
    let child = radio_group_entry(
      value,
      selected,
      state,
      label(value).to_binding(),
      item_style,
      on_change,
      disabled?,
    )
    children.push(child)
  }
  @view.column(style?, children, disabled?)
  .component("RadioGroup")
  .focus_group(fn() {
    let current = selected.peek()
    for index, option in options {
      if option == current {
        return children[index].node_id_at_path([])
      }
    }
    None
  })
}

///|
fn[T : Eq] radio_group_entry(
  value : T,
  selected : @reactive.Signal[T],
  state : RadioGroupState,
  label : @reactive.Binding[String],
  style : RadioStyle?,
  on_change : ((@foundation.ChangeEvent[T]) -> Unit)?,
  disabled? : &@value.BoolValue,
) -> @view.View {
  let spec = radio_spec(fn() { selected.get() == value }, label, style)
  radio_view(spec, disabled?, on_select=fn() {
    // All options form one editable control, including a nested activation of
    // the already selected option. A newer action supersedes an older proposal.
    if state.pending is Some(previous) {
      previous.val = true
    }
    let superseded = Ref(false)
    state.pending = Some(superseded)
    if selected.get() != value {
      ignore(
        @view.dispatch_change(
          spec.label.id,
          value,
          on_change,
          fn() { selected.set(value) },
          is_current=fn() { !superseded.val },
        ),
      )
    }
  })
}

///|
fn radio_spec(
  selected : () -> Bool,
  label : @reactive.Binding[String],
  style : RadioStyle?,
) -> RadioSpec {
  let style = style.unwrap_or(RadioStyle())
  { specified_style: style, selected, label: @view.TextContent(label), }
}

///|
fn radio_view(
  spec : RadioSpec,
  on_select~ : () -> Unit,
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
  @view.element(
    component_name="Radio",
    style=spec.specified_style,
    measure=fn(context) {
      radio_measure_func(
        spec,
        context.text_layout_system,
        context.font,
        resolved_radio_style(context.styles),
      )
    },
    painter=radio_painter(spec),
    events=@view.ElementEvents(
      focusable=true,
      editable=true,
      disabled?,
      on_click=on_select,
      on_focus?,
      on_blur?,
      on_key_down?,
      on_text_input?,
      on_pointer_down?,
      on_pointer_move?,
      on_pointer_up?,
      on_pointer_cancel?,
      handle_key_down=fn(event) {
        match event.key {
          KeyEnter | KeySpace => {
            on_select()
            KeyActivated
          }
          _ => KeyIgnored
        }
      },
    ),
    reactivity=@view.Reactivity::paint(fn() { ignore((spec.selected)()) }).with_text(
      spec.label,
    ),
  )
}

///|
fn radio_measure_func(
  spec : RadioSpec,
  text_layout_system : @text.TextLayoutSystem,
  font : @foundation.FontSpec,
  style : RadioStyle,
) -> @view.Measure {
  choice_measure_func(
    spec.label.get(),
    font,
    choice_indicator_size(style.indicator),
    style_length(style.gap.unwrap_or(8.0)),
    text_layout_system,
  )
}
