///|
// Constructed by the native stub. Values match skerry_platform there.
priv enum RendererPlatform {
  Other = 0
  Windows = 1
  MacOS = 2
  Linux = 3
}

///|
extern "c" fn renderer_platform() -> RendererPlatform = "moonbit_skerry_renderer_platform"

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
  let candidates = match renderer_platform() {
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
