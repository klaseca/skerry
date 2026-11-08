///|
/// One leaf's String source, shared by layout, paint and diagnostics.
/// Allocate one content per leaf; its ID is that leaf's identity.
/// Construction is cold; connect it through Reactivity.with_text.
pub struct TextContent {
  id : Int32
  priv source : @reactive.Binding[String]
  priv applied : Ref[String?]
}

///|
pub fn TextContent::TextContent(value : &@value.StringValue) -> TextContent {
  { id: next_ui_node_id(), source: value.to_binding(), applied: Ref(None), }
}

///|
/// Read the applied value without pulling or subscribing to its producer.
pub fn TextContent::get(self : TextContent) -> String {
  match self.source.constant_value() {
    Some(text) => text
    None => {
      if @environment.text_values() is Some(values) &&
        values.get(self.id) is Some(text) {
        return text
      }
      self.applied.val.unwrap_or("")
    }
  }
}

///|
fn text_reactivity(
  value : TextContent,
  needs_layout~ : () -> Bool = fn() { true },
) -> Reactivity {
  {
    text_value: Some(value),
    image_value: None,
    manages_children: false,
    mount: fn(host) {
      if value.source.constant_value() is Some(_) {
        return fn() { () }
      }
      let first_run = Ref(true)
      let active = Ref(true)
      let stop = value.source.subscribe(fn(next) {
        guard active.val else { return }
        let changed = !first_run.val
        first_run.val = false
        value.applied.val = Some(next)
        if changed && needs_layout() {
          (host.mark_layout_dirty)()
        }
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
pub fn Reactivity::with_text(
  self : Reactivity,
  value : TextContent,
  needs_layout~ : () -> Bool = fn() { true },
) -> Reactivity {
  let text = text_reactivity(value, needs_layout~)
  {
    ..self,
    text_value: Some(value),
    mount: fn(host) {
      let stop_text = (text.mount)(host)
      let stop_other = (self.mount)(host)
      fn() {
        stop_other()
        stop_text()
      }
    },
  }
}
