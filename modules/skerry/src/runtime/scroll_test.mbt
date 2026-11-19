///|
struct ScrollRecorder {
  clips : Array[@foundation.Rect]
  fills : Array[(@foundation.Rect, @foundation.Rect, @foundation.Color)]
}

///|
fn ScrollRecorder::ScrollRecorder() -> ScrollRecorder {
  { clips: [], fills: [], }
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn clear(self, _) {
  self.clips.clear()
  self.fills.clear()
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn fill_rect(
  self,
  frame,
  color,
) {
  self.fills.push((frame, self.clips[self.clips.length() - 1], color))
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn fill_rounded_rect(
  self,
  rounded,
  color,
) {
  @foundation.SceneRenderer::fill_rect(self, rounded.rect, color)
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn stroke_rect(
  _,
  _,
  _,
  _,
) {
  ()
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn stroke_rounded_rect(
  _,
  _,
  _,
  _,
) {
  ()
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn draw_text(_, _) {
  ()
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn push_clip(self, clip) {
  let effective = if self.clips.last() is Some(parent) {
    parent.intersect(clip)
  } else {
    clip
  }
  self.clips.push(effective)
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn pop_clip(self) {
  ignore(self.clips.pop())
}

///|
fn scroll_tile(
  index : Int32,
  clicks : Array[Int32],
  positions? : Array[@foundation.Point],
) -> @view.View {
  @view.interactive(
    @view.box(
      style=@style.BoxStyle()
        .width(60.0)
        .height(30.0)
        .background(@foundation.Color::rgb(r=index * 30, g=0, b=0)),
    ),
    on_click=fn() { clicks.push(index) },
    on_pointer_down=fn(event) {
      if positions is Some(values) {
        values.push(event.position)
      }
    },
  )
}

///|
test "scroll viewport clips paint and hit testing and translates pointer coordinates" {
  let clicks : Array[Int32] = []
  let positions : Array[@foundation.Point] = []
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          scroll_tile(1, clicks, positions~),
          scroll_tile(2, clicks, positions~),
          scroll_tile(3, clicks, positions~),
        ]),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=60.0, height=50.0)
  let renderer = ScrollRecorder()
  root.paint(renderer, size~)
  let first = root.snapshot().unwrap()
  let viewport = first.tree.nodes[0].scroll.unwrap()
  assert_eq(viewport.content_size.height, 90.0)
  assert_eq(viewport.max_offset, 40.0)
  assert_eq(renderer.clips.length(), 0)
  assert_eq(renderer.fills[2].0.origin.y, 60.0)
  assert_true(renderer.fills[2].0.intersect(renderer.fills[2].1).is_empty())
  assert_false(root.click_at(size~, point=Point(x=5.0, y=65.0)))
  assert_eq(clicks, [])
  assert_true(
    root.scroll_at(
      size~,
      point=Point(x=5.0, y=5.0),
      delta=Point(x=0.0, y=100.0),
    ),
  )
  assert_eq(offset.get(), 40.0)
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, first.frame.layout_count)
  let scrolled = root.snapshot().unwrap()
  assert_eq(scrolled.tree.nodes[4].frame.origin.y, 20.0)
  assert_eq(scrolled.tree.nodes[4].clip, @foundation.Rect::from_size(size))
  assert_eq(renderer.fills[2].0, scrolled.tree.nodes[4].frame)
  assert_true(root.pointer_down(size~, point=Point(x=5.0, y=25.0)))
  assert_eq(positions, [Point(x=5.0, y=5.0)])
  assert_true(root.pointer_up(size~, point=Point(x=5.0, y=25.0)))
  assert_eq(clicks, [3])
  assert_false(root.click_at(size~, point=Point(x=5.0, y=50.0)))
  assert_false(
    root.scroll_at(size~, point=Point(x=5.0, y=5.0), delta=Point(x=0.0, y=1.0)),
  )
}

///|
test "scroll offsets clamp per viewport without mutating requested values in paint" {
  let offset = @reactive.signal(30.0)
  let create = fn() {
    @view.scroll_view(
      @view.column([
        @view.fill_box(30.0),
        @view.fill_box(30.0),
        @view.fill_box(30.0),
      ]),
      offset~,
    )
  }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  first.paint(ScrollRecorder(), size=Size(width=60.0, height=50.0))
  second.paint(ScrollRecorder(), size=Size(width=60.0, height=80.0))
  assert_eq(
    first.snapshot().unwrap().tree.nodes[0].scroll.unwrap().offset,
    30.0,
  )
  assert_eq(
    second.snapshot().unwrap().tree.nodes[0].scroll.unwrap().offset,
    10.0,
  )
  assert_eq(offset.get(), 30.0)
  assert_false(second.needs_frame())
  let previous = first.snapshot().unwrap()
  offset.set(-20.0)
  assert_true(first.snapshot() is None)
  first.paint(ScrollRecorder(), size=Size(width=60.0, height=50.0))
  assert_eq(first.snapshot().unwrap().tree.nodes[0].scroll.unwrap().offset, 0.0)
  assert_eq(offset.get(), -20.0)
  assert_false(first.needs_frame())
  assert_eq(previous.tree.nodes[0].scroll.unwrap().offset, 30.0)
}

///|
test "translated and clipped views keep identity and use the same paint input geometry" {
  let clicks = Ref(0)
  let button = @controls.button(
    "x",
    style=@controls.ButtonStyle().surface(
      @style.BoxStyle().width(30.0).height(30.0),
    ),
    on_click=fn() { clicks.val += 1 },
  )
  let id = button.node_id_at_path([])
  let moved = button
    .translated(Point(x=20.0, y=10.0))
    .clip()
    .debug(name="moved")
  assert_eq(moved.node_id_at_path([]), id)
  let root = @runtime.mount(
    fn() { @view.column([moved]) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(ScrollRecorder(), size=Size(width=100.0, height=100.0))
  let node = root.snapshot().unwrap().tree.nodes[1]
  assert_eq(node.frame, Rect(x=20.0, y=10.0, width=30.0, height=30.0))
  assert_eq(node.clip, node.frame)
  assert_eq(node.debug_name, Some("moved"))
  assert_false(
    root.click_at(
      size=Size(width=100.0, height=100.0),
      point=Point(x=5.0, y=5.0),
    ),
  )
  assert_true(
    root.click_at(
      size=Size(width=100.0, height=100.0),
      point=Point(x=25.0, y=15.0),
    ),
  )
  assert_eq(clicks.val, 1)
}

///|
test "visible overflow children receive input unless their ancestor clips them" {
  for clipped in [false, true] {
    let clicks : Array[Int32] = []
    let row = @view.row(
      [
        @controls.button(
          "",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(60.0).height(30.0),
          ),
          on_click=fn() { clicks.push(1) },
        ),
      ],
      style=@view.FlexStyle().surface(@style.BoxStyle().height(10.0)),
    )
    let row = if clipped { row.clip() } else { row }
    let root = @runtime.mount(
      fn() { @view.column([row]) },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=60.0, height=60.0)
    let renderer = ScrollRecorder()
    root.paint(renderer, size~)
    assert_eq(renderer.fills[0].0.size.height, 30.0)
    assert_eq(
      renderer.fills[0].1.size.height,
      if clipped {
        10.0
      } else {
        60.0
      },
    )
    assert_eq(root.click_at(size~, point=Point(x=5.0, y=20.0)), !clipped)
  }
}

///|
test "nested wheel routing bubbles at boundaries and respects disabled overlays" {
  let inner = @reactive.signal(0.0)
  let outer = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.scroll_view(
            @view.column([@view.fill_box(30.0), @view.fill_box(30.0)]),
            offset=inner,
            style=@style.BoxStyle().height(30.0),
          ),
          @view.fill_box(80.0),
        ]),
        offset=outer,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=60.0, height=50.0)
  let point = @foundation.Point(x=5.0, y=10.0)
  assert_true(root.scroll_at(size~, point~, delta=Point(x=0.0, y=50.0)))
  assert_eq(inner.get(), 30.0)
  assert_eq(outer.get(), 0.0)
  assert_true(root.scroll_at(size~, point~, delta=Point(x=0.0, y=10.0)))
  assert_eq(outer.get(), 10.0)
  assert_true(root.scroll_at(size~, point~, delta=Point(x=0.0, y=-50.0)))
  assert_eq(inner.get(), 0.0)
  assert_eq(outer.get(), 10.0)
  assert_true(root.scroll_at(size~, point~, delta=Point(x=0.0, y=-50.0)))
  assert_eq(outer.get(), 0.0)
  let blocked_offset = @reactive.signal(0.0)
  let overlay_visible = @reactive.signal(true)
  let blocked = @runtime.mount(
    fn() {
      @view.stack([
        @view.scroll_view(
          @view.column([@view.fill_box(100.0)]),
          offset=blocked_offset,
          style=@style.BoxStyle().width(60.0).height(50.0),
        ),
        @view.show(fn() { overlay_visible.get() }, fn() {
          @view.interactive(
            @view.box(style=@style.BoxStyle().width(60.0).height(50.0)),
            disabled=true,
          )
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer blocked.dispose()
  assert_false(blocked.scroll_at(size~, point~, delta=Point(x=0.0, y=10.0)))
  assert_eq(blocked_offset.get(), 0.0)
  overlay_visible.set(false)
  assert_true(blocked.scroll_at(size~, point~, delta=Point(x=0.0, y=10.0)))
  assert_eq(blocked_offset.get(), 10.0)
}

///|
test "horizontal scroll clamps content width and skips points outside the viewport" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.row([
          @view.box(style=@style.BoxStyle().width(50.0).height(20.0)),
          @view.box(style=@style.BoxStyle().width(50.0).height(20.0)),
          @view.box(style=@style.BoxStyle().width(50.0).height(20.0)),
        ]),
        axis=Horizontal,
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=60.0, height=30.0)
  root.paint(ScrollRecorder(), size~)
  let first = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap()
  assert_eq(first.content_size.width, 150.0)
  assert_eq(first.max_offset, 90.0)
  assert_false(
    root.scroll_at(
      size~,
      point=Point(x=70.0, y=5.0),
      delta=Point(x=10.0, y=0.0),
    ),
  )
  assert_true(
    root.scroll_at(
      size~,
      point=Point(x=5.0, y=5.0),
      delta=Point(x=500.0, y=0.0),
    ),
  )
  assert_eq(offset.get(), 90.0)
  root.paint(ScrollRecorder(), size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[4].frame.origin.x, 10.0)
}

///|
test "scroll viewport padding and resize share stable snapshots and child coordinates" {
  let offset = @reactive.signal(20.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.fill_box(30.0),
          @view.fill_box(30.0),
          @view.fill_box(30.0),
        ]),
        offset~,
        style=@style.BoxStyle().padding(@foundation.Insets::all(5.0)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(ScrollRecorder(), size=Size(width=60.0, height=50.0))
  let first = root.snapshot().unwrap()
  let scroll = first.tree.nodes[0].scroll.unwrap()
  assert_eq(scroll.viewport, Rect(x=5.0, y=5.0, width=50.0, height=40.0))
  assert_eq(scroll.content_size, Size(width=50.0, height=90.0))
  assert_eq(scroll.max_offset, 50.0)
  assert_eq(first.tree.nodes[2].frame.origin, Point(x=5.0, y=-15.0))
  assert_eq(
    first.tree.nodes[2].clip,
    Rect(x=0.0, y=5.0, width=60.0, height=40.0),
  )
  assert_false(
    root.scroll_at(
      size=Size(width=60.0, height=50.0),
      point=Point(x=2.0, y=2.0),
      delta=Point(x=0.0, y=10.0),
    ),
  )
  root.paint(ScrollRecorder(), size=Size(width=60.0, height=120.0))
  let resized = root.snapshot().unwrap()
  assert_eq(resized.tree.nodes[0].scroll.unwrap().offset, 0.0)
  assert_eq(resized.tree.nodes[0].scroll.unwrap().max_offset, 0.0)
  assert_eq(offset.get(), 20.0)
  assert_eq(first.tree.nodes[0].scroll.unwrap().offset, 20.0)
  assert_false(root.needs_frame())
}

///|
test "captured release outside a scroll clip does not activate the child" {
  let clicks : Array[Int32] = []
  let released = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.interactive(scroll_tile(1, clicks), on_pointer_up=fn(_) {
            released.val += 1
          }),
          scroll_tile(2, clicks),
        ]),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=60.0, height=25.0)
  assert_true(root.pointer_down(size~, point=Point(x=5.0, y=10.0)))
  assert_true(root.pointer_up(size~, point=Point(x=5.0, y=28.0)))
  assert_eq(released.val, 1)
  assert_eq(clicks, [])
}

///|
test "scroll subscriptions stop on detach and snapshots never read live offsets" {
  let offset = @reactive.signal(0.0)
  let visible = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @view.scroll_view(
          @view.column([@view.fill_box(100.0)]),
          offset~,
          style=@style.BoxStyle().height(30.0),
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=60.0, height=60.0)
  root.paint(ScrollRecorder(), size~)
  let runs = Ref(0)
  let stop = @reactive.effect(fn() {
    runs.val += 1
    ignore(root.snapshot())
  })
  defer stop()
  offset.set(10.0)
  assert_eq(runs.val, 1)
  root.paint(ScrollRecorder(), size~)
  visible.set(false)
  root.paint(ScrollRecorder(), size~)
  assert_false(root.needs_frame())
  offset.set(20.0)
  assert_false(root.needs_frame())
  assert_eq(runs.val, 1)
}

///|
test "scroll changes during paint keep one frozen projection until the next frame" {
  let offset = @reactive.signal(0.0)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.element(
            style=@style.BoxStyle().width(60.0).height(30.0),
            painter=@view.Painter(fn(context, frame) {
              context.fill_box(frame, @foundation.Color::black(), 0.0)
              if first.val {
                first.val = false
                offset.set(40.0)
              }
            }),
          ),
          @view.fill_box(30.0),
          @view.fill_box(30.0),
        ]),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = ScrollRecorder()
  let size = @foundation.Size(width=60.0, height=50.0)
  let delivered : Array[@runtime.UiSnapshot] = []
  let stop = root.observe_snapshots(fn(snapshot) { delivered.push(snapshot) })
  defer stop()
  root.paint(renderer, size~)
  assert_eq(renderer.fills[:3].to_owned().map(fill => fill.0.origin.y), [
    0.0, 30.0, 60.0,
  ])
  assert_eq(renderer.fills[4].0.origin.y, 2.0)
  assert_eq(delivered.length(), 0)
  assert_true(root.snapshot() is None)
  assert_true(root.needs_frame())
  root.paint(renderer, size~)
  assert_eq(renderer.fills[:3].to_owned().map(fill => fill.0.origin.y), [
    -40.0, -10.0, 20.0,
  ])
  assert_eq(delivered.length(), 1)
  assert_eq(delivered[0].tree.nodes[0].scroll.unwrap().offset, 40.0)
  assert_eq(
    renderer.fills[4].0,
    delivered[0].tree.nodes[0].scroll.unwrap().scrollbar.unwrap().thumb,
  )
  assert_eq(root.frame_stats().layout_count, 1)
  assert_false(root.needs_frame())
}

///|
test "disabled ancestors block painted overflow and explicit clips expose siblings" {
  for clipped in [false, true] {
    let clicks = Ref(0)
    let disabled = @view.interactive(
      @view.row(
        [
          @controls.button(
            "",
            style=@controls.ButtonStyle().surface(
              @style.BoxStyle().width(60.0).height(30.0),
            ),
          ),
        ],
        style=@view.FlexStyle().surface(@style.BoxStyle().height(10.0)),
      ),
      disabled=true,
    )
    let overlay = if clipped { disabled.clip() } else { disabled }
    let root = @runtime.mount(
      fn() {
        @view.stack([
          @controls.button(
            "",
            style=@controls.ButtonStyle().surface(
              @style.BoxStyle().width(60.0).height(30.0),
            ),
            on_click=fn() { clicks.val += 1 },
          ),
          overlay,
        ])
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    assert_eq(
      root.click_at(
        size=Size(width=60.0, height=60.0),
        point=Point(x=5.0, y=20.0),
      ),
      clipped,
    )
    assert_eq(clicks.val, if clipped { 1 } else { 0 })
  }
}

///|
test "zero wheel work and disposal during measurement never change scroll state" {
  let offset = @reactive.signal(0.0)
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let root = @runtime.mount(
    fn() { @view.scroll_view(@view.text("text that needs layout"), offset~) },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      if root_ref.val is Some(root) {
        root.dispose()
      }
    }),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  let size = @foundation.Size(width=60.0, height=10.0)
  assert_false(
    root.scroll_at(size~, point=Point(x=5.0, y=5.0), delta=Point(x=0.0, y=0.0)),
  )
  assert_false(root.is_disposed())
  assert_eq(root.frame_stats().layout_count, 0)
  assert_false(
    root.scroll_at(size~, point=Point(x=5.0, y=5.0), delta=Point(x=0.0, y=10.0)),
  )
  assert_true(root.is_disposed())
  assert_eq(offset.get(), 0.0)
}

///|
test "scroll extent includes visible layout overflow but excludes clipped descendants" {
  for clipped in [false, true] {
    let offset = @reactive.signal(0.0)
    let content = @view.row(
      [
        @controls.button(
          "",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(60.0).height(30.0),
          ),
        ),
      ],
      style=@view.FlexStyle().surface(@style.BoxStyle().height(10.0)),
    )
    let content = if clipped { content.clip() } else { content }
    let root = @runtime.mount(
      fn() { @view.scroll_view(content, offset~) },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=60.0, height=25.0)
    root.paint(ScrollRecorder(), size~)
    let scroll = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap()
    assert_eq(scroll.content_size.height, if clipped { 10.0 } else { 30.0 })
    assert_eq(scroll.max_offset, if clipped { 0.0 } else { 5.0 })
    assert_eq(
      root.scroll_at(
        size~,
        point=Point(x=5.0, y=5.0),
        delta=Point(x=0.0, y=20.0),
      ),
      !clipped,
    )
    assert_eq(offset.get(), if clipped { 0.0 } else { 5.0 })
  }
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn draw_image(
  _self,
  _image,
  _placement,
) {
  ()
}

///|
impl @foundation.SceneRenderer for ScrollRecorder with fn draw_line(
  _,
  _,
  _,
  _,
  _,
) {
  ()
}
