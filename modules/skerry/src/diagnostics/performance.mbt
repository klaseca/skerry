///|
/// Work performed during one completed paint call. Layout triggered earlier by
/// input is included in the root totals, not in this paint's counts. layout_ms
/// includes tree construction and reflow; paint_ms includes clear and drawing,
/// excluding layout. Times are milliseconds and None when profiling was disabled
/// or its registration changed during the call. Present and observer delivery
/// are outside these timings.
#derive(Debug, Eq)
pub(all) struct PaintStats {
  layout_count : Int32
  layout_pass_count : Int32
  text_measure_count : Int32
  layout_ms : Double?
  paint_ms : Double?
}

///|
pub extend PaintStats with Debug::{to_repr}

///|
pub extend PaintStats with Eq::{equal, not_equal}
