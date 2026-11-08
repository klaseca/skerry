///|
test "basic theme button cycles application modes without user theme state" {
  let app = @skerry.App(content=app_view)
  let system = @skerry.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(_) {
      TextMetrics(width=0.0, line_height=20.0, baseline=16.0, caret_positions=[])
    }),
  )
  let root = app.mount(text_layout_system=system)
  defer root.dispose()
  let theme_control = root.view().node_id_at_path([3, 3])
  assert_eq(root.theme(), Theme())
  assert_eq(app.theme_mode(), System)
  for _ in 0..<6 {
    assert_true(root.key_down(KeyEvent(key=KeyTab)))
  }
  assert_true(root.key_down(KeyEvent(key=KeySpace)))
  assert_true(root.key_up(KeyEvent(key=KeySpace)))
  assert_eq(app.theme_mode(), Light)
  assert_true(root.key_down(KeyEvent(key=KeySpace)))
  assert_true(root.key_up(KeyEvent(key=KeySpace)))
  assert_eq(app.theme_mode(), Dark)
  assert_eq(
    root.theme().tokens,
    @skerry.Theme(palette=@skerry.Palette::dark()).tokens,
  )
  assert_eq(root.view().node_id_at_path([3, 3]), theme_control)
  root.dispose()
  app.set_theme_mode(System)
  assert_eq(
    root.theme().tokens,
    @skerry.Theme(palette=@skerry.Palette::dark()).tokens,
  )
}
