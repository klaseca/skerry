///|
#derive(Eq, Debug)
pub(all) enum DirtyState {
  Clean
  NeedsPaint
  NeedsLayout
}

///|
pub extend DirtyState with Eq::{not_equal, equal}

///|
pub extend DirtyState with Debug::{to_repr}

///|
pub struct UiRoot {
  priv id : Int32
  priv view : @view.View
  priv mut dirty : DirtyState
  priv layout_state : @view.LayoutState
  priv mut focused_node_id : Int32?
  priv mut focus_request : Ref[Bool]
  priv mut captured_node_id : Int32?
  priv mut captured_scrollbar : Bool
  priv mut pointer_position : @foundation.Point?
  priv mut hovered_node_id : Int32?
  priv mut keyboard_press : (Int32, @foundation.Key)?
  priv mut viewport_size : @foundation.Size?
  priv mut pending_focus_reveal : Int32?
  priv mut revealing_focus : Bool
  priv mut dispose_reactivity : () -> Unit
  priv scope : @reactive.Scope
  priv lifetime : @reactive.Scope
  priv theme_environment : @reactive.Signal[@environment.ThemeEnvironment]
  priv system_theme_value : @reactive.Signal[ColorScheme?]
  priv mut disposed : Bool
  priv mut losing_focus : Bool
  priv mut painting : Bool
  priv mut presenting : Bool
  priv mut paint_count : Int32
  priv mut present_count : Int32
  priv mut presented_frame : Int32
  priv mut last_paint_stats : @diagnostics.PaintStats?
  priv mut frame_observer : FrameObserver?
  priv mut notifying_frame : Bool
  priv mut snapshot_observer : SnapshotObserver?
  priv mut notifying_snapshot : Bool
  priv mut actions : Array[UiAction]
  priv mut timers : Array[UiTimer]
  priv mut after_present_actions : Array[UiAction]
  priv clock : () -> Double
  priv mut draining_actions : Bool
  priv wakeup_callback : Ref[(() -> Unit)?]
  priv mut popup_sessions : Array[PopupSession]
  priv mut syncing_popups : Bool
  priv mut popups_pending : Bool
}

///|
/// Mount a root. Custom clocks return finite, nondecreasing milliseconds;
/// the default uses a monotonic clock, independent of wall-clock adjustments.
/// builder runs once and must return a fresh View instance. For another root,
/// call the component function again; a ready View cannot be mounted twice.
pub fn mount(
  builder : () -> @view.View,
  text_layout_system~ : @text.TextLayoutSystem,
  theme~ : @style.Theme = Theme(),
  color_scheme~ : ColorScheme = Light,
  providers~ : Array[@reactive.ContextBinding] = [],
  clock~ : () -> Double = monotonic_milliseconds,
) -> UiRoot {
  mount_configured(
    builder,
    text_layout_system~,
    theme~,
    color_scheme~,
    providers~,
    clock~,
  )
}

///|
fn mount_configured(
  builder : () -> @view.View,
  text_layout_system~ : @text.TextLayoutSystem,
  theme~ : @style.Theme = Theme(),
  color_scheme~ : ColorScheme = Light,
  providers~ : Array[@reactive.ContextBinding],
  app? : App,
  system_theme? : ColorScheme,
  clock~ : () -> Double,
) -> UiRoot {
  let lifetime = @reactive.Scope::root()
  let theme_environment = @reactive.signal(
    @environment.ThemeEnvironment(theme, color_scheme~),
  )
  let system_theme_value = @reactive.signal(system_theme)
  let bindings = providers.copy()
  bindings.push(
    lifetime.run(fn() { @environment.theme_binding(theme_environment) }),
  )
  bindings.push(@environment.control_binding())
  bindings.push(@environment.values_binding())
  if app is Some(app) {
    bindings.push(app_context.provide(Some(app)))
  }
  lifetime.run_with(bindings, fn() {
    let scope = @reactive.Scope::current().unwrap()
    let pending : Ref[UiRoot?] = Ref(None)
    if app is Some(app) {
      ignore(
        @reactive.render_effect(fn() {
          let next = app.resolve_theme(system_theme_value)
          @reactive.untracked(fn() {
            if pending.val is Some(root) {
              root.set_theme_context(next)
            } else {
              let environment = @environment.ThemeEnvironment(
                next.theme,
                color_scheme=next.color_scheme,
              )
              if theme_environment.peek() != environment {
                theme_environment.set(environment)
              }
            }
          })
        }),
      )
    }
    let root = mount_owned(
      builder,
      text_layout_system~,
      scope~,
      lifetime~,
      theme_environment~,
      system_theme_value~,
      clock~,
    )
    pending.val = Some(root)
    root.set_theme_context(theme_environment.peek().context)
    root
  })
}

///|
fn mount_owned(
  builder : () -> @view.View,
  text_layout_system~ : @text.TextLayoutSystem,
  scope~ : @reactive.Scope,
  lifetime~ : @reactive.Scope,
  theme_environment~ : @reactive.Signal[@environment.ThemeEnvironment],
  system_theme_value~ : @reactive.Signal[ColorScheme?],
  clock~ : () -> Double,
) -> UiRoot {
  let root : UiRoot = {
    id: next_root_id(),
    view: scope.run(builder),
    dirty: NeedsLayout,
    layout_state: LayoutState(
      text_layout_system~,
      theme=theme_environment.peek().context.theme,
    ),
    focused_node_id: None,
    focus_request: Ref(false),
    captured_node_id: None,
    captured_scrollbar: false,
    pointer_position: None,
    hovered_node_id: None,
    keyboard_press: None,
    viewport_size: None,
    pending_focus_reveal: None,
    revealing_focus: false,
    dispose_reactivity: fn() { () },
    scope,
    lifetime,
    theme_environment,
    system_theme_value,
    disposed: false,
    losing_focus: false,
    painting: false,
    presenting: false,
    paint_count: 0,
    present_count: 0,
    presented_frame: 0,
    last_paint_stats: None,
    frame_observer: None,
    notifying_frame: false,
    snapshot_observer: None,
    notifying_snapshot: false,
    actions: [],
    timers: [],
    after_present_actions: [],
    clock,
    draining_actions: false,
    wakeup_callback: Ref(None),
    popup_sessions: [],
    syncing_popups: false,
    popups_pending: false,
  }
  root.dispose_reactivity = scope.run(fn() {
    root.view.mount_reactivity(
      style_sheet=root.layout_state.style_sheet(),
      mark_layout_dirty=fn() { root.mark_layout_dirty() },
      mark_paint_dirty=fn() { root.mark_paint_dirty() },
      on_disabled_change=fn(_) { root.prune_disabled_interactions() },
      clock=root.clock,
      request_focus=fn(id) {
        guard !root.disposed &&
          !root.losing_focus &&
          root.view
          .focusable_paths()
          .any(path => root.view.node_id_at_path(path) == Some(id)) else {
          return false
        }
        root.scope.run(fn() {
          @reactive.during_update(fn() {
            root.set_focus(id, reveal=true)
            root.reveal_focus()
            root.focused_node_id == Some(id)
          })
        })
      },
      on_theme_change=fn(id, theme) {
        if root.layout_state.set_theme_override(id, theme) {
          if root.layout_state.needs_layout() {
            root.mark_layout_dirty()
          } else {
            root.mark_paint_dirty()
          }
        }
      },
      on_node_detach=fn(node_id) {
        if root.hovered_node_id == Some(node_id) {
          root.hovered_node_id = None
          root.mark_paint_dirty()
        }
        if root.captured_node_id == Some(node_id) {
          ignore(root.pointer_cancel())
        }
        if root.focused_node_id == Some(node_id) {
          root.clear_focus()
        }
      },
    )
  })
  @environment.mark_values_materialized(root.view.node_id_at_path([]).unwrap())
  root.dirty = NeedsLayout
  root.sync_popups()
  root
}

///|
pub fn UiRoot::dispose(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  self.disposed = true
  self.popup_sessions = []
  self.pointer_position = None
  self.hovered_node_id = None
  self.keyboard_press = None
  self.layout_state.dispose()
  self.dirty = Clean
  let wakeup = self.wakeup_callback.val
  self.wakeup_callback.val = None
  for action in self.actions {
    action.callback = None
  }
  self.actions = []
  for timer in self.timers {
    timer.action.callback = None
  }
  self.timers = []
  for action in self.after_present_actions {
    action.callback = None
  }
  self.after_present_actions = []
  let snapshot_observer = self.snapshot_observer
  self.snapshot_observer = None
  if snapshot_observer is Some(observer) {
    observer.scope.dispose()
  }
  let observer = self.frame_observer
  self.frame_observer = None
  if observer is Some(observer) {
    observer.scope.dispose()
  }
  let dispose = self.dispose_reactivity
  self.dispose_reactivity = fn() { () }
  ignore(self.pointer_cancel())
  self.clear_focus()
  dispose()
  self.lifetime.dispose()
  if wakeup is Some(wakeup) {
    wakeup()
  }
}

///|
pub fn UiRoot::view(self : UiRoot) -> @view.View {
  self.view
}

///|
pub fn UiRoot::dirty(self : UiRoot) -> DirtyState {
  self.dirty
}

///|
pub fn UiRoot::mark_layout_dirty(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  let was_clean = self.dirty == Clean
  self.dirty = NeedsLayout
  // Hit testing can populate the cache while a paint is still pending.
  self.layout_state.invalidate()
  self.request_popup_sync()
  self.notify_invalidation()
  if was_clean {
    self.wakeup_frame()
  }
}

///|
/// Invalidate text metrics and geometry after external font/scale resources
/// change. Normal text/font/width inputs select their own cache entries.
pub fn UiRoot::invalidate_text(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  self.layout_state.clear_text_cache()
  self.mark_layout_dirty()
}

///|
pub fn UiRoot::mark_paint_dirty(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  if self.dirty == Clean {
    self.dirty = NeedsPaint
    self.wakeup_frame()
  }
  self.notify_invalidation()
}

///|
pub fn UiRoot::paint(
  self : UiRoot,
  renderer : &@foundation.SceneRenderer,
  size~ : @foundation.Size,
  clear~ : @foundation.Color = @foundation.Color::transparent(),
) -> Unit {
  self.scope.run(fn() { self.paint_scoped(renderer, size~, clear~) })
}

///|
fn UiRoot::paint_scoped(
  self : UiRoot,
  renderer : &@foundation.SceneRenderer,
  size~ : @foundation.Size,
  clear~ : @foundation.Color,
) -> Unit {
  guard !self.disposed else { return }
  guard !self.painting &&
    !self.presenting &&
    !self.draining_actions &&
    !self.notifying_snapshot else {
    self.mark_paint_dirty()
    return
  }
  self.painting = true
  defer (fn() { self.painting = false })()
  self.viewport_size = Some(size)
  // Resolve keyboard focus visibility before drawing, including Tab before the
  // first host size was known. Scroll signal callbacks may change the tree.
  self.reveal_focus()
  ignore(self.captured_path())
  guard !self.disposed else { return }
  // Consume this request before drawing. Any invalidation during drawing belongs
  // to the next frame, including paint-only changes and observer callbacks.
  self.dirty = Clean
  let focused_path = self.focused_path()
  self.layout_state.paint(
    self.view,
    size~,
    renderer,
    focused_path~,
    clear~,
    pointer?=self.pointer_position,
    captured_node_id?=if self.captured_scrollbar {
      None
    } else {
      self.captured_node_id
    },
    keyboard_pressed_node_id?=self.keyboard_press.map(press => press.0),
  )
  self.hovered_node_id = self.layout_state.hovered_node_id()
  guard !self.disposed else { return }
  self.paint_count += 1
  self.last_paint_stats = self.layout_state.last_paint_stats()
  if self.pending_focus_reveal is Some(_) &&
    size.width > 0.0 &&
    size.height > 0.0 {
    self.mark_paint_dirty()
  }
  // Capture values before a frame observer can mutate the live application.
  let snapshot = if self.snapshot_observer is Some(observer) {
    self.snapshot_now().map(snapshot => (observer, snapshot))
  } else {
    None
  }
  if self.frame_observer is Some(observer) {
    self.notify_frame(observer, Painted(self.frame_stats()))
  }
  if snapshot is Some((observer, snapshot)) {
    self.notify_snapshot(observer, snapshot)
  }
}

///|
/// Activate the hit target directly, without producing pointer down/up events.
pub fn UiRoot::click_at(
  self : UiRoot,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed && !self.losing_focus else { false }
    self.viewport_size = Some(size)
    ignore(self.pointer_cancel())
    guard !self.disposed else { false }
    if self.dismiss_outside_popup(size, point) {
      return true
    }
    match self.layout_state.hit_test(self.view, size~, point~) {
      Some(target) => {
        if target.scrollbar {
          let handled = self.layout_state.click_at(self.view, size~, point~)
          if handled {
            self.mark_paint_dirty()
          }
          return handled
        }
        self.activate_target(target)
        true
      }
      None => {
        self.clear_focus()
        false
      }
    }
  })
}

///|
/// End the captured press. Activation requires release over the same live node.
pub fn UiRoot::pointer_up(
  self : UiRoot,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed else { false }
    self.viewport_size = Some(size)
    self.update_pointer(size, point)
    guard !self.disposed else { false }
    guard self.captured_node_id is Some(node_id) else { false }
    guard self.captured_path() is Some(path) else { false }
    // End capture before callbacks, which may remove the node or start a new press.
    let scrollbar = self.captured_scrollbar
    self.captured_node_id = None
    self.captured_scrollbar = false
    ignore(
      self.layout_state.pointer_up_path(
        self.view,
        size~,
        path,
        point~,
        scrollbar~,
      ),
    )
    self.mark_paint_dirty()
    if !scrollbar && !self.disposed && self.captured_node_id is None {
      if self.layout_state.hit_test(self.view, size~, point~) is Some(target) &&
        target.node_id == node_id &&
        !target.scrollbar {
        self.activate_target(target)
      }
    }
    true
  })
}

///|
fn UiRoot::activate_target(self : UiRoot, target : @view.HitTarget) -> Unit {
  guard !target.scrollbar else { return }
  if target.focusable {
    self.set_focus(target.node_id)
  } else {
    self.clear_focus()
  }
  // Focus callbacks can dispose the root or remove the target.
  if !self.disposed &&
    self.view.path_for_node_id(target.node_id) is Some(path) &&
    self.view.is_enabled_path(path) &&
    target.on_click is Some(action) {
    action()
  }
}

///|
pub fn UiRoot::pointer_down(
  self : UiRoot,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed && !self.losing_focus else { false }
    self.viewport_size = Some(size)
    ignore(self.pointer_cancel())
    guard !self.disposed else { false }
    if self.dismiss_outside_popup(size, point) {
      if !self.disposed {
        self.update_pointer(size, point)
      }
      return true
    }
    self.update_pointer(size, point)
    guard !self.disposed else { false }
    match self.layout_state.hit_test(self.view, size~, point~) {
      Some(target) => {
        self.captured_node_id = Some(target.node_id)
        self.captured_scrollbar = target.scrollbar
        if !target.scrollbar {
          if target.focusable {
            self.set_focus(target.node_id)
          } else {
            self.clear_focus()
          }
        }
        guard !self.disposed &&
          self.captured_node_id == Some(target.node_id) &&
          self.captured_path() is Some(path) else {
          false
        }
        guard self.layout_state.pointer_down_path(
          self.view,
          size~,
          path,
          point~,
          scrollbar=target.scrollbar,
        ) else {
          ignore(self.pointer_cancel())
          return false
        }
        self.mark_paint_dirty()
        true
      }
      None => {
        self.clear_focus()
        false
      }
    }
  })
}

///|
/// Update hover even without capture. The return value reports captured pointer
/// dispatch, so false does not imply that no paint was requested.
pub fn UiRoot::pointer_move(
  self : UiRoot,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed else { false }
    self.viewport_size = Some(size)
    self.update_pointer(size, point)
    guard !self.disposed else { false }
    match self.captured_path() {
      Some(path) => {
        ignore(
          self.layout_state.pointer_move_path(
            self.view,
            size~,
            path,
            point~,
            scrollbar=self.captured_scrollbar,
          ),
        )
        self.mark_paint_dirty()
        true
      }
      None => false
    }
  })
}

///|
/// Controls handle keys first. Unmodified navigation keys then scroll their
/// nearest eligible viewport. size overrides the last paint/input host size.
pub fn UiRoot::key_down(
  self : UiRoot,
  event : @foundation.KeyEvent,
  size? : @foundation.Size,
) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed && !self.losing_focus else { false }
    if size is Some(size) {
      self.viewport_size = Some(size)
    }
    self.sync_popups()
    match event.key {
      KeyTab if is_focus_traversal_event(event) => {
        let handled = if event.modifiers.shift {
          self.focus_previous()
        } else {
          self.focus_next()
        }
        self.reveal_focus()
        handled
      }
      _ => {
        if self.focused_path() is Some(path) {
          let target = self.focused_node_id
          match self.view.dispatch_key_down_path(path, event) {
            KeyActivated => {
              if !event.repeat &&
                (event.key == KeyEnter || event.key == KeySpace) &&
                self.focused_node_id == target &&
                self.focused_path() is Some(_) &&
                target is Some(node_id) {
                self.keyboard_press = Some((node_id, event.key))
              }
              self.mark_paint_dirty()
              return true
            }
            KeyHandled => return true
            KeyIgnored => ()
          }
          guard !self.disposed && !self.losing_focus else { return false }
          if self.focused_node_id == target &&
            self.focused_path() is Some(current) &&
            self.view.focus_group_key_target(current, event) is Some(next) {
            @reactive.during_update(fn() {
              self.set_focus(next.node_id, reveal=true)
              if !self.disposed &&
                self.focused_node_id == Some(next.node_id) &&
                self.view.path_for_node_id(next.node_id) is Some(path) &&
                self.view.is_enabled_path(path) &&
                next.on_click is Some(action) {
                action()
              }
              // A proposal handler can disable its target. Settle interaction
              // cleanup before the pending focus wakeup can paint that target.
              self.prune_disabled_interactions()
              self.reveal_focus()
            })
            return true
          }
          if event.key == KeyEscape {
            if self.dismiss_top_popup() {
              return true
            }
            self.focus_lost()
            return true
          }
        }
        if event.key == KeyEscape && self.dismiss_top_popup() {
          return true
        }
        guard !self.disposed && !self.losing_focus else { return false }
        ignore(self.focused_path())
        if self.viewport_size is Some(size) &&
          self.layout_state.scroll_key(
            self.view,
            self.focused_node_id,
            event,
            size~,
          ) {
          self.mark_paint_dirty()
          true
        } else {
          false
        }
      }
    }
  })
}

///|
fn is_focus_traversal_event(event : @foundation.KeyEvent) -> Bool {
  event.key == KeyTab &&
  !event.modifiers.control &&
  !event.modifiers.alt &&
  !event.modifiers.meta
}

///|
pub fn UiRoot::text_input(self : UiRoot, text : String) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed && !self.losing_focus else { false }
    match self.focused_path() {
      Some(path) => self.view.text_input_path(path, text)
      None => false
    }
  })
}

///|
pub fn UiRoot::copy_text(self : UiRoot) -> String? {
  self.scope.run(fn() {
    guard !self.disposed else { None }
    match self.focused_path() {
      Some(path) =>
        match self.view.text_edit_path(path, CopyText) {
          TextEditText(text) => Some(text)
          _ => None
        }
      None => None
    }
  })
}

///|
/// Propose a cut, then optionally write the accepted selection before deleting.
/// A rejected proposal never calls write. Returning false from write leaves the
/// text and selection intact. Without write, return the cut text to the caller.
pub fn UiRoot::cut_text(self : UiRoot, write? : (String) -> Bool) -> String? {
  self.scope.run(fn() {
    @environment.with_cut_writer(write, fn() {
      guard !self.disposed else { None }
      match self.focused_path() {
        Some(path) =>
          match self.view.text_edit_path(path, CutText) {
            TextEditText(text) => Some(text)
            _ => None
          }
        None => None
      }
    })
  })
}

///|
pub fn UiRoot::paste_text(self : UiRoot, text : String) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed else { false }
    match self.focused_path() {
      Some(path) =>
        match self.view.text_edit_path(path, PasteText(text)) {
          TextEditHandled | TextEditText(_) => true
          TextEditIgnored => false
        }
      None => false
    }
  })
}

///|
fn UiRoot::set_focus(
  self : UiRoot,
  node_id : Int32,
  reveal~ : Bool = false,
) -> Unit {
  guard !self.disposed && !self.losing_focus else { return }
  // The latest request wins, including one made synchronously from blur/focus.
  // A token avoids overwriting a nested focus without its matching blur.
  self.focus_request.val = true
  let superseded = Ref(false)
  self.focus_request = superseded
  guard self.focused_node_id != Some(node_id) else {
    if reveal {
      self.pending_focus_reveal = Some(node_id)
    }
    return
  }
  self.blur_focused_node()
  guard !superseded.val &&
    !self.disposed &&
    self.view.path_for_node_id(node_id) is Some(path) &&
    self.view.is_enabled_path(path) else {
    return
  }
  // Register focus before the callback so removal during on_focus can blur it.
  self.focused_node_id = Some(node_id)
  if !self.view.focus_path(path) && !superseded.val {
    self.focused_node_id = None
  }
  if reveal && !superseded.val && self.focused_node_id == Some(node_id) {
    self.pending_focus_reveal = Some(node_id)
  }
  self.mark_paint_dirty()
}

///|
fn UiRoot::clear_focus(self : UiRoot) -> Unit {
  self.focus_request.val = true
  self.blur_focused_node()
}

///|
fn UiRoot::blur_focused_node(self : UiRoot) -> Unit {
  self.pending_focus_reveal = None
  self.keyboard_press = None
  if self.focused_node_id is Some(node_id) {
    self.focused_node_id = None
    if self.view.path_for_node_id(node_id) is Some(path) {
      self.view.blur_path(path)
    }
    self.mark_paint_dirty()
  }
}

///|
fn UiRoot::focus_next(self : UiRoot) -> Bool {
  let paths = self.popup_tab_paths()
  if paths.is_empty() {
    self.clear_focus()
    false
  } else {
    let next = match self.focused_path() {
      Some(current) => next_focus_path(paths, current)
      None => paths[0]
    }
    match self.view.node_id_at_path(next) {
      Some(node_id) => self.set_focus(node_id, reveal=true)
      None => self.clear_focus()
    }
    true
  }
}

///|
fn UiRoot::focus_previous(self : UiRoot) -> Bool {
  let paths = self.popup_tab_paths()
  if paths.is_empty() {
    self.clear_focus()
    false
  } else {
    let previous = match self.focused_path() {
      Some(current) => previous_focus_path(paths, current)
      None => paths[paths.length() - 1]
    }
    match self.view.node_id_at_path(previous) {
      Some(node_id) => self.set_focus(node_id, reveal=true)
      None => self.clear_focus()
    }
    true
  }
}

///|
fn UiRoot::focused_path(self : UiRoot) -> Array[Int32]? {
  guard self.focused_node_id is Some(node_id) else { None }
  match self.view.path_for_node_id(node_id) {
    Some(path) if self.view.is_enabled_path(path) => Some(path)
    _ => {
      self.clear_focus()
      None
    }
  }
}

///|
fn UiRoot::captured_path(self : UiRoot) -> Array[Int32]? {
  guard self.captured_node_id is Some(node_id) else { None }
  match self.view.path_for_node_id(node_id) {
    Some(path) if self.view.is_enabled_path(path) => Some(path)
    _ => {
      ignore(self.pointer_cancel())
      None
    }
  }
}

///|
fn next_focus_path(
  paths : Array[Array[Int32]],
  current : Array[Int32],
) -> Array[Int32] {
  for index, path in paths {
    if same_path(path, current) {
      if index + 1 < paths.length() {
        return paths[index + 1]
      } else {
        return paths[0]
      }
    }
  }
  paths[0]
}

///|
fn previous_focus_path(
  paths : Array[Array[Int32]],
  current : Array[Int32],
) -> Array[Int32] {
  for index, path in paths {
    if same_path(path, current) {
      if index > 0 {
        return paths[index - 1]
      } else {
        return paths[paths.length() - 1]
      }
    }
  }
  paths[paths.length() - 1]
}

///|
fn same_path(left : Array[Int32], right : Array[Int32]) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    for index in 0..<left.length() {
      if left[index] != right[index] {
        return false
      }
    }
    true
  }
}

///|
/// Cancel capture without releasing or activating its target.
pub fn UiRoot::pointer_cancel(self : UiRoot) -> Bool {
  self.scope.run(fn() {
    self.layout_state.pointer_cancel()
    guard self.captured_node_id is Some(node_id) else { false }
    let scrollbar = self.captured_scrollbar
    self.captured_node_id = None
    self.captured_scrollbar = false
    if !scrollbar && self.view.path_for_node_id(node_id) is Some(path) {
      ignore(self.view.pointer_cancel_path(path))
    }
    self.mark_paint_dirty()
    true
  })
}

///|
/// Notify the root that its host window lost input focus.
pub fn UiRoot::focus_lost(self : UiRoot) -> Unit {
  self.scope.run(fn() {
    guard !self.disposed && !self.losing_focus else { return }
    self.losing_focus = true
    self.pointer_leave()
    ignore(self.pointer_cancel())
    self.clear_focus()
    self.losing_focus = false
  })
}

///|
fn UiRoot::update_pointer(
  self : UiRoot,
  size : @foundation.Size,
  point : @foundation.Point,
) -> Unit {
  self.pointer_position = Some(point)
  let hovered = match self.layout_state.hit_test(self.view, size~, point~) {
    Some(target) if !target.scrollbar => Some(target.node_id)
    _ => None
  }
  guard !self.disposed else { return }
  if hovered != self.hovered_node_id {
    self.hovered_node_id = hovered
    self.mark_paint_dirty()
  }
}

///|
/// Clear hover when the pointer leaves the host. Capture is retained so a drag
/// can return or release outside; call pointer_cancel to abandon the press.
pub fn UiRoot::pointer_leave(self : UiRoot) -> Unit {
  self.scope.run(fn() {
    guard !self.disposed else { return }
    self.pointer_position = None
    if self.hovered_node_id is Some(_) {
      self.hovered_node_id = None
      self.mark_paint_dirty()
    }
  })
}

///|
/// End the visual keyboard press. Activation keeps its existing key-down
/// semantics; releasing a key does not activate the control a second time.
pub fn UiRoot::key_up(self : UiRoot, event : @foundation.KeyEvent) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed else { false }
    guard self.keyboard_press is Some((_, key)) && key == event.key else {
      false
    }
    self.keyboard_press = None
    self.mark_paint_dirty()
    true
  })
}
