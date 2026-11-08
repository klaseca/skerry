///|
test "color token identity defaults and immutable assignments" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let blue = @foundation.Color::rgb(r=30, g=70, b=190)
  let first = @style.ThemeToken("Brand", fallback=red)
  let second = @style.ThemeToken("Brand", fallback=blue)
  let initial = @style.Theme()
  let assigned = initial.token(first, blue)
  assert_true(first != second)
  assert_eq(initial.resolve(first), red)
  assert_eq(assigned.resolve(first), blue)
  assert_eq(assigned.resolve(second), blue)
  assert_eq(assigned.token(first, blue), assigned)
  assert_eq(assigned.token(first, red).resolve(first), red)
  assert_eq(assigned.resolve(first), blue)
}

///|
test "token assignment equality depends on values rather than insertion order" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let blue = @foundation.Color::rgb(r=30, g=70, b=190)
  let first = @style.ThemeToken("First", fallback=red)
  let second = @style.ThemeToken("Second", fallback=blue)
  let initial = @style.Theme()
  let forward = initial.token(first, red).token(second, blue)
  let backward = initial.token(second, blue).token(first, red)
  assert_eq(forward, backward)
}

///|
test "same-name tokens retain independent assignments when the collection grows" {
  let fallback = @foundation.Color::black()
  let keys = Array::makei(40, fn(_) { @style.ThemeToken("Custom", fallback~) })
  let initial = @style.Theme()
  let mut theme = initial
  for index, key in keys {
    theme = theme.token(key, @foundation.Color::rgb(r=index, g=70, b=190))
  }
  for index, key in keys {
    assert_eq(theme.resolve(key), @foundation.Color::rgb(r=index, g=70, b=190))
    assert_eq(initial.resolve(key), fallback)
  }
  let updated = theme.token(keys[0], @foundation.Color::white())
  assert_eq(updated.resolve(keys[0]), @foundation.Color::white())
  assert_eq(theme.resolve(keys[0]), @foundation.Color::rgb(r=0, g=70, b=190))
  assert_eq(updated.resolve(keys[1]), theme.resolve(keys[1]))
  assert_eq(theme.resolve(ThemeToken("Custom", fallback~)), fallback)
}

///|
test "palette presets fill ordinary builtin keys and later assignment wins" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  for palette in [@style.Palette(), @style.Palette::dark()] {
    let theme = @style.Theme(palette~)
    let roles = [
      (@style.surface_token, palette.surface),
      (@style.control_surface_token, palette.control_surface),
      (@style.text_token, palette.text),
      (@style.muted_text_token, palette.muted_text),
      (@style.accent_token, palette.accent),
      (@style.on_accent_token, palette.on_accent),
      (@style.border_token, palette.border),
      (@style.selection_token, palette.selection),
      (@style.scrollbar_track_token, palette.scrollbar_track),
      (@style.scrollbar_thumb_token, palette.scrollbar_thumb),
    ]
    let mut parent = @style.Theme()
    for (key, color) in roles {
      assert_eq(theme.resolve(key), color)
      let assigned = theme.token(key, red)
      assert_eq(assigned.resolve(key), red)
      assert_eq(theme.resolve(key), color)
      parent = parent.token(key, red)
    }
    let inherited = theme.inherit_tokens(parent)
    for (key, color) in roles {
      assert_eq(inherited.resolve(key), color)
    }
  }
  let unrelated = @style.ThemeToken("accent", fallback=red)
  assert_eq(
    @style.Theme(palette=@style.Palette::dark()).resolve(unrelated),
    red,
  )
}

///|
test "one paint setter stores literals and typed keys without a binding" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let literal = @style.BoxStyle().background(red)
  let referenced = @style.BoxStyle().background(@style.accent_token)
  let theme = @style.Theme(palette=@style.Palette::dark())
  assert_eq(literal.paint.background, Some(Literal(red)))
  assert_eq(referenced.paint.background, Some(Token(@style.accent_token)))
  assert_eq(literal.paint.background.unwrap().resolve(theme), red)
  assert_eq(
    referenced.paint.background.unwrap().resolve(theme),
    theme.resolve(@style.accent_token),
  )
}

///|
test "complete child themes supply their colors and derived themes retain assignments" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let blue = @foundation.Color::rgb(r=30, g=70, b=190)
  let custom = @style.ThemeToken("Border", fallback=@foundation.Color::black())
  let parent = @style.Theme()
    .token(custom, red)
    .token(@style.accent_token, blue)
  let replacement = @style.Theme(palette=@style.Palette::dark())
  let child = replacement.inherit_tokens(parent)
  assert_eq(child.resolve(custom), red)
  assert_eq(child.resolve(@style.accent_token), @style.Palette::dark().accent)
  let derived = { ..parent, font: parent.font.size(22.0), }.inherit_tokens(
    parent,
  )
  assert_eq(derived.resolve(custom), red)
  assert_eq(derived.resolve(@style.accent_token), blue)
  assert_eq(parent.font.point_size(), 16.0)
}

///|
test "custom keys with builtin names keep their fallback and inherited values" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let blue = @foundation.Color::rgb(r=30, g=70, b=190)
  let custom = @style.ThemeToken("accent", fallback=red)
  let parent = @style.Theme()
    .token(@style.accent_token, red)
    .token(custom, blue)
  let replacement = @style.Theme(palette=@style.Palette::dark())
  let child = replacement.inherit_tokens(parent)
  assert_true(custom != @style.accent_token)
  assert_eq(replacement.resolve(custom), red)
  assert_eq(child.resolve(custom), blue)
  assert_eq(
    child.resolve(@style.accent_token),
    replacement.resolve(@style.accent_token),
  )
  assert_eq(child.token(custom, red).resolve(custom), red)
  assert_eq(parent.resolve(custom), blue)
}

///|
test "the token collection contains preset colors and custom assignments together" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let blue = @foundation.Color::rgb(r=30, g=70, b=190)
  let custom = @style.ThemeToken("CardBorder", fallback=red)
  let theme = @style.Theme(palette=@style.Palette::dark())
    .token(@style.accent_token, blue)
    .token(custom, red)
  // Copying just the stored assignments also copies all preset colors.
  let copied = @style.Theme(tokens=theme.tokens)
  assert_eq(copied, theme)
  assert_eq(
    copied.resolve(@style.surface_token),
    @style.Palette::dark().surface,
  )
  assert_eq(copied.resolve(@style.accent_token), blue)
  assert_eq(copied.resolve(custom), red)
  assert_eq(
    @style.BoxStyle().background(@style.accent_token).paint.background
    .unwrap()
    .resolve(copied),
    blue,
  )
}

///|
test "the same inheritance merge handles missing builtin and custom keys" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let blue = @foundation.Color::rgb(r=30, g=70, b=190)
  let custom = @style.ThemeToken("CardBorder", fallback=red)
  let parent = @style.Theme(palette=@style.Palette::dark())
    .token(@style.accent_token, blue)
    .token(custom, blue)
  let partial = { ..@style.Theme(), tokens: TokenValues(), }
    .token(@style.text_token, red)
    .token(custom, red)
  let child = partial.inherit_tokens(parent)
  assert_eq(child.resolve(@style.accent_token), blue)
  assert_eq(child.resolve(@style.surface_token), @style.Palette::dark().surface)
  assert_eq(child.resolve(@style.text_token), red)
  assert_eq(child.resolve(custom), red)
  assert_eq(child.inherit_tokens(parent), child)
  assert_eq(parent.resolve(custom), blue)
}
