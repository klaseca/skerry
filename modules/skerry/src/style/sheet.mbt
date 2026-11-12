///|
/// Root/provider-owned rule lookup. Each concrete family has one readonly
/// signal; unrelated theme changes do not invalidate its consumers.
pub struct StyleSheet {
  priv id : Int32
  priv styles : Ref[Styles]
  priv entries : Map[String, SheetEntry]
}

///|
let next_style_sheet_id : Ref[Int32] = Ref(0)

///|
priv struct SheetEntry {
  witness : () -> Unit
  payload : StylePayload
  update : (Styles) -> Bool
  observers : Array[RuleObserver?]
}

///|
priv struct RuleObserver {
  mut notify : (() -> Unit)?
}

///|
pub fn StyleSheet::StyleSheet(styles : Styles) -> StyleSheet {
  let id = next_style_sheet_id.val
  next_style_sheet_id.val = id + 1
  { id, styles: Ref(styles), entries: {}, }
}

///|
pub fn StyleSheet::set(self : StyleSheet, styles : Styles) -> Unit {
  guard self.styles.val != styles else { return }
  self.styles.val = styles
  let entries = self.entries.values().to_array()
  let changed : Array[SheetEntry] = []
  @reactive.batch(fn() {
    for entry in entries {
      if (entry.update)(styles) {
        changed.push(entry)
      }
    }
  })
  for entry in changed {
    for observer in entry.observers.copy() {
      if observer is Some(observer) && observer.notify is Some(notify) {
        notify()
      }
    }
  }
}

///|
pub fn[T : StyleSpec] StyleSheet::get(self : StyleSheet) -> ReadOnlyArray[T] {
  let key = describe_style((panic : () -> Ref[T]))
  let witness = StyleWitness::witness((panic : () -> Ref[T]))
  let value : @reactive.Signal[ReadOnlyArray[T]] = match self.entries.get(key) {
    Some(entry) if physical_equal(witness, entry.witness) => {
      let value : Ref[@reactive.Signal[ReadOnlyArray[T]]] = restore_style(
        entry.payload,
      )
      value.val
    }
    _ => {
      let value : @reactive.Signal[ReadOnlyArray[T]] = @reactive.signal(
        self.styles.val.get(),
      )
      let observers : Array[RuleObserver?] = []
      self.entries.set(key, {
        observers,
        witness,
        payload: erase_style(Ref(value)),
        update: fn(styles) {
          let next = styles.get()
          if value.peek() != next {
            value.set(next)
            true
          } else {
            false
          }
        },
      })
      value
    }
  }
  value.get()
}

///|
/// Observe changes to a family without allocating an effect per static node.
pub fn[T : StyleSpec] StyleSheet::observe(
  self : StyleSheet,
  _type : () -> Ref[T],
  receive : (Bool) -> Unit,
) -> () -> Unit {
  ignore(@reactive.untracked(fn() -> ReadOnlyArray[T] { self.get() }))
  let key = describe_style((panic : () -> Ref[T]))
  let entry = self.entries.get(key).unwrap()
  let observer = {
    notify: Some(fn() {
      let rules : ReadOnlyArray[T] = self.styles.val.get()
      let dynamic = rules.iter().any(rule => StyleSpec::has_source(rule))
      receive(dynamic)
    }),
  }
  entry.observers.push(Some(observer))
  observer.notify.unwrap()()
  let registration = Ref(Some((entry, observer)))
  fn() {
    guard registration.val is Some((entry, observer)) else { return }
    registration.val = None
    observer.notify = None
    entry.observers.retain(value => {
      value is Some(value) && !physical_equal(value, observer)
    })
    entry.observers.release_unused(placeholder=None)
  }
}
