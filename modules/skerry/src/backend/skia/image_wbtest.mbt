///|
#callsite(autofill(loc))
fn image_fixture_path(name : String, loc~ : SourceLoc) -> String raise {
  let filename = match @json.parse(loc.to_json_string()) {
    { "filename": String(filename), .. } => filename
    _ => abort("missing source path")
  }
  let parts = filename
    .split("\\")
    .map(part => part.to_owned())
    .collect()
    .join("/")
    .split("/")
    .map(part => part.to_owned())
    .collect()
  parts[:parts.length() - 1].to_owned().join("/") + "/fixtures/" + name
}

///|
test "PNG and JPEG decode into portable premultiplied pixels and file loading agrees" {
  let png = decode_image(
    @fs.read_file_to_bytes(image_fixture_path("colors.png")),
  )
  assert_eq((png.width, png.height), (2, 1))
  assert_eq(png.pixels(), b"\x00\x00\xff\xff\x80\x00\x00\x80")
  let loaded = load_image(image_fixture_path("colors.png"))
  assert_eq(loaded.pixels(), png.pixels())
  let jpeg = decode_image(
    @fs.read_file_to_bytes(image_fixture_path("solid.jpg")),
  )
  assert_eq((jpeg.width, jpeg.height), (8, 8))
  assert_true((jpeg.pixels()[0].to_int() - 140).abs() <= 4)
  assert_true((jpeg.pixels()[1].to_int() - 80).abs() <= 4)
  assert_true((jpeg.pixels()[2].to_int() - 30).abs() <= 4)
  assert_eq(jpeg.pixels()[3], 255)
  let loaded = load_image(image_fixture_path("solid.jpg"))
  assert_eq(loaded.pixels(), jpeg.pixels())
  assert_false(physical_equal(png, loaded))
}

///|
test "invalid image input and absent files report errors at resource initialization" {
  for data in [b"", b"not an image", b"\x89PNG\x0d\x0a"] {
    let rejected = try {
      ignore(decode_image(data))
      false
    } catch {
      @foundation.InvalidImageData => true
      _ => false
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(load_image(image_fixture_path("absent.png")))
    false
  } catch {
    @foundation.ImageFileReadFailed(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "native image paint respects contain cover and alpha over the cleared surface" {
  let image = load_image(image_fixture_path("colors.png"))
  let renderer = Renderer()
  defer renderer.dispose()
  let surface = @skia_lib.Surface(width=4, height=4)
  defer surface.dispose()
  let root = @runtime.mount(
    fn() { @view.image(image) },
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer root.dispose()
  renderer.draw(surface.canvas(), fn(scene) {
    root.paint(
      scene,
      size=Size(width=4.0, height=4.0),
      clear=@foundation.Color::white(),
    )
  })
  let data = surface.read_pixels().data
  for i in 0..<16 {
    assert_eq(data[i], 255)
  }
  assert_eq(data[16:20].to_owned(), b"\x00\x00\xff\xff")
  assert_eq(data[28:32].to_owned(), b"\xff\x7f\x7f\xff")
  let cover = @runtime.mount(
    fn() {
      @view.image(image, style=@view.ImageStyle().fit(Cover).align(CenterRight))
    },
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer cover.dispose()
  renderer.draw(surface.canvas(), fn(scene) {
    cover.paint(
      scene,
      size=Size(width=4.0, height=4.0),
      clear=@foundation.Color::white(),
    )
  })
  let data = surface.read_pixels().data
  assert_eq(data[12:16].to_owned(), b"\xff\x7f\x7f\xff")
}

///|
test "native image cache reuses uploads and releases resources absent from the next frame" {
  let image = load_image(image_fixture_path("colors.png"))
  let other = load_image(image_fixture_path("solid.jpg"))
  let renderer = Renderer()
  defer renderer.dispose()
  let surface = @skia_lib.Surface(width=4, height=4)
  defer surface.dispose()
  let frame = @foundation.Rect(x=0.0, y=0.0, width=4.0, height=4.0)
  for _ in 0..<3 {
    renderer.draw(surface.canvas(), fn(scene) {
      scene.draw_image(image, image.placement(frame).unwrap())
      scene.draw_image(image, image.placement(frame).unwrap())
    })
    assert_eq(renderer.images.length(), 1)
  }
  let native = renderer.images.get(image).unwrap().native
  renderer.draw(surface.canvas(), fn(scene) {
    scene.draw_image(image, image.placement(frame).unwrap())
  })
  assert_true(
    physical_equal(native, renderer.images.get(image).unwrap().native),
  )
  renderer.draw(surface.canvas(), fn(scene) {
    scene.draw_image(other, other.placement(frame).unwrap())
  })
  assert_eq(renderer.images.length(), 1)
  assert_true(renderer.images.get(image) is None)
  renderer.draw(surface.canvas(), fn(scene) {
    scene.clear(@foundation.Color::white())
  })
  assert_true(renderer.images.is_empty())
}

///|
test "removed and fully clipped image views do not retain native cache entries" {
  let first = load_image(image_fixture_path("colors.png"))
  let second = load_image(image_fixture_path("solid.jpg"))
  let visible = @reactive.signal(true)
  let offset = @reactive.signal(0.0)
  let renderer = Renderer()
  defer renderer.dispose()
  let surface = @skia_lib.Surface(width=40, height=40)
  defer surface.dispose()
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @view.scroll_view(
          @view.column(
            [
              @view.image(
                first,
                style=@view.ImageStyle().width(40.0).height(40.0).shrink(0.0),
              ),
              @view.image(
                second,
                style=@view.ImageStyle().width(40.0).height(40.0).shrink(0.0),
              ),
            ],
            style=@view.FlexStyle().spacing(2.0),
          ),
          offset~,
        )
      })
    },
    text_layout_system=@backend.Renderer::text_layout_system(renderer),
  )
  defer root.dispose()
  let draw = fn() raise {
    renderer.draw(surface.canvas(), fn(scene) {
      root.paint(scene, size=Size(width=40.0, height=40.0))
    })
  }
  draw()
  assert_eq(renderer.images.length(), 1)
  assert_true(renderer.images.get(first) is Some(_))
  assert_true(renderer.images.get(second) is None)
  offset.set(42.0)
  draw()
  assert_eq(renderer.images.length(), 1)
  assert_true(renderer.images.get(first) is None)
  assert_true(renderer.images.get(second) is Some(_))
  visible.set(false)
  draw()
  assert_true(renderer.images.is_empty())
}
