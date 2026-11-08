///|
const METRICS_CACHE_CAPACITY : Int32 = 256

///|
const LAYOUT_CACHE_CAPACITY : Int32 = 64

///|
// Per cache: strings, caret arrays and line payload. Fixed entry/map overhead is
// separately bounded by capacity. Oversized items are used without retention.
const CACHE_PAYLOAD_LIMIT : Int32 = 256 * 1024

///|
#derive(Eq)
priv struct MeasureCacheKey {
  text : String
  font : @foundation.FontSpec
}

///|
impl Hash for MeasureCacheKey with fn hash_combine(self, hasher) {
  // Equality compares the full FontSpec. Hashing its size remains correct if
  // more font properties are added; they may share a bucket, never an entry.
  Hash::hash_combine((self.text, self.font.point_size()), hasher)
}

///|
#derive(Eq)
priv struct LayoutCacheKey {
  text : String
  font : @foundation.FontSpec
  max_width : Double?
}

///|
impl Hash for LayoutCacheKey with fn hash_combine(self, hasher) {
  Hash::hash_combine(
    (self.text, self.font.point_size(), self.max_width),
    hasher,
  )
}

///|
priv struct CacheEntry[V] {
  value : V
  payload_bytes : Int32
}

///|
priv struct TextCache[K, V] {
  capacity : Int32
  entries : Map[K, CacheEntry[V]]
  mut payload_bytes : Int32
  mut hits : Int32
  mut evictions : Int32
}

///|
fn[K : Hash + Eq, V] TextCache::new(capacity : Int32) -> TextCache[K, V] {
  { capacity, entries: {}, payload_bytes: 0, hits: 0, evictions: 0, }
}

///|
fn[K : Hash + Eq, V] TextCache::get(self : TextCache[K, V], key : K) -> V? {
  self.entries
  .get(key)
  .map(entry => {
    // Map preserves insertion order: moving this entry to the end makes the
    // first entry the least recently used, without timestamps or cyclic links.
    self.entries.remove(key)
    self.entries[key] = entry
    self.hits += 1
    entry.value
  })
}

///|
fn[K : Hash + Eq, V] TextCache::put(
  self : TextCache[K, V],
  key : K,
  value : V,
  payload_bytes : Int32,
) -> Unit {
  if self.entries.get(key) is Some(previous) {
    self.entries.remove(key)
    self.payload_bytes -= previous.payload_bytes
  }
  while self.entries.length() >= self.capacity ||
        payload_bytes > CACHE_PAYLOAD_LIMIT - self.payload_bytes {
    if self.entries.iter().next() is Some((oldest, entry)) {
      self.entries.remove(oldest)
      self.payload_bytes -= entry.payload_bytes
      self.evictions += 1
    } else {
      break
    }
  }
  self.entries[key] = { value, payload_bytes, }
  self.payload_bytes += payload_bytes
}

///|
fn[K, V] TextCache::clear(self : TextCache[K, V]) -> Unit {
  self.entries.clear()
  self.payload_bytes = 0
}

///|
/// Current retained entries/payload and cumulative hits/evictions for a session.
/// Payload accounts for UTF-16 strings, caret doubles and line values; it excludes
/// allocator and fixed entry overhead. Limits are 256 metric entries, 64 layout
/// entries and 256 KiB of accounted payload for each cache.
#derive(Eq, Debug)
pub(all) struct TextCacheStats {
  enabled : Bool
  measure_hits : Int32
  layout_hits : Int32
  measure_entries : Int32
  layout_entries : Int32
  payload_bytes : Int32
  evictions : Int32
}

///|
pub extend TextCacheStats with Eq::{equal, not_equal}

///|
pub extend TextCacheStats with Debug::{to_repr}

///|
/// Read copied cache statistics without layout, metrics, tracking or callbacks.
pub fn TextLayoutSystem::cache_stats(self : TextLayoutSystem) -> TextCacheStats {
  {
    enabled: self.cache_enabled,
    measure_hits: self.metrics_cache.hits,
    layout_hits: self.layout_cache.hits,
    measure_entries: self.metrics_cache.entries.length(),
    layout_entries: self.layout_cache.entries.length(),
    payload_bytes: self.metrics_cache.payload_bytes +
    self.layout_cache.payload_bytes,
    evictions: self.metrics_cache.evictions + self.layout_cache.evictions,
  }
}

///|
/// Drop retained text data after metrics change. Counts and cumulative cache
/// statistics remain available. In-flight requests do not store pre-clear results.
/// This method does not invalidate a host's existing geometry or request a frame.
///
/// ```mbt check
/// test {
///   let system = @text.TextLayoutSystem::from_metrics(
///     TextMetricsProvider(measure=fn(input) {
///       TextMetrics(
///         width=input.text.length().to_double(),
///         line_height=10.0,
///         baseline=8.0,
///         caret_positions=[],
///       )
///     }),
///   )
///   let input = @text.TextLayoutInput(text="hello")
///   ignore(system.layout(input))
///   let calls = system.measure_count()
///   ignore(system.layout(input))
///   assert_eq(system.measure_count(), calls)
///   system.clear_cache()
///   assert_eq(system.cache_stats().layout_entries, 0)
///   ignore(system.layout(input))
///   assert_eq(system.measure_count(), calls + 1)
/// }
/// ```
pub fn TextLayoutSystem::clear_cache(self : TextLayoutSystem) -> Unit {
  self.cache_generation += 1
  self.metrics_cache.clear()
  self.layout_cache.clear()
}

///|
/// Enable/disable caching for this session and clear entries on a policy change.
/// Disabling is useful for providers whose results vary beyond text/font inputs.
/// Existing sessions created from this system keep their own policy and caches.
pub fn TextLayoutSystem::set_cache_enabled(
  self : TextLayoutSystem,
  enabled : Bool,
) -> Unit {
  if self.cache_enabled != enabled {
    self.cache_enabled = enabled
    self.clear_cache()
  }
}

///|
fn cache_payload_add(
  total : Int32,
  count : Int32,
  element_bytes : Int32,
) -> Int32? {
  // Check before multiplying/adding: accounting stays within the small payload
  // limit even for a very large provider result or text length.
  if count > (CACHE_PAYLOAD_LIMIT - total) / element_bytes {
    None
  } else {
    Some(total + count * element_bytes)
  }
}

///|
fn metrics_payload_bytes(
  input : TextMeasureInput,
  metrics : TextMetrics,
) -> Int32? {
  guard cache_payload_add(0, input.text.length(), 2) is Some(bytes) else {
    return None
  }
  cache_payload_add(bytes, metrics.caret_positions.length(), 8)
}

///|
fn layout_payload_bytes(
  input : TextLayoutInput,
  layout : TextLayoutResult,
) -> Int32? {
  guard cache_payload_add(0, input.text.length(), 2) is Some(bytes) else {
    return None
  }
  guard cache_payload_add(bytes, layout.caret_positions.length(), 8)
    is Some(bytes) else {
    return None
  }
  guard cache_payload_add(bytes, layout.lines.length(), 48) is Some(initial) else {
    return None
  }
  let mut bytes = initial
  for line in layout.lines {
    guard cache_payload_add(bytes, line.text.length(), 2) is Some(next) else {
      return None
    }
    bytes = next
  }
  Some(bytes)
}

///|
fn TextLayoutResult::copy(self : TextLayoutResult) -> TextLayoutResult {
  {
    ..self,
    lines: self.lines.copy(),
    caret_positions: self.caret_positions.copy(),
  }
}
