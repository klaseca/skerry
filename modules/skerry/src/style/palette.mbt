///|
/// A convenient preset for the built-in color tokens. Theme copies these values
/// into its token collection at construction or when applying the preset.
#derive(Eq, Debug)
pub(all) struct Palette {
  surface : @foundation.Color
  control_surface : @foundation.Color
  text : @foundation.Color
  muted_text : @foundation.Color
  accent : @foundation.Color
  on_accent : @foundation.Color
  border : @foundation.Color
  selection : @foundation.Color
  scrollbar_track : @foundation.Color
  scrollbar_thumb : @foundation.Color
}

///|
pub extend Palette with Eq::{equal, not_equal}

///|
pub extend Palette with Debug::{to_repr}

///|
/// The default light palette preserves the built-in colors.
pub fn Palette::Palette(
  surface~ : @foundation.Color = @foundation.Color::surface(),
  control_surface~ : @foundation.Color = @foundation.Color::white(),
  text~ : @foundation.Color = @foundation.Color::black(),
  muted_text~ : @foundation.Color = @foundation.Color::rgb(r=120, g=128, b=140),
  accent~ : @foundation.Color = @foundation.Color::accent(),
  on_accent~ : @foundation.Color = @foundation.Color::white(),
  border~ : @foundation.Color = @foundation.Color::rgb(r=148, g=163, b=184),
  selection~ : @foundation.Color = @foundation.Color::rgb(r=191, g=219, b=254),
  scrollbar_track~ : @foundation.Color = @foundation.Color::rgb(
    r=241,
    g=241,
    b=241,
  ),
  scrollbar_thumb~ : @foundation.Color = @foundation.Color::rgb(
    r=160,
    g=160,
    b=160,
  ),
) -> Palette {
  {
    surface,
    control_surface,
    text,
    muted_text,
    accent,
    on_accent,
    border,
    selection,
    scrollbar_track,
    scrollbar_thumb,
  }
}

///|
pub fn Palette::dark() -> Palette {
  Palette(
    surface=@foundation.Color::rgb(r=24, g=27, b=34),
    control_surface=@foundation.Color::rgb(r=35, g=41, b=52),
    text=@foundation.Color::rgb(r=233, g=238, b=246),
    muted_text=@foundation.Color::rgb(r=152, g=163, b=184),
    accent=@foundation.Color::rgb(r=96, g=165, b=250),
    on_accent=@foundation.Color::rgb(r=17, g=24, b=39),
    border=@foundation.Color::rgb(r=75, g=85, b=99),
    selection=@foundation.Color::rgb(r=55, g=85, b=135),
    scrollbar_track=@foundation.Color::rgb(r=31, g=36, b=45),
    scrollbar_thumb=@foundation.Color::rgb(r=107, g=114, b=128),
  )
}

///|
// A preset is converted once into ordinary assignments, without a second color
// representation inside Theme or special metadata on the built-in keys.
fn Palette::tokens(self : Palette) -> TokenValues {
  {
    colors: Map([
      (surface_token, self.surface),
      (control_surface_token, self.control_surface),
      (text_token, self.text),
      (muted_text_token, self.muted_text),
      (accent_token, self.accent),
      (on_accent_token, self.on_accent),
      (border_token, self.border),
      (selection_token, self.selection),
      (scrollbar_track_token, self.scrollbar_track),
      (scrollbar_thumb_token, self.scrollbar_thumb),
    ]),
  }
}

///|
/// The surface role of the consuming theme.
pub let surface_token : ThemeToken[@foundation.Color] = ThemeToken(
  "surface",
  fallback=Palette().surface,
)

///|
/// The control surface role of the consuming theme.
pub let control_surface_token : ThemeToken[@foundation.Color] = ThemeToken(
  "control_surface",
  fallback=Palette().control_surface,
)

///|
/// The text role of the consuming theme.
pub let text_token : ThemeToken[@foundation.Color] = ThemeToken(
  "text",
  fallback=Palette().text,
)

///|
/// The muted text role of the consuming theme.
pub let muted_text_token : ThemeToken[@foundation.Color] = ThemeToken(
  "muted_text",
  fallback=Palette().muted_text,
)

///|
/// The accent role of the consuming theme.
pub let accent_token : ThemeToken[@foundation.Color] = ThemeToken(
  "accent",
  fallback=Palette().accent,
)

///|
/// The on accent role of the consuming theme.
pub let on_accent_token : ThemeToken[@foundation.Color] = ThemeToken(
  "on_accent",
  fallback=Palette().on_accent,
)

///|
/// The border role of the consuming theme.
pub let border_token : ThemeToken[@foundation.Color] = ThemeToken(
  "border",
  fallback=Palette().border,
)

///|
/// The selection role of the consuming theme.
pub let selection_token : ThemeToken[@foundation.Color] = ThemeToken(
  "selection",
  fallback=Palette().selection,
)

///|
/// The scrollbar track role of the consuming theme.
pub let scrollbar_track_token : ThemeToken[@foundation.Color] = ThemeToken(
  "scrollbar_track",
  fallback=Palette().scrollbar_track,
)

///|
/// The scrollbar thumb role of the consuming theme.
pub let scrollbar_thumb_token : ThemeToken[@foundation.Color] = ThemeToken(
  "scrollbar_thumb",
  fallback=Palette().scrollbar_thumb,
)
