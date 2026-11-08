///|
#derive(Eq, Debug)
pub(all) enum Key {
  KeyBackspace
  KeyDelete
  KeyEscape
  KeyTab
  KeyEnter
  KeySpace
  KeyHome
  KeyEnd
  KeyArrowRight
  KeyArrowLeft
  KeyArrowUp
  KeyArrowDown
  KeyPageUp
  KeyPageDown
  KeyA
  KeyC
  KeyV
  KeyX
  KeyUnknown
}

///|
pub extend Key with Eq::{not_equal, equal}

///|
pub extend Key with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct KeyModifiers {
  shift : Bool
  control : Bool
  alt : Bool
  meta : Bool
}

///|
pub extend KeyModifiers with Eq::{not_equal, equal}

///|
pub extend KeyModifiers with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct KeyEvent {
  key : Key
  modifiers : KeyModifiers
  repeat : Bool
}

///|
pub extend KeyEvent with Eq::{not_equal, equal}

///|
pub extend KeyEvent with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum PointerPhase {
  PointerDown
  PointerMove
  PointerUp
}

///|
pub extend PointerPhase with Eq::{not_equal, equal}

///|
pub extend PointerPhase with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct PointerEvent {
  position : Point
  phase : PointerPhase
}

///|
pub extend PointerEvent with Eq::{not_equal, equal}

///|
pub extend PointerEvent with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum TextEditCommand {
  CopyText
  CutText
  PasteText(String)
}

///|
pub extend TextEditCommand with Eq::{not_equal, equal}

///|
pub extend TextEditCommand with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum TextEditShortcut {
  CopyShortcut
  CutShortcut
  PasteShortcut
}

///|
pub extend TextEditShortcut with Eq::{not_equal, equal}

///|
pub extend TextEditShortcut with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum TextEditResult {
  TextEditIgnored
  TextEditHandled
  TextEditText(String)
}

///|
pub extend TextEditResult with Eq::{not_equal, equal}

///|
pub extend TextEditResult with Debug::{to_repr}

///|
pub fn KeyModifiers::none() -> KeyModifiers {
  { shift: false, control: false, alt: false, meta: false, }
}

///|
pub fn KeyModifiers::KeyModifiers(
  shift~ : Bool = false,
  control~ : Bool = false,
  alt~ : Bool = false,
  meta~ : Bool = false,
) -> KeyModifiers {
  { shift, control, alt, meta, }
}

///|
pub fn KeyEvent::KeyEvent(
  key~ : Key,
  modifiers~ : KeyModifiers = KeyModifiers::none(),
  repeat~ : Bool = false,
) -> KeyEvent {
  { key, modifiers, repeat, }
}

///|
pub fn KeyEvent::text_edit_shortcut(self : KeyEvent) -> TextEditShortcut? {
  if !(self.modifiers.control || self.modifiers.meta) {
    None
  } else {
    match self.key {
      KeyC => Some(CopyShortcut)
      KeyX => Some(CutShortcut)
      KeyV => Some(PasteShortcut)
      _ => None
    }
  }
}

///|
pub fn PointerEvent::PointerEvent(
  position~ : Point,
  phase~ : PointerPhase,
) -> PointerEvent {
  { position, phase, }
}
