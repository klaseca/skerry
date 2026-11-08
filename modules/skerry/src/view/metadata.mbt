///|
priv struct DebugMetadata {
  name : String?
  source : @diagnostics.SourceLocation?
  key_label : String?
  components : ComponentMetadata?
}

///|
priv struct ComponentMetadata {
  id : Int32
  name : String
  debug_name : String?
  source : @diagnostics.SourceLocation?
  inner : ComponentMetadata?
}

///|
let next_component_id_ref : Ref[Int32] = Ref(0)

///|
fn UiNode::debug_metadata(self : UiNode) -> DebugMetadata {
  self.metadata.unwrap_or({
    name: None,
    source: None,
    key_label: None,
    components: None,
  })
}

///|
/// Declare a virtual component boundary before passing this view to a parent
/// or mounting it. Repeated calls preserve the inner boundaries and primitive.
/// The returned view shares the same UI identity, children and lifetime; this
/// only adds diagnostic metadata, without layout nodes or reactive scopes.
///
/// ```mbt check
/// test {
///   let column = @view.column([])
///   let card = column.component("Card").component("ProfileCard")
///   assert_eq(card.node_id_at_path([]), column.node_id_at_path([]))
/// }
/// ```
pub fn View::component(self : View, name : String) -> View {
  let metadata = self.node.debug_metadata()
  let id = next_component_id_ref.val
  next_component_id_ref.val = id + 1
  view_from_node({
    ..self.node,
    metadata: Some({
      ..metadata,
      components: Some({
        id,
        name,
        debug_name: None,
        source: None,
        inner: metadata.components,
      }),
    }),
  })
}

///|
/// Attach static diagnostic values to the current level before composition or
/// mounting. After component(), these describe the outer component; otherwise
/// they describe the UI node. Omitted fields preserve previous values. The
/// original view's metadata is unchanged; no diagnostic boundary is added.
///
/// ```mbt check
/// test {
///   let source = @diagnostics.SourceLocation(
///     file="src/editor.mbt",
///     line=42,
///     column=5,
///   )
///   let button = @controls.button("Save")
///   let tagged = button.debug(name="save button", source~)
///   assert_eq(tagged.node_id_at_path([]), button.node_id_at_path([]))
/// }
/// ```
pub fn View::debug(
  self : View,
  name? : String,
  source? : @diagnostics.SourceLocation,
) -> View {
  guard name is Some(_) || source is Some(_) else { return self }
  let metadata = self.node.debug_metadata()
  let metadata = match metadata.components {
    Some(component) =>
      {
        ..metadata,
        components: Some({
          ..component,
          debug_name: if name is Some(_) {
            name
          } else {
            component.debug_name
          },
          source: if source is Some(_) {
            source
          } else {
            component.source
          },
        }),
      }
    None =>
      {
        ..metadata,
        name: if name is Some(_) {
          name
        } else {
          metadata.name
        },
        source: if source is Some(_) {
          source
        } else {
          metadata.source
        },
      }
  }
  view_from_node({ ..self.node, metadata: Some(metadata), })
}

///|
fn UiNode::label_key(self : UiNode, label : String) -> UiNode {
  {
    ..self,
    metadata: Some({ ..self.debug_metadata(), key_label: Some(label), }),
  }
}
