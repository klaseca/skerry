///|
priv struct CachedImage {
  native : @skia_sys.Image
  mut used : Bool
}

///|
// Cache only resources used by the last frame. Rebuild on eviction so removed
// map storage cannot retain keys or native handles in unused slots.
fn Renderer::release_unused_images(self : Renderer) -> Unit {
  let mut stale = false
  for _, entry in self.images {
    if !entry.used {
      stale = true
      break
    }
  }
  if stale {
    let active : Map[@foundation.Image, CachedImage] = Map([])
    for image, entry in self.images {
      if entry.used {
        active[image] = entry
      }
    }
    self.images = active
  }
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn draw_image(
  self,
  image,
  placement,
) {
  guard !self.canvas.quick_reject(to_skia_rect(placement.destination)) else {
    return
  }
  let entry = match self.images.get(image) {
    Some(entry) => entry
    None => {
      let info = @skia_sys.imageinfo_bgra8888_premul(image.width, image.height)
      let native = @skia_sys.image_new_raster_copy(
        info,
        image.pixels(),
        image.row_bytes.to_uint64(),
      )
      guard !native.is_null() else {
        self.image_error.val = Some(
          ImageCreateFailed(width=image.width, height=image.height),
        )
        return
      }
      let entry = { native, used: true, }
      self.images[image] = entry
      entry
    }
  }
  entry.used = true
  self.paint.set_style(Fill)
  self.paint.set_color(@skia_lib.Color(a=255, r=255, g=255, b=255))
  self.canvas.draw_image(
    entry.native,
    to_skia_rect(placement.source),
    to_skia_rect(placement.destination),
    self.paint,
  )
}
