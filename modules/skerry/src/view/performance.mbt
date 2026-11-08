///|
/// Actual Crater layout computations, including reflow passes.
pub fn LayoutState::layout_pass_count(self : LayoutState) -> Int32 {
  self.layout_pass_count
}

///|
/// Metrics provider calls made by this state's independent text session.
/// Includes layout, paint and input using that session.
pub fn LayoutState::text_measure_count(self : LayoutState) -> Int32 {
  self.text_layout_system.measure_count()
}

///|
pub fn LayoutState::text_cache_stats(
  self : LayoutState,
) -> @text.TextCacheStats {
  self.text_layout_system.cache_stats()
}

///|
/// Clear text caches after provider resources change. A custom host must also
/// invalidate layout before using geometry measured with the previous resources.
pub fn LayoutState::clear_text_cache(self : LayoutState) -> Unit {
  self.text_layout_system.clear_cache()
}

///|
/// Release retained geometry/text and disable timing/caching for an unmounted
/// state, including writes by work already in flight. Use a fresh state to remount.
pub fn LayoutState::dispose(self : LayoutState) -> Unit {
  self.disposed = true
  self.theme_overrides.clear()
  self.pointer_cancel()
  self.text_layout_system.set_cache_enabled(false)
  self.set_profile_clock(None)
  self.invalidate()
}

///|
/// Enable timing for a custom host, or disable it with None. Clocks return finite,
/// nondecreasing milliseconds and are read untracked only during actual work.
/// Changing the clock during work makes that paint's timings unavailable.
/// This does not invalidate layout or request a paint. Counts are always active.
pub fn LayoutState::set_profile_clock(
  self : LayoutState,
  clock : (() -> Double)?,
) -> Unit {
  self.profile_generation += 1
  self.profile_clock = clock
  self.layout_ms = 0.0
}

///|
/// Copied values for the last completed paint call, even if later invalidated.
/// Reading does not invoke metrics, layout, application getters or the clock.
pub fn LayoutState::last_paint_stats(
  self : LayoutState,
) -> @diagnostics.PaintStats? {
  self.last_paint_stats
}
