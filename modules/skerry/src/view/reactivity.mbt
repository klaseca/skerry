///|
priv struct KeyedChild[T, K] {
  key : K
  value : @reactive.Signal[T]
  node : UiNode
  scope : @reactive.Scope
  mut dispose : (() -> Unit)?
}

///|
fn[T, K] keyed_child(
  item : T,
  key : K,
  render : (() -> T) -> View,
  key_label? : (K) -> String,
) -> KeyedChild[T, K] {
  let value = @reactive.signal(item)
  let scope = @reactive.Scope::new()
  let node = scope.run(fn() {
    let node = render(fn() { value.get() }).node
    match key_label {
      Some(format) => node.label_key(format(key))
      None => node
    }
  })
  { key, value, node, scope, dispose: None, }
}

///|
fn empty_reactivity() -> Reactivity {
  {
    mount: fn(host) {
      ignore(host.mark_paint_dirty)
      fn() { () }
    },
    manages_children: false,
    text_value: None,
    image_value: None,
  }
}

///|
fn paint_reactivity(track : () -> Unit) -> Reactivity {
  {
    mount: fn(host) {
      let first_run = Ref(true)
      @reactive.render_effect(fn() {
        track()
        if first_run.val {
          first_run.val = false
        } else {
          (host.mark_paint_dirty)()
        }
      })
    },
    manages_children: false,
    text_value: None,
    image_value: None,
  }
}

///|
priv struct ShowState {
  scope : @reactive.Scope
  mut branch_scope : @reactive.Scope
  mut visible : Bool
  children : Ref[Array[UiNode]]
}

///|
fn dynamic_children_reactivity(
  state : ShowState,
  condition : () -> Bool,
  render : () -> View,
) -> Reactivity {
  {
    mount: fn(host) {
      let scope = state.scope
      let dispose_children = Ref(
        state.branch_scope.run(fn() {
          mount_claimed_nodes(state.children.val, host)
        }),
      )
      let dispose_effect = scope.run(fn() {
        @reactive.render_effect(fn() {
          let visible = condition()
          guard visible != state.visible else { return }
          scope.run(fn() {
            state.visible = visible
            let stop_children = dispose_children.val
            dispose_children.val = fn() { () }
            stop_children()
            state.branch_scope.dispose()
            guard !scope.is_disposed() else { return }
            let next_scope = scope.child()
            let next = next_scope.run(fn() {
              if visible {
                [render().node]
              } else {
                []
              }
            })
            if scope.is_disposed() {
              next_scope.dispose()
              return
            }
            state.children.val = next
            state.branch_scope = next_scope
            dispose_children.val = next_scope.run(fn() {
              mount_child_nodes(next, host)
            })
            (host.mark_layout_dirty)()
          })
        })
      })
      fn() {
        dispose_effect()
        let stop_children = dispose_children.val
        dispose_children.val = fn() { () }
        stop_children()
        state.branch_scope.dispose()
        scope.dispose()
        state.children.val = []
      }
    },
    manages_children: true,
    text_value: None,
    image_value: None,
  }
}

///|
priv struct KeyedChildrenState[T, K] {
  scope : @reactive.Scope
  mut entries : Array[KeyedChild[T, K]]
  children : Ref[Array[UiNode]]
}

///|
fn[T, K : Eq] keyed_children_reactivity(
  state : KeyedChildrenState[T, K],
  items : () -> Array[T],
  key : (T) -> K,
  render : (() -> T) -> View,
  key_label : ((K) -> String)?,
) -> Reactivity {
  {
    mount: fn(host) {
      let scope = state.scope
      let first_run = Ref(true)
      let dispose_effect = scope.run(fn() {
        @reactive.render_effect(fn() {
          let next_items = items()
          scope.run(fn() {
            @reactive.batch(fn() {
              let next = reconcile_keyed_entries(
                state.entries,
                next_items,
                key,
                render,
                key_label,
                host,
                scope,
              )
              guard !scope.is_disposed() else {
                dispose_keyed_entries(next)
                return
              }
              state.entries = next
              state.children.val = next.map(entry => entry.node)
              if first_run.val {
                first_run.val = false
                mount_keyed_entries(next, host)
              } else {
                (host.mark_layout_dirty)()
              }
            })
          })
        })
      })
      fn() {
        dispose_effect()
        dispose_keyed_entries(state.entries)
        scope.dispose()
        state.entries = []
        state.children.val = []
      }
    },
    manages_children: true,
    text_value: None,
    image_value: None,
  }
}

///|
fn[T, K] mount_keyed_entries(
  entries : Array[KeyedChild[T, K]],
  host : MountContext,
) -> Unit {
  for entry in entries {
    if entry.dispose is None {
      entry.dispose = Some(
        entry.scope.run(fn() { entry.node.mount_claimed(host) }),
      )
    }
  }
}

///|
fn[T, K : Eq] reconcile_keyed_entries(
  current : Array[KeyedChild[T, K]],
  items : Array[T],
  key : (T) -> K,
  render : (() -> T) -> View,
  key_label : ((K) -> String)?,
  host : MountContext,
  scope : @reactive.Scope,
) -> Array[KeyedChild[T, K]] {
  let used = Array::make(current.length(), false)
  let next : Array[KeyedChild[T, K]] = []
  for item in items {
    guard !scope.is_disposed() else { break }
    let item_key = key(item)
    match find_unused_key(current, used, item_key) {
      Some(index) => {
        used[index] = true
        let entry = current[index]
        entry.value.set(item)
        next.push(entry)
      }
      None => {
        let entry = keyed_child(item, item_key, render, key_label?)
        if !scope.is_disposed() {
          entry.dispose = Some(
            entry.scope.run(fn() { entry.node.mount_reactivity(host) }),
          )
        }
        next.push(entry)
      }
    }
  }
  for index, entry in current {
    if !used[index] {
      dispose_keyed_entry(entry)
    }
  }
  next
}

///|
fn[T, K : Eq] find_unused_key(
  entries : Array[KeyedChild[T, K]],
  used : Array[Bool],
  key : K,
) -> Int32? {
  for index, entry in entries {
    if !used[index] && entry.key == key {
      break Some(index)
    }
  } nobreak {
    None
  }
}

///|
fn[T, K] dispose_keyed_entries(entries : Array[KeyedChild[T, K]]) -> Unit {
  for entry in entries {
    dispose_keyed_entry(entry)
  }
}

///|
fn[T, K] dispose_keyed_entry(entry : KeyedChild[T, K]) -> Unit {
  if entry.dispose is Some(dispose) {
    entry.dispose = None
    dispose()
  } else {
    entry.node.discard_claimed()
  }
  entry.scope.dispose()
}

///|
/// Mount the view's internal subscriptions. The returned disposer is idempotent.
/// `on_node_detach` runs before a node's handlers become unreachable, including
/// when a dynamic branch or keyed entry is removed.
/// `on_disabled_change` reports a changed local disabled condition (not initial
/// mount), after the update's source values materialize. Custom hosts revalidate
/// focus and capture, including descendants of the reported node, and invalidate
/// before invoking application callbacks. Mount before using reactive properties.
/// UiRoot handles this automatically. Neither callback requests layout.
/// This instance and its descendants must not have been mounted before. Reusing
/// a mounted/disposed instance or placing it twice in a tree is a programming
/// error; create fresh instances by calling their component functions again.
pub fn View::mount_reactivity(
  self : View,
  mark_layout_dirty~ : () -> Unit,
  mark_paint_dirty~ : () -> Unit,
  on_node_detach~ : (Int32) -> Unit = fn(_) { () },
  on_theme_change~ : (Int32, @style.Theme?) -> Unit = fn(_, _) { () },
  on_disabled_change~ : (Int32) -> Unit = fn(_) { () },
  style_sheet? : @style.StyleSheet,
) -> () -> Unit {
  self.with_scope(fn() {
    let host = {
      mark_layout_dirty,
      mark_paint_dirty,
      on_node_detach,
      on_theme_change,
      on_disabled_change,
      style_sheet: match @environment.current_theme_provider() {
        Some(provider) => Some(provider.sheet())
        None => style_sheet
      },
      style_theme: @environment.current_theme_provider(),
      can_change: fn(id) {
        self.path_for_node_id(id) is Some(path) && self.is_enabled_path(path)
      },
    }
    self.node.mount_reactivity(host)
  })
}

///|
fn UiNode::mount_reactivity(self : UiNode, host : MountContext) -> () -> Unit {
  claim_new_nodes([self])
  self.mount_claimed(host)
}

///|
fn UiNode::mount_claimed(self : UiNode, host : MountContext) -> () -> Unit {
  self.lifecycle.phase = Mounted
  self.lifecycle.scope = @reactive.Scope::current()
  let host = match self.geometry {
    Some({ theme: Some(spec), .. }) =>
      {
        ..host,
        style_sheet: Some(spec.provider.sheet()),
        style_theme: Some(spec.provider),
      }
    _ => host
  }
  let disposed = Ref(false)
  let disposers : Array[() -> Unit] = []
  let unregister_change = if self.events.editable {
    @environment.register_change_target(self.id, host.can_change)
  } else {
    fn() { () }
  }
  if self.events.disabled is Some(spec) && spec.constant_value() is None {
    disposers.push(self.mount_disabled(spec, host))
  }
  if self.geometry is Some({ theme: Some(spec), .. }) {
    let stop = @reactive.render_effect(fn() {
      let next = (spec.source)()
      @reactive.untracked(fn() { (host.on_theme_change)(self.id, Some(next)) })
    })
    disposers.push(fn() {
      stop()
      (host.on_theme_change)(self.id, None)
    })
  }
  if self.styles is Some(styles) {
    disposers.push(styles.mount(host))
  }
  disposers.push((self.reactivity.mount)(host))
  if !self.reactivity.manages_children {
    for child in self.children.val {
      disposers.push(child.mount_claimed(host))
    }
  }
  fn() {
    guard !disposed.val else { return }
    disposed.val = true
    self.lifecycle.phase = Disposed
    unregister_change()
    // Notify the host while this node and its event handlers are reachable.
    (host.on_node_detach)(self.id)
    for disposer in disposers {
      disposer()
    }
  }
}

///|
fn mount_child_nodes(nodes : Array[UiNode], host : MountContext) -> () -> Unit {
  claim_new_nodes(nodes)
  mount_claimed_nodes(nodes, host)
}

///|
fn mount_claimed_nodes(
  nodes : Array[UiNode],
  host : MountContext,
) -> () -> Unit {
  let disposers : Array[() -> Unit] = []
  for child in nodes {
    disposers.push(child.mount_claimed(host))
  }
  fn() {
    for disposer in disposers {
      disposer()
    }
  }
}
