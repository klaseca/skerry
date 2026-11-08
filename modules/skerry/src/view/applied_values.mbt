///|
// Materialize before a standalone operation. No effects are created and no
// structural builders are rerun. A mounted low-level host uses its saved value.
fn UiNode::sample_values(
  self : UiNode,
  values : Map[Int32, String],
  applied : Map[Int32, String]?,
  images : Map[Int32, @foundation.Image],
  applied_images : Map[Int32, @foundation.Image]?,
) -> Unit {
  if self.reactivity.text_value is Some(value) &&
    value.source.constant_value() is None {
    let saved = match applied {
      Some(applied) => applied.get(value.id)
      None => None
    }
    let next = match saved {
      Some(text) => text
      None =>
        match value.applied.val {
          Some(text) => text
          None => value.source.get()
        }
    }
    values.set(value.id, next)
  }
  self.sample_image(images, applied_images)
  for child in self.children.val {
    child.sample_values(values, applied, images, applied_images)
  }
}

///|
fn[T] View::with_applied_values(self : View, run : () -> T) -> T {
  // A nested layout/paint must retain the operation's sampled values instead
  // of restoring the host scope and sampling the producer for a second time.
  if @environment.values_are_materialized(self.node.id) {
    return run()
  }
  self.with_scope(fn() {
    if @environment.values_are_materialized(self.node.id) {
      run()
    } else {
      let applied = @environment.text_values()
      let images = @environment.image_values()
      @reactive.provide([@environment.values_binding()], fn() {
        self.node.sample_values(
          @environment.text_values().unwrap(),
          applied,
          @environment.image_values().unwrap(),
          images,
        )
        @environment.mark_values_materialized(self.node.id)
        run()
      })
    }
  })
}
