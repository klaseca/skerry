///|
priv struct ImageValue {
  id : Int32
  source : @reactive.Binding[@foundation.Image]
  applied : Ref[@foundation.Image?]
}

///|
fn ImageValue::ImageValue(
  id : Int32,
  source : @reactive.Binding[@foundation.Image],
) -> ImageValue {
  { id, source, applied: Ref(None), }
}

///|
fn ImageValue::get(self : ImageValue) -> @foundation.Image {
  match self.source.constant_value() {
    Some(image) => image
    None => {
      if @environment.image_values() is Some(values) &&
        values.get(self.id) is Some(image) {
        return image
      }
      self.applied.val.unwrap()
    }
  }
}

///|
fn image_reactivity(value : ImageValue) -> Reactivity {
  {
    text_value: None,
    image_value: Some(value),
    manages_children: false,
    mount: fn(host) {
      if value.source.constant_value() is Some(_) {
        return fn() { () }
      }
      let previous : Ref[@foundation.Size?] = Ref(None)
      let active = Ref(true)
      let stop = value.source.subscribe(fn(next) {
        guard active.val else { return }
        value.applied.val = Some(next)
        let size = next.size()
        if previous.val is Some(old) {
          if old == size {
            (host.mark_paint_dirty)()
          } else {
            (host.mark_layout_dirty)()
          }
        }
        previous.val = Some(size)
      })
      fn() {
        guard active.val else { return }
        active.val = false
        stop()
        value.applied.val = None
      }
    },
  }
}

///|
fn UiNode::sample_image(
  self : UiNode,
  values : Map[Int32, @foundation.Image],
  applied : Map[Int32, @foundation.Image]?,
) -> Unit {
  if self.reactivity.image_value is Some(value) &&
    value.source.constant_value() is None {
    let saved = match applied {
      Some(values) => values.get(value.id)
      None => None
    }
    let next = match saved {
      Some(image) => image
      None =>
        match value.applied.val {
          Some(image) => image
          None => value.source.get()
        }
    }
    values[value.id] = next
  }
}
