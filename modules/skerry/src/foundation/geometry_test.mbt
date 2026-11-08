///|
test "geometry constraints and hit testing" {
  let rect = @foundation.Rect(x=4.0, y=8.0, width=20.0, height=12.0)
  assert_true(rect.contains(Point(x=12.0, y=10.0)))
  assert_true(!rect.contains(Point(x=40.0, y=10.0)))
  let constraints = @foundation.Constraints::loose(
    Size(width=100.0, height=80.0),
  ).deflate(@foundation.Insets::all(10.0))
  inspect(constraints.max.width, content="80")
  inspect(constraints.max.height, content="60")
}

///|
test "clip intersection preserves offsets and treats touching edges as empty" {
  let viewport = @foundation.Rect(x=10.0, y=20.0, width=30.0, height=40.0)
  let overlapping = @foundation.Rect(x=25.0, y=5.0, width=30.0, height=40.0)
  assert_eq(
    viewport.intersect(overlapping),
    Rect(x=25.0, y=20.0, width=15.0, height=25.0),
  )
  assert_eq(overlapping.intersect(viewport), viewport.intersect(overlapping))
  assert_true(
    viewport.intersect(Rect(x=40.0, y=20.0, width=10.0, height=40.0)).is_empty(),
  )
  assert_true(
    viewport.intersect(Rect(x=11.0, y=21.0, width=0.0, height=10.0)).is_empty(),
  )
}
