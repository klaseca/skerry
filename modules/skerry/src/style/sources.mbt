///|
/// A concrete style that can carry a lazy readonly source. No field schema is
/// required; only the whole value is split and reattached.
/// computed shares one cache, like reactive.Computed. Capture model handles for
/// shared computations; use bind for provider lookups resolved per mounted node.
pub(open) trait SourceStyle: StyleSpec + Default {
  fn with_source(Self, StyleSource[Self]?) -> Self
  fn computed(() -> Self) -> Self = _
  fn bind(@reactive.Binding[Self]) -> Self = _
}

///|
pub struct StyleSource[T] {
  priv read : (StyleSheet) -> Array[StyleLayer[T]]
  priv resolving : Ref[Bool]
  priv empty : T
  priv frozen : FrozenStyleSource[T]?
  priv equal_frozen : ((FrozenStyleSource[T], FrozenStyleSource[T]) -> Bool)?
}

///|
priv struct StyleLayer[T] {
  value : T
  origin : StyleOrigin
  // Fragments may share one normal/state declaration. A projection is an
  // incoming sequence of declarations and retains its boundaries.
  fragment : Bool
}

///|
priv struct FrozenStyleSource[T] {
  layers : ReadOnlyArray[StyleLayer[T]]
  values : ReadOnlyArray[T]
}

///|
fn[T] style_fragment(value : T) -> StyleLayer[T] {
  { value, origin: Local(style_name((panic : () -> T))), fragment: true, }
}

///|
fn[T : SourceStyle] StyleSource::StyleSource(
  read : (StyleSheet) -> Array[StyleLayer[T]],
) -> StyleSource[T] {
  {
    read,
    resolving: Ref(false),
    empty: Default::default(),
    frozen: None,
    equal_frozen: None,
  }
}

///|
pub impl[T] Eq for StyleSource[T] with fn equal(a, b) {
  match (a.frozen, b.frozen, a.equal_frozen) {
    (Some(a), Some(b), Some(equal)) => equal(a, b)
    _ => physical_equal(a.resolving, b.resolving)
  }
}

///|
pub impl[T] Debug for StyleSource[T] with fn to_repr(_) {
  Repr("StyleSource")
}

///|
pub extend StyleSource with Eq::{equal, not_equal}

///|
pub extend StyleSource with Debug::{to_repr}

///|
fn[T : StyleSpec] expand_style(
  value : T,
  sheet : StyleSheet,
) -> Array[StyleLayer[T]] {
  let (specified, source) = StyleSpec::split_source(value)
  match source {
    None => [style_fragment(specified)]
    Some(source) => {
      guard !source.resolving.val else { abort("Cyclic style source") }
      source.resolving.val = true
      defer {
        source.resolving.val = false
      }
      let result : Array[StyleLayer[T]] = []
      let input = match source.frozen {
        Some(frozen) => frozen.layers.iter().to_array()
        None => (source.read)(sheet)
      }
      for layer in input {
        for nested in expand_style(layer.value, sheet) {
          result.push({
            value: nested.value,
            origin: nest_origin(layer.origin, nested.origin),
            fragment: layer.fragment && nested.fragment,
          })
        }
      }
      if specified != source.empty {
        append_fragment(result, style_fragment(specified))
      }
      result
    }
  }
}

///|
fn[P : StyleSpec, T : SourceStyle] project_style(
  parent : P,
  select : (P) -> T,
) -> T {
  let from = style_name((panic : () -> P))
  let to = style_name((panic : () -> T))
  let source = StyleSource(fn(sheet) {
    let result : Array[StyleLayer[T]] = []
    for index, rule in (sheet.get() : ReadOnlyArray[P]) {
      for layer in expand_style(rule, sheet) {
        result.push({
          value: select(layer.value),
          origin: Projection(
            from~,
            to~,
            source=ThemeRule(
              sheet=sheet.id,
              rule=index,
              family=from,
              source=layer.origin,
            ),
          ),
          fragment: false,
        })
      }
    }
    for layer in expand_style(parent, sheet) {
      result.push({
        value: select(layer.value),
        origin: Projection(from~, to~, source=layer.origin),
        fragment: false,
      })
    }
    result
  })
  SourceStyle::with_source(Default::default(), Some(source))
}

///|
impl SourceStyle with fn computed(read) {
  let cached = @reactive.computed(read)
  SourceStyle::bind(@reactive.bind(fn() { cached.get() }))
}

///|
impl SourceStyle with fn bind(source) {
  match source.constant_value() {
    Some(value) => value
    None => {
      let family = style_name((panic : () -> Self))
      SourceStyle::with_source(
        Default::default(),
        Some(
          StyleSource(fn(sheet) {
            expand_style(source.get(), sheet).map(layer => {
              ..layer,
              origin: Binding(family, layer.origin),
            })
          }),
        ),
      )
    }
  }
}

///|
/// Merge fragments in expression order. Adjacent value fragments share one
/// normal/state declaration; incoming projections retain their declaration edges.
pub fn[T : SourceStyle] merge_sources(a : T, b : T, fields : (T, T) -> T) -> T {
  if a == b {
    return a
  }
  let (_, first) = StyleSpec::split_source(a)
  let (_, second) = StyleSpec::split_source(b)
  if first is None && second is None {
    return fields(a, b)
  }
  let first_frozen = match first {
    None => true
    Some(value) => value.frozen is Some(_)
  }
  let second_frozen = match second {
    None => true
    Some(value) => value.frozen is Some(_)
  }
  if first_frozen && second_frozen {
    let left = frozen_layers(a)
    let right = frozen_layers(b)
    for layer in right {
      append_fragment(left, layer)
    }
    return SourceStyle::with_source(
      Default::default(),
      Some(frozen_source(left)),
    )
  }
  SourceStyle::with_source(
    Default::default(),
    Some(
      StyleSource(fn(sheet) {
        let left = expand_style(a, sheet)
        let right = expand_style(b, sheet)
        for layer in right {
          append_fragment(left, layer)
        }
        left
      }),
    ),
  )
}

///|
/// Store a scalar dependency as a style fragment. Constants stay ordinary data;
/// dynamic values share the consuming node's subscription and create no memo.
pub fn[P : SourceStyle, T] apply_style_value(
  owner : P,
  source : @reactive.Binding[T],
  field : (P, T) -> P,
) -> P {
  match source.constant_value() {
    Some(value) => field(owner, value)
    None => {
      let family = style_name((panic : () -> P))
      StyleSpec::merge(
        owner,
        SourceStyle::with_source(
          Default::default(),
          Some(
            StyleSource(fn(_) {
              [
                {
                  value: field(Default::default(), source.get()),
                  origin: Binding(family, Local(family)),
                  fragment: true,
                },
              ]
            }),
          ),
        ),
      )
    }
  }
}

///|
fn[T : StyleSpec] append_fragment(
  layers : Array[StyleLayer[T]],
  next : StyleLayer[T],
) -> Unit {
  match layers.last() {
    Some(previous) if previous.fragment && next.fragment =>
      layers[layers.length() - 1] = {
        value: StyleSpec::merge(previous.value, next.value),
        origin: Merged(previous.origin, next.origin),
        fragment: true,
      }
    _ => layers.push(next)
  }
}

///|
/// Freeze a nested value while preserving its normal/state rule boundaries.
pub fn[T : SourceStyle] freeze_style(value : T, sheet : StyleSheet) -> T {
  let (_, source) = StyleSpec::split_source(value)
  if source is None {
    return StyleSpec::freeze_fields(value, sheet)
  }
  let values = expand_style(value, sheet).map(layer => {
    ..layer,
    value: StyleSpec::freeze_fields(layer.value, sheet),
  })
  SourceStyle::with_source(Default::default(), Some(frozen_source(values)))
}

///|
/// Read only materialized layers. This never evaluates application code.
pub fn[T : StyleSpec] style_layers(value : T) -> ReadOnlyArray[T] {
  let (specified, source) = StyleSpec::split_source(value)
  match source {
    None => ReadOnlyArray::from_array([specified])
    Some(source) =>
      match source.frozen {
        Some(frozen) if specified == source.empty => frozen.values
        Some(_) => {
          let result = frozen_layers(value).map(layer => layer.value)
          ReadOnlyArray::from_array(result[:])
        }
        None => abort("Style sources must be materialized before painting")
      }
  }
}

///|
fn[T : StyleSpec] frozen_layers(value : T) -> Array[StyleLayer[T]] {
  let (specified, source) = StyleSpec::split_source(value)
  match source {
    None => [style_fragment(specified)]
    Some(source) => {
      let result = source.frozen.unwrap().layers.iter().to_array()
      if specified != source.empty {
        append_fragment(result, style_fragment(specified))
      }
      result
    }
  }
}

///|
/// The normal-value projection. Unresolved inputs expose only their specified
/// fields; diagnostics cannot cause a producer to run.
pub fn[T : StyleSpec] style_value(value : T) -> T {
  let (specified, source) = StyleSpec::split_source(value)
  match source {
    Some(source) if source.frozen is Some(_) => {
      let values = style_layers(value)
      let mut result = values[0]
      for index in 1..<values.length() {
        result = StyleSpec::merge(result, values[index])
      }
      result
    }
    _ => specified
  }
}

///|
pub fn[P : SourceStyle, T : StyleSpec] apply_style_field(
  owner : P,
  value : T,
  field : (P, T) -> P,
) -> P {
  if !StyleSpec::has_source(value) {
    return field(owner, value)
  }
  let patch = SourceStyle::with_source(
    Default::default(),
    Some(
      StyleSource(fn(sheet) {
        expand_style(value, sheet).map(layer => {
          value: field(Default::default(), layer.value),
          origin: layer.origin,
          fragment: layer.fragment,
        })
      }),
    ),
  )
  StyleSpec::merge(owner, patch)
}

///|
fn[T : SourceStyle] frozen_source(
  layers : Array[StyleLayer[T]],
) -> StyleSource[T] {
  let values = layers.map(layer => layer.value)
  {
    read: fn(_) { abort("A frozen source contains data, not a producer") },
    resolving: Ref(false),
    empty: Default::default(),
    frozen: Some({
      layers: ReadOnlyArray::from_array(layers[:]),
      values: ReadOnlyArray::from_array(values[:]),
    }),
    equal_frozen: Some(fn(a, b) {
      guard a.values == b.values else { return false }
      for index in 0..<a.layers.length() {
        if a.layers[index].fragment != b.layers[index].fragment {
          return false
        }
      }
      true
    }),
  }
}
