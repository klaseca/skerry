///|
let next_root_id_ref : Ref[Int32] = Ref(0)

///|
fn next_root_id() -> Int32 {
  let id = next_root_id_ref.val
  next_root_id_ref.val = id + 1
  id
}

///|
/// Geometry uses logical UI units, independent of the host's pixel density.
/// An immutable description of a completed, consistent paint. Selection uses
/// (root_id, node.id), so roots mounting the same View remain distinct.
/// frame.paint_count labels this tree; frame.presented_frame describes the
/// host's most recent present at capture time (valid when present_count != 0).
/// Pending changes do not update an already captured snapshot.
/// Theme contains font/tokens and static defaults used by this paint; reactive
/// rules appear as materialized data in each node's style_layers.
#derive(Debug, Eq)
pub(all) struct UiSnapshot {
  root_id : Int32
  frame : FrameStats
  theme : @style.Theme
  tree : @diagnostics.TreeSnapshot
  focused_node_id : Int32?
  captured_node_id : Int32?
  rendering : RenderingInfo?
}

///|
pub extend UiSnapshot with Debug::{to_repr}

///|
pub extend UiSnapshot with Eq::{equal, not_equal}

///|
priv struct SnapshotObserver {
  callback : (UiSnapshot) -> Unit
  scope : @reactive.Scope
}

///|
/// Read diagnostic values on demand, without layout, paint, wakeup or tracking.
/// None means disposed, no completed paint, pending frame work, action/present
/// delivery in progress, or a changed layout since paint. The root does not
/// retain snapshot history. Previously returned values remain readable.
pub fn UiRoot::snapshot(self : UiRoot) -> UiSnapshot? {
  guard !self.painting && !self.draining_actions && !self.presenting else {
    return None
  }
  self.snapshot_now()
}

///|
fn UiRoot::snapshot_now(self : UiRoot) -> UiSnapshot? {
  guard !self.disposed && self.dirty == Clean else { return None }
  self.layout_state
  .snapshot(self.view)
  .map(tree => {
    root_id: self.id,
    frame: self.frame_stats(),
    theme: self.theme().snapshot(),
    tree,
    focused_node_id: self.focused_node_id,
    captured_node_id: self.captured_node_id,
    rendering: self.rendering,
  })
}

///|
/// Attach one snapshot observer, replacing the previous registration. A clean
/// painted root is delivered immediately, then each consistent paint is delivered
/// after its Painted frame notification. Unstable paints wait for the next frame.
/// Callbacks run untracked in an independent diagnostic scope; nested delivery
/// is suppressed. Attachment/detachment does not request a frame. Without an
/// observer or an explicit snapshot query, no diagnostic tree is built.
///
/// ```mbt nocheck
/// pub fn attach_tree_logger(root : @runtime.UiRoot) -> () -> Unit {
///   root.observe_snapshots(fn(snapshot) {
///     println(
///       "frame \{snapshot.frame.paint_count}: \{snapshot.tree.nodes.length()} nodes",
///     )
///   })
/// }
/// ```
pub fn UiRoot::observe_snapshots(
  self : UiRoot,
  callback : (UiSnapshot) -> Unit,
) -> () -> Unit {
  guard !self.disposed else { return fn() { () } }
  let observer : SnapshotObserver = {
    callback,
    scope: @reactive.Scope::root(),
  }
  let previous = self.snapshot_observer
  self.snapshot_observer = Some(observer)
  if previous is Some(previous) {
    previous.scope.dispose()
  }
  if self.snapshot() is Some(snapshot) {
    self.notify_snapshot(observer, snapshot)
  }
  fn() {
    if self.snapshot_observer is Some(current) &&
      physical_equal(current, observer) {
      self.snapshot_observer = None
    }
    observer.scope.dispose()
  }
}

///|
fn UiRoot::notify_snapshot(
  self : UiRoot,
  observer : SnapshotObserver,
  snapshot : UiSnapshot,
) -> Unit {
  guard !self.disposed &&
    !self.notifying_snapshot &&
    !observer.scope.is_disposed() &&
    self.snapshot_observer is Some(current) &&
    physical_equal(current, observer) else {
    return
  }
  self.notifying_snapshot = true
  defer (fn() { self.notifying_snapshot = false })()
  observer.scope.run(fn() { (observer.callback)(snapshot) })
}
