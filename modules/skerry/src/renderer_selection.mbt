///|
// Each build constructs only the variant selected by #cfg.
#warnings("-unused_constructor")
priv enum RendererPlatform {
  Windows
  MacOS
  Linux
  Other
}

///|
#cfg(platform="windows")
let renderer_platform : RendererPlatform = Windows

///|
#cfg(platform="macos")
let renderer_platform : RendererPlatform = MacOS

///|
#cfg(platform="linux")
let renderer_platform : RendererPlatform = Linux

///|
#cfg(not(any(platform="windows", platform="macos", platform="linux")))
let renderer_platform : RendererPlatform = Other

///|
/// Tries renderer factories in order until one initializes successfully.
/// The current platform's list takes precedence over `preferred`, even when
/// empty. If every candidate fails, tries `fallback` and propagates its error.
pub fn renderers(
  preferred~ : ArrayView[@backend.RendererFactory] = [],
  windows? : ArrayView[@backend.RendererFactory],
  macos? : ArrayView[@backend.RendererFactory],
  linux? : ArrayView[@backend.RendererFactory],
  fallback~ : @backend.RendererFactory = @skia_backend.raster_renderer,
) -> @backend.RendererFactory {
  let candidates = match renderer_platform {
    Windows => windows.unwrap_or(preferred)
    MacOS => macos.unwrap_or(preferred)
    Linux => linux.unwrap_or(preferred)
    Other => preferred
  }
  factory => {
    for candidate in candidates {
      let renderer = candidate(factory) catch { _ => continue }
      return renderer
    }
    fallback(factory)
  }
}
