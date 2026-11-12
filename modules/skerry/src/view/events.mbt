///|
/// Event behavior and optional observers for one element. Behavior runs before
/// observers. Set editable=true when the element dispatches change proposals.
pub struct ElementEvents {
  priv disabled : @reactive.Binding[Bool]?
  priv on_click : (() -> Unit)?
  priv hit_testable : Bool
  priv focusable : Bool
  priv editable : Bool
  priv focus_entry : (() -> Int32?)?
  priv on_focus : (() -> Unit)?
  priv on_blur : (() -> Unit)?
  priv on_pointer_down : (PointerContext) -> Unit
  priv on_pointer_move : (PointerContext) -> Unit
  priv on_pointer_up : (PointerContext) -> Unit
  priv on_pointer_cancel : () -> Unit
  priv on_key_down : (@foundation.KeyEvent) -> KeyHandling
  priv on_text_input : (String) -> Bool
  priv on_text_edit : (@foundation.TextEditCommand) -> @foundation.TextEditResult
}

///|
#derive(Eq)
pub(all) enum KeyHandling {
  KeyIgnored
  // Consumed; view reactivity owns invalidation, including no-op actions.
  // Native adapters prevent the handled key's generated text input.
  KeyHandled
  KeyActivated
}

///|
pub extend KeyHandling with Eq::{equal, not_equal}

///|
/// Local pointer coordinates and the same typography/insets used for paint.
pub struct PointerContext {
  align : @foundation.TextAlign
  position : @foundation.Point
  text_layout_system : @text.TextLayoutSystem
  font : @foundation.FontSpec
  size : @foundation.Size
  padding : @foundation.Insets
}

///|
/// Configure disabled state without evaluating a reactive source until mount.
/// focus_entry groups focus targets into one Tab stop and returns a preferred
/// node ID. Its callback retains the construction context, like event handlers.
/// Pass this configuration to element through its events argument.
///
/// ```mbt check
/// test {
///   let blocked = @reactive.signal(false)
///   let events = @view.ElementEvents(focusable=true, disabled=blocked, focus_entry=fn() {
///     None
///   })
///   ignore(events)
/// }
/// ```
pub fn ElementEvents::ElementEvents(
  focusable~ : Bool = false,
  editable~ : Bool = false,
  hit_testable~ : Bool = false,
  disabled? : &@value.BoolValue,
  focus_entry? : () -> Int32?,
  on_click? : () -> Unit,
  on_focus? : () -> Unit,
  on_blur? : () -> Unit,
  on_key_down? : (@foundation.KeyEvent) -> Unit,
  on_text_input? : (String) -> Unit,
  on_pointer_down? : (@foundation.PointerEvent) -> Unit,
  on_pointer_move? : (@foundation.PointerEvent) -> Unit,
  on_pointer_up? : (@foundation.PointerEvent) -> Unit,
  on_pointer_cancel? : () -> Unit,
  handle_key_down~ : (@foundation.KeyEvent) -> KeyHandling = fn(_) {
    KeyIgnored
  },
  handle_text_input~ : (String) -> Bool = fn(_) { false },
  handle_text_edit~ : (@foundation.TextEditCommand) -> @foundation.TextEditResult = fn(
    _,
  ) {
    TextEditIgnored
  },
  handle_pointer_down? : (PointerContext) -> Unit,
  handle_pointer_move? : (PointerContext) -> Unit,
  handle_pointer_up? : (PointerContext) -> Unit,
  handle_pointer_cancel? : () -> Unit,
) -> ElementEvents {
  let events : ElementEvents = {
    disabled: disabled.map(fn(value) { value.to_binding() }),
    on_click,
    hit_testable: hit_testable ||
    on_click is Some(_) ||
    on_pointer_down is Some(_) ||
    on_pointer_move is Some(_) ||
    on_pointer_up is Some(_) ||
    handle_pointer_down is Some(_) ||
    handle_pointer_move is Some(_) ||
    handle_pointer_up is Some(_),
    focusable,
    editable,
    focus_entry: focus_entry.map(scoped_callback),
    on_focus,
    on_blur,
    on_key_down: observed_handler(handle_key_down, on_key_down),
    on_text_input: observed_handler(handle_text_input, on_text_input),
    on_text_edit: handle_text_edit,
    on_pointer_down: pointer_handler(
      handle_pointer_down,
      on_pointer_down,
      PointerDown,
    ),
    on_pointer_move: pointer_handler(
      handle_pointer_move,
      on_pointer_move,
      PointerMove,
    ),
    on_pointer_up: pointer_handler(handle_pointer_up, on_pointer_up, PointerUp),
    on_pointer_cancel: fn() {
      if handle_pointer_cancel is Some(handler) {
        handler()
      }
      if on_pointer_cancel is Some(handler) {
        handler()
      }
    },
  }
  {
    ..events,
    on_click: events.on_click.map(scoped_callback),
    on_focus: events.on_focus.map(scoped_callback),
    on_blur: events.on_blur.map(scoped_callback),
    on_key_down: scoped_handler(events.on_key_down),
    on_text_input: scoped_handler(events.on_text_input),
    on_text_edit: scoped_handler(events.on_text_edit),
    on_pointer_down: scoped_handler(events.on_pointer_down),
    on_pointer_move: scoped_handler(events.on_pointer_move),
    on_pointer_up: scoped_handler(events.on_pointer_up),
    on_pointer_cancel: scoped_callback(events.on_pointer_cancel),
  }
}

///|
fn[T] scoped_callback(callback : () -> T) -> () -> T {
  let scope = @reactive.Scope::current()
  fn() {
    match scope {
      Some(scope) => scope.run(callback)
      None => callback()
    }
  }
}

///|
fn[A, B] scoped_handler(handler : (A) -> B) -> (A) -> B {
  let scope = @reactive.Scope::current()
  fn(arg) {
    match scope {
      Some(scope) => scope.run(fn() { handler(arg) })
      None => handler(arg)
    }
  }
}

///|
fn[A, B] observed_handler(
  handle : (A) -> B,
  observe : ((A) -> Unit)?,
) -> (A) -> B {
  match observe {
    None => handle
    Some(observe) =>
      fn(value) {
        let result = handle(value)
        observe(value)
        result
      }
  }
}

///|
fn pointer_handler(
  internal : ((PointerContext) -> Unit)?,
  external : ((@foundation.PointerEvent) -> Unit)?,
  phase : @foundation.PointerPhase,
) -> (PointerContext) -> Unit {
  fn(event) {
    if internal is Some(handler) {
      handler(event)
    }
    if external is Some(handler) {
      handler(PointerEvent(position=event.position, phase~))
    }
  }
}
