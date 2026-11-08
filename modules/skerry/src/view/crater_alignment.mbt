///|
fn css_justify_content(value : @style.JustifyContent) -> @css_values.Alignment {
  match value {
    Start => Start
    Center => Center
    End => End
    SpaceBetween => SpaceBetween
    SpaceAround => SpaceAround
    SpaceEvenly => SpaceEvenly
  }
}

///|
fn css_align_items(value : @style.AlignItems) -> @css_values.Alignment {
  match value {
    Start => Start
    Center => Center
    End => End
    Stretch => Stretch
  }
}

///|
fn css_align_self(value : @style.AlignSelf) -> @css_values.AlignSelf {
  match value {
    Auto => Auto
    Start => Start
    Center => Center
    End => End
    Stretch => Stretch
  }
}
