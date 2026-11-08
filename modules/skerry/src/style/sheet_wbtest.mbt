///|
test "typed lookups reuse immutable arrays and separate concrete families" {
  let rules = Styles().add(BoxStyle().width(10.0))
  let first : ReadOnlyArray[BoxStyle] = rules.get()
  let second : ReadOnlyArray[BoxStyle] = rules.get()
  assert_true(physical_equal(first, second))
  assert_eq(first[0].layout.width, Some(10.0))
  let fonts : ReadOnlyArray[@foundation.FontSpec] = rules.get()
  assert_eq(fonts.length(), 0)
  let again : ReadOnlyArray[BoxStyle] = rules.get()
  assert_true(physical_equal(first, again))
}
