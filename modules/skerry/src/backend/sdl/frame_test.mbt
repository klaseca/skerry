///|
struct FrameRenderer {
  renderer : &@backend.Renderer
  frames : Ref[Int32]
  root : Ref[@runtime.UiRoot?]
}

///|
impl @backend.Renderer for FrameRenderer with fn text_layout_system(self) {
  self.renderer.text_layout_system()
}

///|
impl @backend.Renderer for FrameRenderer with fn render(
  self,
  root,
  target,
  clear,
) {
  self.root.val = Some(root)
  self.renderer.render(root, target, clear)
  self.frames.val += 1
  // A lost request fails the assertions after run instead of blocking the test.
  if self.frames.val >= 2 ||
    (!root.needs_frame() && root.next_action_delay() is None) {
    root.dispose()
  }
}

///|
fn with_frame_app(
  content : () -> @view.View,
  on_mount~ : (@runtime.UiRoot) -> Unit = fn(_) { () },
) -> @runtime.FrameStats raise {
  let driver = @env.get_env_var("SDL_VIDEODRIVER")
  @env.set_env_var("SDL_VIDEODRIVER", "dummy")
  defer (fn() {
    match driver {
      Some(driver) => @env.set_env_var("SDL_VIDEODRIVER", driver)
      None => @env.unset_env_var("SDL_VIDEODRIVER")
    }
  })()
  let frames = Ref(0)
  let root : Ref[@runtime.UiRoot?] = Ref(None)
  @skia_backend.with_renderer(renderer => {
    @sdl.run(
      App(title="Frame loop test", width=160, height=80, content~, on_mount~),
      FrameRenderer::{ renderer, frames, root, },
    )
  })
  assert_eq(frames.val, 2)
  let root = root.val.unwrap()
  assert_true(root.is_disposed())
  assert_false(root.needs_frame())
  root.frame_stats()
}

///|
test "SDL drains actions posted during paint before the following coalesced frame" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let value = @reactive.signal("first")
  let first = Ref(true)
  let stats = with_frame_app(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if first.val {
              first.val = false
              let root = root_ref.val.unwrap()
              ignore(root.post(fn() { value.set("second") }))
              ignore(root.post(fn() { value.set("third") }))
            }
          }),
        ),
        @view.text_of(value),
      ])
    },
    on_mount=fn(root) { root_ref.val = Some(root) },
  )
  assert_eq(value.get(), "third")
  assert_eq(stats.layout_count, 2)
  assert_eq(stats.paint_count, 2)
}

///|
test "SDL run presents once then wakes at a timer deadline without input" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let value = @reactive.signal("first")
  let first = Ref(true)
  let presented = Ref(0)
  let stats = with_frame_app(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if first.val {
              first.val = false
              let root = root_ref.val.unwrap()
              ignore(
                root.after_present(fn() {
                  presented.val = root.frame_stats().present_count
                }),
              )
              ignore(root.post_delayed(5, fn() { value.set("second") }))
            }
          }),
        ),
        @view.text_of(value),
      ])
    },
    on_mount=fn(root) { root_ref.val = Some(root) },
  )
  assert_eq(presented.val, 1)
  assert_eq(value.get(), "second")
  assert_eq(stats.layout_count, 2)
  assert_eq(stats.paint_count, 2)
}

///|
test "SDL run renders an update requested during paint and stops on root disposal" {
  let checked = @reactive.signal(false)
  let first = Ref(true)
  let stats = with_frame_app(fn() {
    @view.column([
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          if first.val {
            first.val = false
            checked.set(true)
          }
        }),
      ),
      @controls.checkbox(checked~),
    ])
  })
  assert_eq(stats.layout_count, 1)
  assert_eq(stats.paint_count, 2)
  assert_eq(stats.present_count, 1)
  assert_eq(stats.presented_frame, 1)
}

///|
test "SDL run coalesces updates during paint into one following layout frame" {
  let value = @reactive.signal("first")
  let first = Ref(true)
  let stats = with_frame_app(fn() {
    @view.column([
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          if first.val {
            first.val = false
            value.set("second")
            value.set("third")
          }
        }),
      ),
      @view.text_of(value),
    ])
  })
  assert_eq(stats.layout_count, 2)
  assert_eq(stats.paint_count, 2)
  assert_eq(stats.present_count, 1)
  assert_eq(stats.presented_frame, 1)
}
