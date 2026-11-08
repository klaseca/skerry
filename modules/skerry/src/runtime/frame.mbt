///|
/// Diagnostic totals for this root. presented_frame identifies the buffer most
/// recently submitted by the host, which may be older than the latest paint.
#derive(Debug, Eq)
pub(all) struct FrameStats {
  layout_count : Int32
  layout_pass_count : Int32
  text_measure_count : Int32
  text_cache : @text.TextCacheStats
  paint_count : Int32
  present_count : Int32
  presented_frame : Int32
  // Belongs to paint_count, independently of the host's presented_frame.
  last_paint : @diagnostics.PaintStats?
}

///|
pub extend FrameStats with Debug::{to_repr}

///|
pub extend FrameStats with Eq::{equal, not_equal}

///|
#derive(Debug, Eq)
pub(all) enum FrameEvent {
  Invalidated(DirtyState)
  Painted(FrameStats)
  Presented(FrameStats)
}

///|
pub extend FrameEvent with Debug::{to_repr}

///|
pub extend FrameEvent with Eq::{equal, not_equal}

///|
priv struct FrameObserver {
  callback : (FrameEvent) -> Unit
  scope : @reactive.Scope
}

///|
pub fn UiRoot::is_disposed(self : UiRoot) -> Bool {
  self.disposed
}

///|
pub fn UiRoot::needs_frame(self : UiRoot) -> Bool {
  !self.disposed && self.dirty != Clean
}

///|
/// Number of completed paints, used by hosts to label their buffers.
pub fn UiRoot::paint_revision(self : UiRoot) -> Int32 {
  self.paint_count
}

///|
/// Reading statistics does not request a frame or subscribe to signals.
pub fn UiRoot::frame_stats(self : UiRoot) -> FrameStats {
  {
    layout_count: self.layout_state.layout_count(),
    layout_pass_count: self.layout_state.layout_pass_count(),
    text_measure_count: self.layout_state.text_measure_count(),
    text_cache: self.layout_state.text_cache_stats(),
    paint_count: self.paint_count,
    present_count: self.present_count,
    presented_frame: self.presented_frame,
    last_paint: self.last_paint_stats,
  }
}

///|
/// Attach one observer, replacing any previous observer. Callbacks run on the UI
/// thread, untracked and outside application scopes. Nested notifications are
/// suppressed. The returned disposer detaches only this registration.
/// timings=true enables layout/paint timings using the root's monotonic clock.
/// Attachment and detachment do not request a frame. Replacement without timings,
/// detachment and root disposal stop clock reads; counts remain available.
///
/// ```mbt nocheck
/// pub fn profile_frames(root : @runtime.UiRoot) -> () -> Unit {
///   root.observe_frames(
///     fn(event) {
///       if event is Painted(stats) && stats.last_paint is Some(paint) {
///         println("layout: \{paint.layout_ms}, draw: \{paint.paint_ms}")
///       }
///     },
///     timings=true,
///   )
/// }
/// ```
pub fn UiRoot::observe_frames(
  self : UiRoot,
  callback : (FrameEvent) -> Unit,
  timings~ : Bool = false,
) -> () -> Unit {
  guard !self.disposed else { return fn() { () } }
  let observer : FrameObserver = { callback, scope: @reactive.Scope::root(), }
  let previous = self.frame_observer
  self.frame_observer = Some(observer)
  self.layout_state.set_profile_clock(
    if timings {
      Some(self.clock)
    } else {
      None
    },
  )
  if previous is Some(previous) {
    previous.scope.dispose()
  }
  fn() {
    if self.frame_observer is Some(current) && physical_equal(current, observer) {
      self.frame_observer = None
      self.layout_state.set_profile_clock(None)
    }
    observer.scope.dispose()
  }
}

///|
/// Hosts call this after a successful present, using the paint_revision captured
/// for that buffer. Presenting a cached frame increments present_count only.
pub fn UiRoot::record_present(self : UiRoot, frame : Int32) -> Unit {
  guard !self.disposed &&
    !self.painting &&
    !self.draining_actions &&
    !self.presenting &&
    !self.notifying_snapshot else {
    return
  }
  self.presenting = true
  defer (fn() { self.presenting = false })()
  let actions = self.after_present_actions
  self.after_present_actions = []
  self.present_count += 1
  self.presented_frame = frame
  if self.frame_observer is Some(observer) {
    self.notify_frame(observer, Presented(self.frame_stats()))
  }
  self.run_actions(actions)
}

///|
fn UiRoot::notify_frame(
  self : UiRoot,
  observer : FrameObserver,
  event : FrameEvent,
) -> Unit {
  guard !self.disposed && !self.notifying_frame && !observer.scope.is_disposed() else {
    return
  }
  self.notifying_frame = true
  defer (fn() { self.notifying_frame = false })()
  observer.scope.run(fn() { (observer.callback)(event) })
}

///|
fn UiRoot::notify_invalidation(self : UiRoot) -> Unit {
  if @reactive.is_updating() {
    self.scope.run(fn() {
      @reactive.after_update(fn() { self.notify_invalidation() })
    })
    return
  }
  if self.frame_observer is Some(observer) {
    self.notify_frame(observer, Invalidated(self.dirty))
  }
}
