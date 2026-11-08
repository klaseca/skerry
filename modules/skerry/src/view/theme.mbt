///|
/// Read the current root-local theme without tracking or requesting work.
pub fn LayoutState::theme(self : LayoutState) -> @style.Theme {
  self.theme
}

///|
/// Change defaults and invalidate the painted snapshot. Metric changes also
/// invalidate layout; text metrics for other fonts remain cached. Custom hosts
/// request a frame when true is returned and can inspect needs_layout().
/// Equal themes and disposed states return false.
pub fn LayoutState::set_theme(self : LayoutState, theme : @style.Theme) -> Bool {
  guard !self.disposed && self.theme != theme else { return false }
  let layout_changed = self.theme_layout_changed(theme, self.theme_overrides)
  self.theme = theme
  self.source_sheet.set(theme.styles)
  if layout_changed {
    self.invalidate()
  }
  self.painted = false
  true
}
