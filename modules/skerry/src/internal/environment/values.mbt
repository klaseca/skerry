///|
priv struct AppliedValues {
  // Temporary snapshots for standalone layout/paint, not per-root node state.
  text : Map[Int32, String]
  images : Map[Int32, @foundation.Image]
  mut materialized_view : Int32?
}

///|
let values_context : @reactive.Context[AppliedValues?] = Context(None)

///|
pub fn values_binding() -> @reactive.ContextBinding {
  values_context.provide(
    Some({ text: Map([]), images: Map([]), materialized_view: None, }),
  )
}

///|
pub fn text_values() -> Map[Int32, String]? {
  values_context.get().map(state => state.text)
}

///|
pub fn values_are_materialized(view_id : Int32) -> Bool {
  values_context
  .get()
  .map(state => state.materialized_view == Some(view_id))
  .unwrap_or(false)
}

///|
pub fn mark_values_materialized(view_id : Int32) -> Unit {
  if values_context.get() is Some(state) {
    state.materialized_view = Some(view_id)
  }
}

///|
pub fn image_values() -> Map[Int32, @foundation.Image]? {
  values_context.get().map(state => state.images)
}
