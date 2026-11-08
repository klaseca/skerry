///|
test "image intrinsic dimensions and one-axis constraints preserve aspect ratio" {
  let image = @foundation.Image(
    width=200,
    height=100,
    Bytes::new(200 * 100 * 4),
  )
  let layout = @view.column(
    [
      @view.image(image, style=@view.ImageStyle().width(100.0).shrink(0.0)),
      @view.image(image, style=@view.ImageStyle().height(30.0).shrink(0.0)),
      @view.image(image, style=@view.ImageStyle().max_width(80.0).shrink(0.0)),
      @view.image(
        image,
        style=@view.ImageStyle()
          .width(100.0)
          .padding(@foundation.Insets::all(10.0))
          .shrink(0.0),
      ),
      @view.image(image, style=@view.ImageStyle().max_height(40.0).shrink(0.0)),
      @view.image(image, style=@view.ImageStyle().min_height(120.0).shrink(0.0)),
    ],
    style=@view.FlexStyle().align_items(Start),
  ).layout(
    size=@foundation.Size(width=300.0, height=300.0),
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(
    (layout.children[0].width, layout.children[0].height),
    (100.0, 50.0),
  )
  assert_eq((layout.children[1].width, layout.children[1].height), (60.0, 30.0))
  assert_eq((layout.children[2].width, layout.children[2].height), (80.0, 40.0))
  assert_eq(
    (layout.children[3].width, layout.children[3].height),
    (100.0, 60.0),
  )
  assert_eq((layout.children[4].width, layout.children[4].height), (80.0, 40.0))
  assert_eq(
    (layout.children[5].width, layout.children[5].height),
    (240.0, 120.0),
  )
}

///|
test "image styles merge fields and participate in typed component rules" {
  let base = @view.ImageStyle().width(80.0).fit(Contain).align(TopLeft)
  let merged = base.merge(@view.ImageStyle().height(40.0).fit(Cover))
  assert_eq(merged.frame.layout.width, Some(80.0))
  assert_eq(merged.frame.layout.height, Some(40.0))
  assert_eq(merged.fit, Some(@foundation.Cover))
  assert_eq(merged.alignment, Some(@foundation.TopLeft))
  let declaration = @style.StyleDeclaration(merged)
  let restored : @view.ImageStyle = declaration.get().unwrap()
  assert_eq(restored, merged)
  assert_eq(declaration.metrics, @style.StyleMetrics())
}
