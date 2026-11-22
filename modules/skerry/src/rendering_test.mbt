///|
test "default run records the rendering path at mount and in snapshots" {
  let driver = @env.get_env_var("SDL_VIDEODRIVER")
  @env.set_env_var("SDL_VIDEODRIVER", "dummy")
  defer (fn() {
    match driver {
      Some(driver) => @env.set_env_var("SDL_VIDEODRIVER", driver)
      None => @env.unset_env_var("SDL_VIDEODRIVER")
    }
  })()
  let info : Ref[@skerry.RenderingInfo?] = Ref(None)
  let snapshot_info : Ref[@skerry.RenderingInfo?] = Ref(None)
  @skerry.run(
    @skerry.App(width=80, height=60, content=@skerry.empty, on_mount=fn(root) {
      info.val = root.rendering_info()
      ignore(
        root.observe_snapshots(snapshot => {
          snapshot_info.val = snapshot.rendering
        }),
      )
      ignore(root.after_present(fn() { root.dispose() }))
    }),
  )
  assert_eq(info.val, Some({ backend: "SDL", renderer: "Skia/CPU", }))
  assert_eq(snapshot_info.val, info.val)
}

///|
test "explicit backend and renderer factory are used exactly once" {
  let backends = Ref(0)
  let renderers = Ref(0)
  let mounts = Ref(0)
  @skerry.run(
    @skerry.App(content=fn() {
      mounts.val += 1
      @skerry.box(
        style=@skerry.BoxStyle()
          .width(80.0)
          .height(60.0)
          .background(@skerry.Color::rgb(r=255, g=0, b=0)),
      )
    }),
    backend=(app, create_renderer) => {
      backends.val += 1
      let surface = MemorySurface::{
        pixels: Bytes::make(80 * 60 * 4, b'\x00'),
      }
      let factory = MemoryFactory::{ surface, }
      let renderer = create_renderer(factory)
      defer renderer.dispose()
      let root = app.mount(text_layout_system=renderer.text_layout_system())
      defer root.dispose()
      renderer.render(root, 80, 60, 1.0, @skerry.Color::white())
      renderer.surface().present(80, 60)
      assert_eq(surface.pixels[:4], b"\x00\x00\xff\xff")
      assert_eq(renderer.name(), "Skia/CPU")
    },
    renderer=factory => {
      renderers.val += 1
      @skia_backend.raster_renderer(factory)
    },
  )
  assert_eq(backends.val, 1)
  assert_eq(renderers.val, 1)
  assert_eq(mounts.val, 1)
}

///|
test "renderer selection tries candidates in order until one initializes" {
  let attempts = []
  let create_renderer = @skerry.renderers(
    preferred=[
      factory => {
        attempts.push("OpenGL")
        @skia_backend.opengl_renderer(factory)
      },
      factory => {
        attempts.push("CPU")
        @skia_backend.raster_renderer(factory)
      },
      factory => {
        attempts.push("extra candidate")
        @skia_backend.raster_renderer(factory)
      },
    ],
    fallback=factory => {
      attempts.push("fallback")
      @skia_backend.raster_renderer(factory)
    },
  )
  let renderer = create_renderer(MemoryFactory::{
    surface: { pixels: Bytes::make(80 * 60 * 4, b'\x00'), },
  })
  defer renderer.dispose()
  assert_eq(attempts, ["OpenGL", "CPU"])
  assert_eq(renderer.name(), "Skia/CPU")
}

///|
#cfg(platform="windows")
test "the Windows renderer list takes precedence and falls back to CPU" {
  let attempts = []
  let create_renderer = @skerry.renderers(
    preferred=[
      factory => {
        attempts.push("shared")
        @skia_backend.raster_renderer(factory)
      },
    ],
    windows=[
      factory => {
        attempts.push("D3D12")
        @skia_backend.d3d12_renderer(factory)
      },
    ],
  )
  let renderer = create_renderer(MemoryFactory::{
    surface: { pixels: Bytes::make(80 * 60 * 4, b'\x00'), },
  })
  defer renderer.dispose()
  assert_eq(attempts, ["D3D12"])
  assert_eq(renderer.name(), "Skia/CPU")
}

///|
// This backend has no SDL dependency or native window. The same Skia renderer
// negotiates its raster target through the common protocol.
struct MemorySurface {
  pixels : Bytes
}

///|
struct MemoryFactory {
  surface : MemorySurface
}

///|
impl @backend.SurfaceFactory for MemoryFactory with fn raster(self) {
  self.surface
}

///|
impl @backend.Surface for MemorySurface with fn output_size(_) {
  { width: 80, height: 60, }
}

///|
impl @backend.Surface for MemorySurface with fn resize(_, _, _, _) {
  false
}

///|
impl @backend.Surface for MemorySurface with fn present(_, _, _) {
  ()
}

///|
impl @backend.Surface for MemorySurface with fn restore(_, _, _) {
  true
}

///|
impl @backend.RasterSurface for MemorySurface with fn with_pixels(
  self,
  width,
  height,
  scale,
  draw,
) {
  draw(
    @backend.RasterTarget(
      memory=memory_pointer(self.pixels),
      width~,
      height~,
      row_bytes=80 * 4,
      format=Bgra8888Premultiplied,
      scale~,
    ),
  )
}

///|
fn memory_pointer(bytes : Bytes) -> @backend.RasterMemory = "%identity"
