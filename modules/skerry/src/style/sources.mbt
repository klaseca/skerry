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
  priv read : (StyleSheet) -> Array[T]
  priv resolving : Ref[Bool]
  priv empty : T
  priv frozen : ReadOnlyArray[T]?
  priv equal_frozen : ((ReadOnlyArray[T], ReadOnlyArray[T]) -> Bool)?
}

///|
fn[T : SourceStyle] StyleSource::StyleSource(
  read : (StyleSheet) -> Array[T],
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
fn[T : StyleSpec] expand_style(value : T, sheet : StyleSheet) -> Array[T] {
  let (specified, source) = StyleSpec::split_source(value)
  match source {
    None => [specified]
    Some(source) => {
      guard !source.resolving.val else { abort("Cyclic style source") }
      source.resolving.val = true
      defer {
        source.resolving.val = false
      }
      let result : Array[T] = []
      let input = match source.frozen {
        Some(values) => values.iter().to_array()
        None => (source.read)(sheet)
      }
      for layer in input {
        result.append(expand_style(layer, sheet))
      }
      append_local(result, specified)
      result
    }
  }
}

///|
fn[P : StyleSpec, T : SourceStyle] project_style(
  parent : P,
  select : (P) -> T,
) -> T {
  let source = StyleSource(fn(sheet) {
    let result : Array[T] = []
    for rule in (sheet.get() : ReadOnlyArray[P]) {
      for value in expand_style(rule, sheet) {
        result.push(select(value))
      }
    }
    for value in expand_style(parent, sheet) {
      result.push(select(value))
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
    None =>
      SourceStyle::with_source(
        Default::default(),
        Some(StyleSource(fn(_) { [source.get()] })),
      )
  }
}

///|
/// Compose source-bearing fragments without folding their state layers.
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
    let left = style_layers(a).iter().to_array()
    let right = style_layers(b).iter().to_array()
    let local_a = left.pop().unwrap()
    let local_b = right.pop().unwrap()
    left.append(right)
    left.push(fields(local_a, local_b))
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
        let local_a = left.pop().unwrap()
        let local_b = right.pop().unwrap()
        left.append(right)
        left.push(StyleSpec::merge(local_a, local_b))
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
    None =>
      StyleSpec::merge(
        owner,
        SourceStyle::with_source(
          Default::default(),
          Some(StyleSource(fn(_) { [field(Default::default(), source.get())] })),
        ),
      )
  }
}

///|
fn[T : StyleSpec] append_local(layers : Array[T], specified : T) -> Unit {
  match layers.pop() {
    Some(last) => layers.push(StyleSpec::merge(last, specified))
    None => layers.push(specified)
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
    StyleSpec::freeze_fields(layer, sheet)
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
        Some(values) if specified == source.empty => values
        Some(values) => {
          let result = values.iter().to_array()
          append_local(result, specified)
          ReadOnlyArray::from_array(result[:])
        }
        None => abort("Style sources must be materialized before painting")
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
        expand_style(value, sheet).map(value => field(Default::default(), value))
      }),
    ),
  )
  StyleSpec::merge(owner, patch)
}

///|
fn[T : SourceStyle] frozen_source(values : Array[T]) -> StyleSource[T] {
  {
    read: fn(_) { abort("A frozen source contains data, not a producer") },
    resolving: Ref(false),
    empty: Default::default(),
    frozen: Some(ReadOnlyArray::from_array(values[:])),
    equal_frozen: Some(fn(a, b) { a == b }),
  }
}
