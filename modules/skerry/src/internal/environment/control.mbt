///|
priv struct ChangeTarget {
  mut active : Bool
  can_change : (Int32) -> Bool
  mut pending : Ref[Bool]?
}

///|
// A root's editable targets; this registry validates change proposals rather
// than selecting per-mount component state.
let control_context : @reactive.Context[Map[Int32, ChangeTarget]?] = Context(
  None,
)

///|
// Standalone persistent View hosts do not install a root context.
let standalone_changes : Map[Int32, ChangeTarget] = Map([])

///|
pub fn control_binding() -> @reactive.ContextBinding {
  control_context.provide(Some(Map([])))
}

///|
pub fn register_change_target(
  id : Int32,
  can_change : (Int32) -> Bool,
) -> () -> Unit {
  let targets = control_context.get().unwrap_or(standalone_changes)
  let target = { active: true, can_change, pending: None, }
  targets.set(id, target)
  fn() {
    target.active = false
    if targets.get(id) is Some(current) && physical_equal(current, target) {
      ignore(targets.remove(id))
    }
  }
}

///|
/// Capture this mount and supersede an older pending change on the same control.
pub fn prepare_change(id : Int32) -> () -> Bool {
  let scope = @reactive.Scope::current()
  let targets = control_context.get().unwrap_or(standalone_changes)
  let target = targets.get(id)
  let superseded = Ref(false)
  if target is Some(target) {
    if target.pending is Some(previous) {
      previous.val = true
    }
    target.pending = Some(superseded)
  }
  fn() {
    if scope is Some(scope) && scope.is_disposed() {
      return false
    }
    !superseded.val &&
    (match target {
      Some(target) => target.active && (target.can_change)(id)
      None => true
    })
  }
}

///|
// A cut's host write is dynamically scoped to that synchronous edit operation.
// Event callbacks can restore their construction owner, so a reactive Context
// would lose this operation-local service. Nested cuts restore the outer writer.
let cut_writer : Ref[((String) -> Bool)?] = Ref(None)

///|
pub fn[T] with_cut_writer(write : ((String) -> Bool)?, run : () -> T) -> T {
  let previous = cut_writer.val
  cut_writer.val = write
  defer (fn() { cut_writer.val = previous })()
  run()
}

///|
pub fn write_cut_clipboard(text : String) -> Bool {
  match cut_writer.val {
    Some(write) => write(text)
    None => true
  }
}
