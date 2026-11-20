///|
fn with_dummy_video(check : () -> Unit raise) -> Unit raise {
  let driver = @env.get_env_var("SDL_VIDEODRIVER")
  @env.set_env_var("SDL_VIDEODRIVER", "dummy")
  defer (fn() {
    match driver {
      Some(driver) => @env.set_env_var("SDL_VIDEODRIVER", driver)
      None => @env.unset_env_var("SDL_VIDEODRIVER")
    }
  })()
  check()
}

///|
suberror FrameFailure {
  FrameFailure
}

///|
struct FailingRenderer {
  delegate : &@backend.Renderer
  disposals : Ref[Int32]
}

///|
impl @backend.Renderer for FailingRenderer with fn surface(self) {
  self.delegate.surface()
}

///|
impl @backend.Renderer for FailingRenderer with fn text_layout_system(self) {
  self.delegate.text_layout_system()
}

///|
impl @backend.Renderer for FailingRenderer with fn render(_, _, _, _, _, _) {
  raise FrameFailure
}

///|
impl @backend.Renderer for FailingRenderer with fn dispose(self) {
  self.disposals.val += 1
  self.delegate.dispose()
}

///|
impl @backend.Renderer for FailingRenderer with fn name(self) {
  self.delegate.name()
}

///|
test "a frame error propagates without rerunning the renderer factory or mounting again" {
  with_dummy_video(fn() raise {
    let mounts = Ref(0)
    let factories = Ref(0)
    let disposals = Ref(0)
    let failed = try {
      run(
        @runtime.App(content=fn() {
          mounts.val += 1
          @view.empty()
        }),
        factory => {
          factories.val += 1
          let delegate = @skia_backend.raster_renderer(factory)
          FailingRenderer::{ delegate, disposals, }
        },
      )
      false
    } catch {
      FrameFailure => true
      _ => false
    }
    assert_true(failed)
    assert_eq(factories.val, 1)
    assert_eq(mounts.val, 1)
    assert_eq(disposals.val, 1)
  })
}
