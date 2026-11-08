///|
test "App providers, mode, scheme and custom initial theme are available before content" {
  let label = @reactive.Context("default")
  let seen : Array[String] = []
  let initial_modes : Array[@runtime.ThemeMode] = []
  let initial_schemes : Array[@style.ColorScheme] = []
  let initial_themes : Array[@style.Theme] = []
  let runs = Ref(0)
  let bindings = [label.provide("app")]
  let dark_theme = @style.Theme(palette=@style.Palette::dark()).token(
    @style.accent_token,
    @foundation.Color::rgb(r=17, g=92, b=143),
  )
  let app = @runtime.App(providers=bindings, theme_mode=Dark, dark_theme~, content=fn() {
    seen.push(label.get())
    initial_themes.push(@environment.current_theme())
    initial_schemes.push(@environment.current_color_scheme())
    initial_modes.push(@runtime.current_app().theme_mode())
    ignore(
      @reactive.effect(fn() {
        ignore(@runtime.current_app().theme_mode())
        runs.val += 1
      }),
    )
    @controls.button("toggle", on_click=fn() {
      @runtime.current_app().set_theme_mode(Light)
    })
  })
  bindings.clear()
  let root = app.mount(text_layout_system=test_text_layout_system())
  defer root.dispose()
  assert_eq(seen, ["app"])
  assert_eq(initial_modes, [Dark])
  assert_eq(initial_schemes, [Dark])
  assert_eq(initial_themes, [dark_theme])
  assert_eq(runs.val, 1)
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  root.paint(renderer, size~)
  let before = root.frame_stats()
  assert_true(root.click_at(size~, point=Point(x=12.0, y=12.0)))
  assert_eq(app.theme_mode(), Light)
  assert_eq(root.theme(), Theme())
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, before.layout_count)
  assert_eq(runs.val, 2)
  assert_eq(label.get(), "default")
  root.dispose()
  app.set_theme_mode(Dark)
  assert_eq(root.theme(), Theme())
  assert_eq(runs.val, 2)
}

///|
test "nested context providers restore callback context and own callback-created effects" {
  let key = @reactive.Context("default")
  let source = @reactive.signal(0)
  let runs = Ref(0)
  let seen : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.row([
        @reactive.provide([key.provide("inner")], fn() {
          @controls.button(
            "inner",
            style=@controls.ButtonStyle().surface(
              @style.BoxStyle().width(100.0).height(40.0),
            ),
            on_click=fn() {
              seen.push(key.get())
              ignore(
                @reactive.effect(fn() {
                  ignore(source.get())
                  runs.val += 1
                }),
              )
            },
          )
        }),
        @controls.button(
          "outer",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(100.0).height(40.0),
          ),
          on_click=fn() { seen.push(key.get()) },
        ),
      ])
    },
    providers=[key.provide("outer")],
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=220.0, height=50.0)
  assert_true(root.click_at(size~, point=Point(x=12.0, y=12.0)))
  assert_true(root.click_at(size~, point=Point(x=112.0, y=12.0)))
  assert_eq(seen, ["inner", "outer"])
  source.set(1)
  assert_eq(runs.val, 2)
  root.dispose()
  source.set(2)
  assert_eq(runs.val, 2)
}

///|
test "component instances restore their own callback contexts" {
  let key = @reactive.Context("default")
  let seen : Array[String] = []
  let create = fn() {
    @controls.button("instance", on_click=fn() { seen.push(key.get()) })
  }
  let first = @runtime.mount(
    create,
    providers=[key.provide("first")],
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    providers=[key.provide("second")],
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  assert_true(second.click_at(size~, point=Point(x=12.0, y=12.0)))
  assert_true(first.click_at(size~, point=Point(x=12.0, y=12.0)))
  assert_eq(seen, ["second", "first"])
  first.dispose()
  assert_true(second.click_at(size~, point=Point(x=12.0, y=12.0)))
  assert_eq(seen, ["second", "first", "second"])
}

///|
test "mount binds retained and decorated handles to their instance context automatically" {
  let key = @reactive.Context("outside")
  let source = @reactive.signal(0)
  let runs = Ref(0)
  let seen : Array[String] = []
  // Construct before the host exists: the mount supplies the context to every
  // handle of this instance, including this original undecorated handle.
  let button = @controls.button("context", on_click=fn() {
    seen.push(key.get())
    ignore(
      @reactive.effect(fn() {
        ignore(source.get())
        runs.val += 1
      }),
    )
  })
  let decorated = button.debug(name="retained")
  let root = @runtime.mount(
    fn() { @view.column([decorated]) },
    providers=[key.provide("root")],
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(button.key_down_path([], test_key_event(KeyEnter)))
  assert_eq(seen, ["root"])
  assert_eq(key.get(), "outside")
  source.set(1)
  assert_eq(runs.val, 2)
  root.dispose()
  source.set(2)
  assert_eq(runs.val, 2)
}

///|
test "dynamic branch context and subscriptions end when the branch disappears" {
  let key = @reactive.Context("default")
  let visible = @reactive.signal(true)
  let source = @reactive.signal(0)
  let runs = Ref(0)
  let seen : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @reactive.provide([key.provide("branch")], fn() {
          @controls.button("branch", on_click=fn() {
            seen.push(key.get())
            ignore(
              @reactive.effect(fn() {
                ignore(source.get())
                runs.val += 1
              }),
            )
          })
        })
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=50.0)
  assert_true(root.click_at(size~, point=Point(x=12.0, y=12.0)))
  assert_eq(runs.val, 1)
  visible.set(false)
  source.set(1)
  assert_eq(runs.val, 1)
  visible.set(true)
  assert_true(root.click_at(size~, point=Point(x=12.0, y=12.0)))
  source.set(2)
  assert_eq(runs.val, 3)
  assert_eq(seen, ["branch", "branch"])
}
