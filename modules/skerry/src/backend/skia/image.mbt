///|
/// Decode once into a renderer-independent shared pixel image.
pub fn decode_image(
  bytes : Bytes,
) -> @foundation.Image raise @foundation.ImageError {
  let data = @skia_sys.data_new_with_copy(bytes, bytes.length().to_uint64())
  guard !data.is_null() else { raise @foundation.InvalidImageData }
  decode_image_data(data)
}

///|
/// Load and decode synchronously. Call during resource initialization, not paint.
pub fn load_image(
  path : String,
) -> @foundation.Image raise @foundation.ImageError {
  guard !path.contains("\u0000") else {
    raise @foundation.ImageFileReadFailed(path)
  }
  let data = @skia_sys.data_new_from_file(@utf8.encode(path + "\u0000"))
  guard !data.is_null() else { raise @foundation.ImageFileReadFailed(path) }
  decode_image_data(data)
}

///|
// DISALLOW_SK_IMAGE_CACHING_HINT from sk_types.h. The decoded pixels live in
// the portable Image; retaining a second decoded copy in Skia is unnecessary.
let disallow_image_caching : Int32 = 1

///|
fn decode_image_data(
  data : @skia_sys.Data,
) -> @foundation.Image raise @foundation.ImageError {
  let image = @skia_sys.image_new_from_encoded(data)
  guard !image.is_null() else { raise @foundation.InvalidImageData }
  let width = @skia_sys.image_get_width(image)
  let height = @skia_sys.image_get_height(image)
  guard width > 0 && height > 0 && width <= @int.MAX_VALUE / 4 else {
    raise @foundation.InvalidImageSize(width~, height~)
  }
  let row_bytes = width * 4
  guard height <= @int.MAX_VALUE / row_bytes else {
    raise @foundation.InvalidImageSize(width~, height~)
  }
  let pixels = Bytes::new(row_bytes * height)
  let info = @skia_sys.imageinfo_bgra8888_premul(width, height)
  guard @skia_sys.image_read_pixels(
    image,
    info,
    pixels,
    row_bytes.to_uint64(),
    0,
    0,
    disallow_image_caching,
  ) else {
    raise @foundation.InvalidImageData
  }
  @foundation.Image(width~, height~, pixels)
}
