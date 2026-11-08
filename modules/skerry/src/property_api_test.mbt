///|
test "facade exposes typed cancelable control proposals" {
  let event : @skerry.ChangeEvent[(Int32, String)] = ChangeEvent((1, "next"))
  assert_eq(event.value, (1, "next"))
  assert_false(event.default_prevented())
  event.prevent_default()
  assert_true(event.default_prevented())
  ignore(@skerry.checkbox(on_change=fn(change) { change.prevent_default() }))
  ignore(@skerry.radio(on_change=fn(change) { change.prevent_default() }))
  ignore(@skerry.text_input(on_change=fn(change) { change.prevent_default() }))
}

///|
test "facade style lookup retains concrete component types" {
  let declaration = @skerry.ButtonStyle().surface(
    @skerry.BoxStyle().radius(12.0),
  )
  let theme = @skerry.Theme(styles=@skerry.Styles().add(declaration))
  assert_eq((theme.styles.get() : ReadOnlyArray[@skerry.ButtonStyle]), [
    declaration,
  ])
  assert_eq(
    (theme.styles.get() : ReadOnlyArray[@skerry.TextInputStyle]).length(),
    0,
  )
}

///|
fn numeric_property(value : &@skerry.DoubleValue) -> @skerry.Binding[Double] {
  value.to_binding()
}

///|
test "facade exposes direct fixed type sources and explicit constant or derived bindings" {
  let busy = @skerry.signal(false)
  let title = @skerry.signal("Title")
  let fixed = @skerry.button("Unavailable", disabled=@skerry.val(true))
  let direct = @skerry.button("Save", disabled=busy)
  let derived = @skerry.button("Save", disabled=@skerry.bind(() => !busy.get()))
  assert_false(fixed.is_enabled_path([]))
  ignore(direct)
  ignore(derived)
  ignore(@skerry.text("Heading"))
  ignore(@skerry.text(title))
  ignore(@skerry.text(@skerry.bind(() => "Title: \{title.get()}")))
  assert_eq(numeric_property(12.0).constant_value(), Some(12.0))
  assert_eq(numeric_property(@skerry.val(12.0)).constant_value(), Some(12.0))
  let count = @skerry.signal(3.0)
  assert_eq(numeric_property(count).get(), 3.0)
}

///|
test "facade generic binding factories preserve application payload types" {
  let initial = @skerry.val((7, "selected"))
  let model = @skerry.signal((8, "current"))
  let direct : @skerry.Binding[(Int32, String)] = model.bind()
  let derived = @skerry.bind(() => (model.get().0 + 1, "next"))
  assert_eq(initial.constant_value(), Some((7, "selected")))
  assert_eq(direct.get(), (8, "current"))
  assert_eq(derived.get(), (9, "next"))
}

///|
test "facade exposes Computed get direct properties and generic bind" {
  let count = @skerry.signal(1)
  let title : @skerry.Computed[String] = @skerry.computed(() => {
    "Count: \{count.get()}"
  })
  let blocked = @skerry.computed(() => count.get() < 2)
  let number = @skerry.computed(() => count.get().to_double() * 2.0)
  ignore(@skerry.text(title))
  ignore(@skerry.button("Save", disabled=blocked))
  assert_eq(title.get(), "Count: 1")
  assert_eq(numeric_property(number).get(), 2.0)
  let payload = @skerry.computed(() => (count.get(), "selected"))
  let binding : @skerry.Binding[(Int32, String)] = payload.bind()
  count.set(2)
  assert_eq(title.get(), "Count: 2")
  assert_false(blocked.get())
  assert_eq(binding.get(), (2, "selected"))
}

///|
test "facade exposes reactive control labels placeholders and radio group label factories" {
  let title = @skerry.signal("Title")
  let computed = @skerry.computed(() => "Label: \{title.get()}")
  let views = [
    @skerry.button(title),
    @skerry.checkbox(label=computed),
    @skerry.radio(label=title.bind()),
    @skerry.text_input(placeholder=@skerry.bind(() => title.get())),
    @skerry.button(@skerry.val("Constant")),
  ]
  assert_eq(views.length(), 5)
  let selected = @skerry.signal(1)
  let label : (Int32) -> String = option => option.to_string()
  ignore(@skerry.radio_group(selected, [1, 2], label~))
  ignore(@skerry.radio_group(selected, [1, 2], label=fn(_) { title }))
  ignore(@skerry.radio_group(selected, [1, 2], label=fn(_) { computed }))
  ignore(
    @skerry.radio_group(selected, [1, 2], label=fn(option) {
      @skerry.bind(() => "\{title.get()} \{option}")
    }),
  )
}
