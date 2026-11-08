///|
/// A shared image in BGRA8888 premultiplied format, independent of a renderer.
/// Immutable pixel data is shared; construction does not copy it.
pub struct Image {
  priv identity : Int32
  priv pixels : Bytes
  width : Int32
  height : Int32
  row_bytes : Int32
}

///|
// Used only for hashing. Wrapping is harmless: equality uses object identity.
let next_image_identity : Ref[Int32] = Ref(0)

///|
pub fn Image::Image(
  width~ : Int32,
  height~ : Int32,
  pixels : Bytes,
) -> Image raise ImageError {
  if width <= 0 || height <= 0 || width > @int.MAX_VALUE / 4 {
    raise InvalidImageSize(width~, height~)
  }
  let row_bytes = width * 4
  if height > @int.MAX_VALUE / row_bytes ||
    pixels.length() != row_bytes * height {
    raise InvalidImageSize(width~, height~)
  }
  let identity = next_image_identity.val
  next_image_identity.val += 1
  { identity, pixels, width, height, row_bytes, }
}

///|
/// Immutable pixel storage for custom renderer uploads.
pub fn Image::pixels(self : Image) -> Bytes {
  self.pixels
}

///|
pub fn Image::size(self : Image) -> Size {
  Size(width=self.width.to_double(), height=self.height.to_double())
}

///|
pub impl Eq for Image with fn equal(self, other) {
  physical_equal(self, other)
}

///|
pub impl Hash for Image with fn hash_combine(self, hasher) {
  hasher.combine(self.identity)
}

///|
pub impl Debug for Image with fn to_repr(self) {
  @debug.Repr("Image(\{self.width}x\{self.height})")
}

///|
pub extend Image with Eq::{equal, not_equal}

///|
pub extend Image with Hash::{hash, hash_combine}

///|
pub extend Image with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum ImageFit {
  Contain
  Cover
  Fill
}

///|
pub extend ImageFit with Eq::{equal, not_equal}

///|
pub extend ImageFit with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum ImageAlignment {
  TopLeft
  TopCenter
  TopRight
  CenterLeft
  Center
  CenterRight
  BottomLeft
  BottomCenter
  BottomRight
}

///|
pub extend ImageAlignment with Eq::{equal, not_equal}

///|
pub extend ImageAlignment with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct ImagePlacement {
  source : Rect
  destination : Rect
}

///|
pub extend ImagePlacement with Eq::{equal, not_equal}

///|
pub extend ImagePlacement with Debug::{to_repr}

///|
/// Resolve scaling and cropping in one place for paint and diagnostics.
pub fn Image::placement(
  self : Image,
  frame : Rect,
  fit~ : ImageFit = Contain,
  alignment~ : ImageAlignment = Center,
) -> ImagePlacement? {
  guard !frame.is_empty() else { return None }
  let width = self.width.to_double()
  let height = self.height.to_double()
  let x = match alignment {
    TopLeft | CenterLeft | BottomLeft => 0.0
    TopCenter | Center | BottomCenter => 0.5
    TopRight | CenterRight | BottomRight => 1.0
  }
  let y = match alignment {
    TopLeft | TopCenter | TopRight => 0.0
    CenterLeft | Center | CenterRight => 0.5
    BottomLeft | BottomCenter | BottomRight => 1.0
  }
  match fit {
    Fill =>
      Some({ source: Rect(x=0.0, y=0.0, width~, height~), destination: frame, })
    Contain => {
      let scale = (frame.size.width / width).min(frame.size.height / height)
      let drawn_width = width * scale
      let drawn_height = height * scale
      Some({
        source: Rect(x=0.0, y=0.0, width~, height~),
        destination: Rect(
          x=frame.origin.x + (frame.size.width - drawn_width) * x,
          y=frame.origin.y + (frame.size.height - drawn_height) * y,
          width=drawn_width,
          height=drawn_height,
        ),
      })
    }
    Cover => {
      let scale = (frame.size.width / width).max(frame.size.height / height)
      let cropped_width = frame.size.width / scale
      let cropped_height = frame.size.height / scale
      Some({
        source: Rect(
          x=(width - cropped_width) * x,
          y=(height - cropped_height) * y,
          width=cropped_width,
          height=cropped_height,
        ),
        destination: frame,
      })
    }
  }
}

///|
#derive(Eq, Debug)
pub(all) suberror ImageError {
  InvalidImageSize(width~ : Int32, height~ : Int32)
  InvalidImageData
  ImageFileReadFailed(String)
}

///|
pub extend ImageError with Eq::{equal, not_equal}

///|
pub extend ImageError with Debug::{to_repr}
