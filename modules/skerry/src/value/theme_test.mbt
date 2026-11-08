///|
fn theme_source(value : &@value.ThemeSource) -> @reactive.Binding[@style.Theme] {
  value.to_binding()
}

///|
test "theme source conversion preserves constants and does not evaluate reactive producers" {
  let initial = @style.Theme()
  assert_eq(theme_source(initial).constant_value(), Some(initial))
  assert_eq(
    theme_source(@reactive.val(initial)).constant_value(),
    Some(initial),
  )
  let value = @reactive.signal(initial)
  let reads = Ref(0)
  let source = theme_source(
    @reactive.computed(fn() {
      reads.val += 1
      value.get()
    }),
  )
  assert_eq(source.constant_value(), None)
  assert_eq(reads.val, 0)
  let signal_source = theme_source(value)
  assert_eq(signal_source.get(), initial)
  assert_eq(source.get(), initial)
  assert_eq(source.get(), initial)
  assert_eq(reads.val, 1)
  let next = @style.Theme(palette=@style.Palette::dark())
  value.set(next)
  assert_eq(reads.val, 1)
  assert_eq(signal_source.get(), next)
  assert_eq(source.get(), next)
  assert_eq(reads.val, 2)
}
