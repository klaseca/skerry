///|
struct ThemeRecordingRenderer {
  delegate : &@backend.Renderer
  clears : Array[@foundation.Color]
}

///|
impl @backend.Renderer for ThemeRecordingRenderer with fn text_layout_system(
  self,
) {
  self.delegate.text_layout_system()
}

///|
impl @backend.Renderer for ThemeRecordingRenderer with fn render(
  self,
  root,
  target,
  clear,
) {
  self.clears.push(clear)
  self.delegate.render(root, target, clear)
}

///|
test "SDL clear follows the root palette unless explicitly overridden and returns to idle" {
  let dark = @style.Theme(palette=@style.Palette::dark())
  for explicit in [false, true] {
    let clears : Array[@foundation.Color] = []
    with_render_state(
      fn(_) { @view.empty() },
      (state, _) => {
        state.sync_frame()
        assert_eq(clears, [
          if explicit {
            @foundation.Color::white()
          } else {
            @foundation.Color::surface()
          },
        ])
        state.root.set_theme(dark)
        assert_false(state.prepare_wait())
        state.sync_frame()
        assert_eq(clears.length(), 2)
        assert_eq(
          clears[1],
          if explicit {
            @foundation.Color::white()
          } else {
            dark.resolve(@style.surface_token)
          },
        )
        assert_eq(state.root.frame_stats().layout_count, 1)
        assert_eq(state.root.snapshot().unwrap().theme, dark)
        assert_true(state.prepare_wait())
        state.root.set_theme(dark)
        state.sync_frame()
        assert_eq(clears.length(), 2)
        assert_true(state.prepare_wait())
        let surface = @foundation.Color::rgb(r=40, g=100, b=70)
        state.root.set_theme(dark.token(@style.surface_token, surface))
        state.sync_frame()
        assert_eq(clears.length(), 3)
        assert_eq(
          clears[2],
          if explicit {
            @foundation.Color::white()
          } else {
            surface
          },
        )
        assert_eq(state.root.frame_stats().layout_count, 1)
        assert_true(state.prepare_wait())
      },
      clear=if explicit { Some(@foundation.Color::white()) } else { None },
      observed_clears=clears,
    )
  }
}

///|
test "SDL system theme events update System apps without window input geometry" {
  with_render_state(fn(_) { @view.empty() }, (state, _) => {
    let reported = system_theme()
    let app = @runtime.App(content=@view.empty)
    let root = app.mount(
      text_layout_system=state.renderer.text_layout_system(),
      system_theme=if reported is Some(Dark) { Light } else { Dark },
    )
    defer root.dispose()
    let before = root.theme()
    let queries = Ref(0)
    let get_geometry : () -> InputGeometry raise = fn() {
      queries.val += 1
      {
        window_size: @foundation.Size::zero(),
        logical_size: @foundation.Size::zero(),
      }
    }
    let event = @sdl_sys.Event()
    event.set_event_type(@sdl_sys.EVENT_SYSTEM_THEME_CHANGED)
    let dispatcher = EventDispatcher(root, window_id=999, geometry=get_geometry)
    assert_true(dispatcher.dispatch(event))
    let expected = if reported is Some(Dark) {
      @style.Theme(palette=@style.Palette::dark())
    } else {
      Theme()
    }
    assert_eq(root.theme(), expected)
    assert_true(root.theme() != before)
    assert_eq(app.theme_mode(), System)
    assert_eq(queries.val, 0)
    app.set_theme_mode(Dark)
    assert_true(dispatcher.dispatch(event))
    assert_eq(
      root.theme().tokens,
      @style.Theme(palette=@style.Palette::dark()).tokens,
    )
    root.dispose()
    assert_true(dispatcher.dispatch(event))
    assert_eq(
      root.theme().tokens,
      @style.Theme(palette=@style.Palette::dark()).tokens,
    )
  })
}
