///|
priv struct ButtonSpec {
  label : @view.TextContent
}

///|
/// The label accepts String, Signal[String], Computed[String] or Binding[String].
/// Equal results stay idle; changed labels request layout and preserve control state.
/// `disabled` accepts Bool, Signal[Bool], Computed[Bool] or Binding[Bool].
/// Reactive sources are subscribed when mounted. Changing availability
/// preserves identity/layout;
/// a disabled ancestor still blocks the entire subtree.
///
/// ```mbt check
/// test {
///   let blocked = @reactive.signal(false)
///   let constant = @controls.button("Unavailable", disabled=true)
///   let direct = @controls.button("Save", disabled=blocked)
///   let derived = @controls.button(
///     "Save",
///     disabled=@reactive.bind(fn() { blocked.get() }),
///   )
///   assert_false(constant.is_enabled_path([]))
///   ignore(direct)
///   ignore(derived)
/// }
/// ```
pub fn button(
  label : &@value.StringValue,
  on_click? : () -> Unit,
  style? : ButtonStyle,
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
  let style = style.unwrap_or(ButtonStyle())
  let spec = { label: @view.TextContent(label), }
  @view.element(
    component_name="Button",
    style~,
    padding=@foundation.Insets::symmetric(horizontal=12.0, vertical=8.0),
    measure=fn(context) {
      @view.text_measure(
        spec.label.get(),
        context.font,
        context.text_layout_system,
      )
    },
    painter=button_painter(spec),
    events=@view.ElementEvents(
      focusable=true,
      disabled?,
      on_click?,
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
          KeyEnter | KeySpace =>
            match on_click {
              Some(action) => {
                action()
                KeyActivated
              }
              None => KeyIgnored
            }
          _ => KeyIgnored
        }
      },
    ),
    reactivity=@view.Reactivity().with_text(spec.label),
  )
}
