///|
priv struct SelectSession {
  scope : @reactive.Scope
  mut entries : Array[@view.View]
  mut labels : Array[@view.TextContent]
  mut host : @view.MountContext?
  mut active : Int32?
  mut prefix : String
  mut last_input : Double
}

///|
fn SelectSession::enabled(self : SelectSession, index : Int32) -> Bool {
  !self.scope.is_disposed() && self.entries[index].is_enabled_path([])
}

///|
fn SelectSession::focus(self : SelectSession, index : Int32) -> Unit {
  if self.enabled(index) &&
    self.host is Some(host) &&
    self.entries[index].node_id_at_path([]) is Some(id) {
    ignore(host.request_focus(id))
  }
}

///|
fn SelectSession::edge(self : SelectSession, last~ : Bool = false) -> Int32? {
  if last {
    for index in (self.entries.length() - 1)>=..0 {
      if self.enabled(index) {
        return Some(index)
      }
    }
  } else {
    for index in 0..<self.entries.length() {
      if self.enabled(index) {
        return Some(index)
      }
    }
  }
  None
}

///|
fn SelectSession::step(self : SelectSession, forward : Bool) -> Unit {
  let count = self.entries.length()
  guard count > 0 else { return }
  let start = self.active.unwrap_or(if forward { count - 1 } else { 0 })
  for step in 1..<=count {
    let index = if forward {
      (start + step) % count
    } else {
      (start - step + count) % count
    }
    if self.enabled(index) {
      self.focus(index)
      return
    }
  }
}

///|
fn SelectSession::find(
  self : SelectSession,
  prefix : String,
  start : Int32,
) -> Int32? {
  let count = self.entries.length()
  for step in 0..<count {
    let index = (start + step) % count
    if self.enabled(index) &&
      self.labels[index].get().to_lower().has_prefix(prefix) {
      return Some(index)
    }
  }
  None
}

///|
fn SelectSession::search(self : SelectSession, text : String) -> Bool {
  guard !text.is_empty() && !self.scope.is_disposed() else { return false }
  let now = self.host.map(host => host.now()).unwrap_or(0.0)
  let text = text.to_lower()
  let previous = if now - self.last_input <= 700.0 { self.prefix } else { "" }
  self.last_input = now
  let repeated = previous == text
  let prefix = if repeated { text } else { previous + text }
  let start = self.active.unwrap_or(-1)
  let next = self.find(
    prefix,
    if previous.is_empty() || repeated {
      start + 1
    } else {
      start.max(0)
    },
  )
  self.prefix = prefix
  if next is Some(index) {
    self.focus(index)
  } else if self.find(text, start + 1) is Some(index) {
    self.prefix = text
    self.focus(index)
  } else {
    // An unmatched prefix cannot become a match by appending more text.
    self.prefix = ""
  }
  true
}

///|
fn[T : Eq] select_list(
  state : SelectState[T],
  style : SelectStyle,
  on_change : ((@foundation.ChangeEvent[T?]) -> Unit)?,
  close : () -> Unit,
) -> @view.View {
  let session : SelectSession = {
    scope: @reactive.Scope::current().unwrap(),
    entries: [],
    labels: [],
    host: None,
    active: None,
    prefix: "",
    last_input: 0.0,
  }
  @reactive.on_cleanup(fn() {
    // Entries capture this session in their handlers. Drop the session's side
    // of that cycle after unmount, including cached TextContent handles.
    session.host = None
    session.entries = []
    session.labels = []
  })
  for index, option in state.options {
    let value = option.value
    let content = @view.TextContent(option.label)
    session.labels.push(content)
    let option_style = style
      .select(fn(s) {
        if state.selected.get() == Some(value) {
          s.option.merge(s.selected)
        } else {
          s.option
        }
      })
      .merge(ButtonStyle().surface(@style.BoxStyle().shrink(0.0)))
    let commit = fn() {
      guard session.enabled(index) else { return }
      if state.pending is Some(old) {
        old.val = true
      }
      let superseded = Ref(false)
      state.pending = Some(superseded)
      let before = state.selected.peek()
      if before == Some(value) {
        close()
      } else {
        ignore(
          @view.dispatch_change(
            content.id,
            Some(value),
            on_change,
            fn() {
              state.selected.set(Some(value))
              close()
            },
            is_current=fn() {
              !superseded.val &&
              session.enabled(index) &&
              state.selected.peek() == before
            },
          ),
        )
      }
    }
    let entry = @view.element(
      component_name="SelectOption",
      style=option_style,
      padding=@foundation.Insets::symmetric(horizontal=12.0, vertical=8.0),
      measure=fn(context) {
        select_measure(content.get(), context.font, context.text_layout_system)
      },
      painter=select_option_painter(content, fn() {
        state.selected.peek() == Some(value)
      }),
      events=@view.ElementEvents(
        focusable=true,
        editable=true,
        disabled=option.disabled,
        on_focus=fn() { session.active = Some(index) },
        on_click=commit,
        handle_text_input=fn(text) { session.search(text) },
        handle_key_down=fn(event) {
          guard select_navigation_event(event) else { return KeyIgnored }
          match event.key {
            KeyArrowDown | KeyArrowUp => {
              session.prefix = ""
              session.step(event.key == KeyArrowDown)
              KeyHandled
            }
            KeyHome | KeyEnd => {
              session.prefix = ""
              if session.edge(last=event.key == KeyEnd) is Some(target) {
                session.focus(target)
              }
              KeyHandled
            }
            KeyArrowLeft | KeyArrowRight => KeyHandled
            KeyEnter | KeySpace => {
              if !event.repeat {
                commit()
              }
              KeyHandled
            }
            _ => KeyIgnored
          }
        },
      ),
      reactivity=@view.Reactivity(mount=fn(host) {
        session.host = Some(host)
        fn() { session.host = None }
      }).with_text(content),
    )
    session.entries.push(entry)
  }
  let list = @view.column(
    session.entries,
    style=@view.FlexStyle()
      .spacing(0.0)
      .justify_content(Start)
      .align_items(Stretch),
  ).focus_group(fn() {
    if session.active is Some(index) && session.enabled(index) {
      return session.entries[index].node_id_at_path([])
    }
    let preferred = match state.opening {
      Search(text) => {
        let prefix = text.to_lower()
        session.last_input = session.host.map(host => host.now()).unwrap_or(0.0)
        let target = session.find(prefix, 0)
        session.prefix = if target is Some(_) { prefix } else { "" }
        target
      }
      First => session.edge()
      Last => session.edge(last=true)
      Current => {
        let current = state.selected.peek()
        for index, option in state.options {
          if current == Some(option.value) && session.enabled(index) {
            break Some(index)
          }
        } nobreak {
          None
        }
      }
    }
    let preferred = match preferred {
      Some(_) => preferred
      None => session.edge(last=state.opening is Last)
    }
    state.opening = Current
    preferred.bind(index => session.entries[index].node_id_at_path([]))
  })
  let list_style = @style.BoxStyle()
    .padding(@foundation.Insets::all(4.0))
    .merge(style.select(s => s.list))
  @view.scroll_view(list, style=list_style, scrollbar_gutter=true).component(
    "SelectList",
  )
}
