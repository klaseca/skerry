///|
priv struct CheckboxSpec {
  checked : @reactive.Signal[Bool]
  label : @view.TextContent
}

///|
/// Without a model, the control owns its state. on_change runs before the
/// default write and can cancel it with prevent_default().
/// The label accepts the same String sources as text and button.
pub fn checkbox(
  checked? : @reactive.Signal[Bool],
  label~ : &@value.StringValue = "",
  style? : CheckboxStyle,
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
  let checked = match checked {
    Some(model) => model
    None => @reactive.signal(false)
  }
  let style = style.unwrap_or(CheckboxStyle())
  let spec = { checked, label: @view.TextContent(label), }
  @view.element(
    component_name="Checkbox",
    style~,
    measure=fn(context) {
      checkbox_measure_func(
        spec,
        context.text_layout_system,
        context.font,
        resolved_checkbox_style(context.styles),
      )
    },
    painter=checkbox_painter(spec),
    events=@view.ElementEvents(
      focusable=true,
      editable=true,
      disabled?,
      on_click=fn() { checkbox_toggle(spec, on_change) },
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
            checkbox_toggle(spec, on_change)
            KeyActivated
          }
          _ => KeyIgnored
        }
      },
    ),
    reactivity=@view.Reactivity::paint(fn() { ignore(spec.checked.get()) }).with_text(
      spec.label,
    ),
  )
}

///|
fn checkbox_toggle(
  spec : CheckboxSpec,
  on_change : ((@foundation.ChangeEvent[Bool]) -> Unit)?,
) -> Unit {
  let checked = spec.checked
  let next = !checked.get()
  ignore(
    @view.dispatch_change(spec.label.id, next, on_change, fn() {
      checked.set(next)
    }),
  )
}

///|
fn checkbox_measure_func(
  spec : CheckboxSpec,
  text_layout_system : @text.TextLayoutSystem,
  font : @foundation.FontSpec,
  style : CheckboxStyle,
) -> @view.Measure {
  choice_measure_func(
    spec.label.get(),
    font,
    choice_indicator_size(style.indicator),
    style_length(style.gap.unwrap_or(8.0)),
    text_layout_system,
  )
}
