///|
fn test_text_layout_system(
  on_measure~ : () -> Unit = fn() { () },
) -> @text.TextLayoutSystem {
  @text.TextLayoutSystem::from_metrics(
    TextMetricsProvider(measure=fn(input) {
      on_measure()
      let advance = input.font.point_size() * 0.6
      let carets : Array[Double] = [0.0]
      let mut width = 0.0
      for _ in input.text {
        width = width + advance
        carets.push(width)
      }
      TextMetrics(
        width~,
        line_height=input.font.point_size() * 1.25,
        baseline=input.font.point_size(),
        caret_positions=carets,
      )
    }),
  )
}

///|
fn test_key_event(key : @foundation.Key) -> @foundation.KeyEvent {
  KeyEvent(key~)
}

///|
fn test_shift_key_event(key : @foundation.Key) -> @foundation.KeyEvent {
  KeyEvent(key~, modifiers=KeyModifiers(shift=true))
}

///|
fn test_control_key_event(key : @foundation.Key) -> @foundation.KeyEvent {
  KeyEvent(key~, modifiers=KeyModifiers(control=true))
}

///|
struct TextRunRecorder {
  text : Ref[String?]
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn clear(_self, _color) {
  ()
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn fill_rect(
  _self,
  _rect,
  _color,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn stroke_rect(
  _self,
  _rect,
  _color,
  _width,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn fill_rounded_rect(
  _self,
  _rounded,
  _color,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn stroke_rounded_rect(
  _self,
  _rounded,
  _color,
  _width,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn draw_text(self, run) {
  self.text.val = Some(run.text)
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn push_clip(
  _self,
  _rect,
) {
  ()
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn pop_clip(_self) {
  ()
}

///|
impl @foundation.SceneRenderer for TextRunRecorder with fn draw_image(
  _self,
  _image,
  _placement,
) {
  ()
}
