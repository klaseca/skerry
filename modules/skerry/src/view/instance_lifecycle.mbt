///|
priv enum MountPhase {
  Available
  Claimed
  Mounted
  Disposed
}

///|
priv struct NodeLifecycle {
  mut phase : MountPhase
  mut scope : @reactive.Scope?
  mut disabled : Bool
}

///|
fn NodeLifecycle::NodeLifecycle() -> NodeLifecycle {
  { phase: Available, scope: None, disabled: false, }
}

///|
// Validate the whole new subtree before starting any subscriptions. Reserving
// the shared cell detects aliases (including decorated handles) without relying
// on wrapping numeric node IDs. Failed validation restores only new claims.
fn claim_nodes(nodes : Array[UiNode]) -> String? {
  let claimed : Array[NodeLifecycle] = []
  for node in nodes {
    if node.claim_branch(claimed) is Some(problem) {
      for lifecycle in claimed {
        lifecycle.phase = Available
      }
      return Some(problem)
    }
  }
  None
}

///|
fn UiNode::claim_branch(
  self : UiNode,
  claimed : Array[NodeLifecycle],
) -> String? {
  match self.lifecycle.phase {
    Claimed | Mounted =>
      return Some(
        "\{self.component_name} View is already mounted or appears more than once; call the component function to create another instance",
      )
    Disposed =>
      return Some(
        "\{self.component_name} View has been disposed; call the component function to create another instance",
      )
    Available => ()
  }
  self.lifecycle.phase = Claimed
  claimed.push(self.lifecycle)
  for child in self.children.val {
    if child.claim_branch(claimed) is Some(problem) {
      return Some(problem)
    }
  }
  None
}

///|
fn claim_new_nodes(nodes : Array[UiNode]) -> Unit {
  if claim_nodes(nodes) is Some(problem) {
    abort(problem)
  }
}

///|
// A keyed entry can disappear between construction and its first subscription.
// It has no host callbacks to detach, but its reserved descendants are finished.
fn UiNode::discard_claimed(self : UiNode) -> Unit {
  guard self.lifecycle.phase is Claimed else { return }
  self.lifecycle.phase = Disposed
  for child in self.children.val {
    child.discard_claimed()
  }
}
