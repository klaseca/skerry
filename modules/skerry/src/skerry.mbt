///|
pub using @value {
  trait BoolValue,
  trait StringValue,
  trait IntValue,
  trait DoubleValue,
  trait ThemeSource,
  trait ImageValue,
}

///|
pub using @environment {current_theme, current_color_scheme}

///|
pub using @foundation {
  type Axis,
  type Brush,
  type ChangeEvent,
  type Color,
  type ControlState,
  type OverlayBehavior,
  type OverlayFocus,
  type OverlayPointer,
  type OverlayDismiss,
  type Constraints,
  type IntrinsicSize,
  type FontSpec,
  type Insets,
  type Key,
  type KeyEvent,
  type KeyModifiers,
  type Point,
  type PointerEvent,
  type PointerPhase,
  type Rect,
  type RoundedRect,
  type Size,
  type TextAlign,
  type TextEditCommand,
  type TextEditResult,
  type TextEditShortcut,
  type TextRun,
  type Image,
  type ImageError,
  type ImageFit,
  type ImageAlignment,
  type ImagePlacement,
  trait SceneRenderer,
}

///|
pub using @text {
  type TextCacheStats,
  type TextLayoutInput,
  type TextLayoutLine,
  type TextLayoutResult,
  type TextLayoutSystem,
  type TextMeasureInput,
  type TextMetrics,
  type TextMetricsProvider,
}

///|
pub using @style {
  type BoxStyle,
  type StyleDeclaration,
  type StyleOrigin,
  trait StyleSpec,
  type StyleSource,
  trait SourceStyle,
  merge_sources,
  type StyleMetrics,
  type FlexItemStyle,
  type Styles,
  type Appearance,
  type Palette,
  type Theme,
  type ThemeToken,
  type TokenValues,
  type StyleColor,
  trait ThemeValue,
  trait ColorValue,
  surface_token,
  control_surface_token,
  text_token,
  muted_text_token,
  accent_token,
  on_accent_token,
  border_token,
  selection_token,
  scrollbar_track_token,
  scrollbar_thumb_token,
  type ControlStyles,
  type ScrollbarStyle,
  type JustifyContent,
  type AlignItems,
  type AlignSelf,
}

///|
pub using @reactive {
  type Signal,
  type Computed,
  type Binding,
  type Context,
  type ContextBinding,
  provide,
  signal,
  val,
  bind,
  computed,
  batch,
  untracked,
  watch,
  effect,
  on_cleanup,
}

///|
pub using @runtime {
  type App,
  type ThemeMode,
  type ColorScheme,
  current_app,
  type DirtyState,
  type FrameEvent,
  type FrameStats,
  type RenderingInfo,
  type UiRoot,
  type UiSnapshot,
  type WindowOptions,
  mount,
}

///|
pub using @diagnostics {
  type ComponentSnapshot,
  type ImageSnapshot,
  type ComputedStyle,
  type NodeSnapshot,
  type OverlaySnapshot,
  type PaintStats,
  type ScrollSnapshot,
  type ScrollbarSnapshot,
  type SourceLocation,
  type TreeSnapshot,
}

///|
pub using @view {
  type TextStyle,
  type TextAppearance,
  type FlexStyle,
  type ImageStyle,
  type PaintContext,
  type ComputedStyleContext,
  type Painter,
  type View,
  type Measure,
  type MeasureContext,
  type ElementEvents,
  type PointerContext,
  type KeyHandling,
  type MountContext,
  type Reactivity,
  type TextContent,
  type PopupPlacement,
  type PopupTrigger,
  popup,
  element,
  text_measure,
  dispatch_change,
  apply_appearance,
  apply_active_control_styles,
  box,
  image,
  column,
  empty,
  fragment,
  fill_box,
  for_each,
  interactive,
  row,
  scroll_view,
  text,
  text_of,
  style_scope,
  show,
  stack,
}

///|
pub using @skia_backend {decode_image, load_image}

///|
/// The backend supplies presentation surfaces; the renderer selects a supported
/// protocol. These choices are independent and complete before App::mount.
pub fn run(
  app : @runtime.App,
  backend~ : @backend.AppBackend = @sdl_backend.run,
  renderer~ : @backend.RendererFactory = @skia_backend.raster_renderer,
) -> Unit raise {
  backend(app, renderer)
}

///|
pub using @controls {
  type ButtonStyle,
  type CheckboxStyle,
  type RadioStyle,
  type TextInputStyle,
  type SelectStyle,
  type SelectOption,
  type DialogStyle,
  button,
  checkbox,
  radio,
  radio_group,
  text_input,
  select,
  dialog,
}
