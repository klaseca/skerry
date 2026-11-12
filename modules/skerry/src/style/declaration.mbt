///|
/// Immutable component style data. Merge preserves omitted fields and composes
/// nested fragments; explicitly supplied values, including zero, override them.
/// Common root properties and intrinsic metrics are cached independently of paint.
/// Value methods are deterministic. Selectors and source producers are tracked
/// during materialization; rendering and diagnostics never evaluate them.
pub(open) trait StyleSpec: Eq + Debug {
  fn merge(Self, Self) -> Self
  fn split_source(Self) -> (Self, StyleSource[Self]?) = _
  fn[T : SourceStyle] select(Self, (Self) -> T) -> T = _
  fn freeze_fields(Self, StyleSheet) -> Self = _
  fn has_source(Self) -> Bool = _
  fn root_style(Self) -> BoxStyle = _
  fn metrics(Self) -> StyleMetrics = _
}

///|
impl StyleSpec with fn metrics(_) {
  StyleMetrics()
}

///|
impl StyleSpec with fn root_style(_) {
  BoxStyle()
}

///|
/// Cached concrete declaration. Its payload and all unchecked conversions are
/// private; extraction checks both the runtime type witness and description.
pub struct StyleDeclaration {
  name : String
  origin : StyleOrigin
  layout : BoxStyle
  metrics : StyleMetrics
  roots : ReadOnlyArray[BoxStyle]
  priv witness : () -> Unit
  priv description : String
  priv payload : StylePayload
  priv read_layers : ((StyleSheet) -> ReadOnlyArray[StyleDeclaration])?
  priv observe_rules : (StyleSheet, (Bool) -> Unit) -> () -> Unit
  priv dynamic : Bool
  priv merge_data : (StylePayload, StylePayload) -> StyleDeclaration
  priv equal_value : (StylePayload, StylePayload) -> Bool
  priv debug_value : (StylePayload) -> Repr
}

///|
pub fn[T : StyleSpec] StyleDeclaration::StyleDeclaration(
  value : T,
) -> StyleDeclaration {
  let description = describe_style((panic : () -> Ref[T]))
  let label = describe_style((panic : () -> T))
  let name = match label {
    [.. "<obj:() -> ", .. name, '>'] => name.to_owned()
    _ => label
  }
  {
    origin: Local(name),
    merge_data: fn(a, b) {
      let a : Ref[T] = restore_style(a)
      let b : Ref[T] = restore_style(b)
      StyleDeclaration::plain(StyleSpec::merge(a.val, b.val))
    },
    dynamic: StyleSpec::has_source(value),
    observe_rules: fn(sheet, receive) {
      sheet.observe((panic : () -> Ref[T]), receive)
    },
    read_layers: Some(fn(sheet) {
      let result : Array[StyleDeclaration] = []
      for index, rule in (sheet.get() : ReadOnlyArray[T]) {
        for layer in expand_style(rule, sheet) {
          result.push({
            ..StyleDeclaration::plain(
              StyleSpec::freeze_fields(layer.value, sheet),
            ),
            origin: ThemeRule(
              sheet=sheet.id,
              rule=index,
              family=name,
              source=layer.origin,
            ),
          })
        }
      }
      for layer in expand_style(value, sheet) {
        result.push({
          ..StyleDeclaration::plain(
            StyleSpec::freeze_fields(layer.value, sheet),
          ),
          origin: layer.origin,
        })
      }
      ReadOnlyArray::from_array(result[:])
    }),
    name,
    description,
    witness: StyleWitness::witness((panic : () -> Ref[T])),
    payload: erase_style(Ref(value)),
    layout: style_value(StyleSpec::root_style(value)),
    metrics: StyleSpec::metrics(value),
    roots: ReadOnlyArray::from_array([]),
    equal_value: fn(a, b) {
      let a : Ref[T] = restore_style(a)
      let b : Ref[T] = restore_style(b)
      a.val == b.val
    },
    debug_value: fn(value) {
      let value : Ref[T] = restore_style(value)
      Repr(value.val)
    },
  }
}

///|
pub fn StyleDeclaration::same_type(
  self : StyleDeclaration,
  other : StyleDeclaration,
) -> Bool {
  physical_equal(self.witness, other.witness) &&
  self.description == other.description
}

///|
pub fn[T] StyleDeclaration::get(self : StyleDeclaration) -> T? {
  let witness = StyleWitness::witness((panic : () -> Ref[T]))
  let description = describe_style((panic : () -> Ref[T]))
  if physical_equal(witness, self.witness) && description == self.description {
    let value : Ref[T] = restore_style(self.payload)
    Some(value.val)
  } else {
    None
  }
}

///|
pub impl Eq for StyleDeclaration with fn equal(self, other) {
  self.same_type(other) && (self.equal_value)(self.payload, other.payload)
}

///|
pub impl Debug for StyleDeclaration with fn to_repr(self) {
  (self.debug_value)(self.payload)
}

///|
pub extend StyleDeclaration with Eq::{equal, not_equal}

///|
pub extend StyleDeclaration with Debug::{to_repr}

///|
impl StyleSpec with fn split_source(self) {
  (self, None)
}

///|
impl StyleSpec with fn select(self, select) {
  project_style(self, select)
}

///|
pub fn StyleDeclaration::resolve(
  self : StyleDeclaration,
  sheet : StyleSheet,
) -> ReadOnlyArray[StyleDeclaration] {
  match self.read_layers {
    Some(read) => read(sheet)
    None => ReadOnlyArray::from_array([self])
  }
}

///|
fn[T : StyleSpec] StyleDeclaration::plain(value : T) -> StyleDeclaration {
  let description = describe_style((panic : () -> Ref[T]))
  {
    origin: Local(style_name((panic : () -> T))),
    merge_data: fn(a, b) {
      let a : Ref[T] = restore_style(a)
      let b : Ref[T] = restore_style(b)
      StyleDeclaration::plain(StyleSpec::merge(a.val, b.val))
    },
    name: style_name((panic : () -> T)),
    description,
    witness: StyleWitness::witness((panic : () -> Ref[T])),
    payload: erase_style(Ref(value)),
    layout: style_value(StyleSpec::root_style(value)),
    metrics: StyleSpec::metrics(value),
    roots: style_layers(StyleSpec::root_style(value)),
    dynamic: false,
    observe_rules: fn(_, _) { fn() { () } },
    read_layers: None,
    equal_value: fn(a, b) {
      let a : Ref[T] = restore_style(a)
      let b : Ref[T] = restore_style(b)
      a.val == b.val
    },
    debug_value: fn(value) {
      let value : Ref[T] = restore_style(value)
      Repr(value.val)
    },
  }
}

///|
/// Copy local data from the last materialization without running its producer.
/// Reactive declarations describe their materialized value, including state
/// fragments; static declarations preserve their original unset properties.
pub fn StyleDeclaration::snapshot(
  self : StyleDeclaration,
  layers : ReadOnlyArray[StyleDeclaration],
) -> StyleDeclaration? {
  if !self.dynamic {
    return self.static_snapshot()
  }
  let mut result : StyleDeclaration? = None
  for layer in layers {
    if !layer.origin.is_theme() && layer.same_type(self) {
      result = Some(
        match result {
          Some(previous) =>
            {
              ..(layer.merge_data)(previous.payload, layer.payload),
              origin: Merged(previous.origin, layer.origin),
            }
          None => layer
        },
      )
    }
  }
  result
}

///|
fn StyleDeclaration::static_snapshot(
  self : StyleDeclaration,
) -> StyleDeclaration? {
  if self.dynamic {
    None
  } else {
    Some({ ..self, read_layers: None, observe_rules: fn(_, _) { fn() { () } }, })
  }
}

///|
fn[T] style_name(value : () -> T) -> String {
  match describe_style(value) {
    [.. "<obj:() -> ", .. name, '>'] => name.to_owned()
    label => label
  }
}

///|
pub fn StyleDeclaration::observe(
  self : StyleDeclaration,
  sheet : StyleSheet,
  receive : (Bool) -> Unit,
) -> () -> Unit {
  if self.dynamic {
    receive(true)
    fn() { () }
  } else {
    (self.observe_rules)(sheet, receive)
  }
}

///|
impl StyleSpec with fn freeze_fields(self, _) {
  self
}

///|
impl StyleSpec with fn has_source(self) {
  StyleSpec::split_source(self).1 is Some(_)
}
