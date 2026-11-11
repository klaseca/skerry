# Skerry

`klaseca/skerry` is an experimental native desktop UI framework for MoonBit. The
initial backend uses SDL 3 for windows and input and Skia for CPU rendering.

The first release focuses on a small, usable foundation: layout, reactive state,
text, images, basic controls, scrolling, themes, focus handling and text editing
in a single native window.

## Getting started

Clone the repository and use its workspace:

```sh
git clone https://github.com/klaseca/skerry.git
cd skerry
```

Only the native target is supported.

Use the MoonBit compiler version recorded in the root `.moonbit-version` file.
Install Node.js for the native build hooks and make a native C compiler available.
On Windows, the compiler must use an MSVC-compatible ABI.

Configure the native dependencies described below, then run the basic example
from the repository root:

```sh
moon run examples/basic
```

The [repository README](https://github.com/klaseca/skerry#getting-started)
provides the environment setup and development commands.

## Native dependencies

The framework uses the published `klaseca/sdl` and `klaseca/skia` modules. Their
prebuild hooks resolve the native development libraries when a native package is
built or tested.

Set `SDL3_INSTALL_PATH` when SDL is not discoverable through `pkg-config`,
vcpkg, `CMAKE_PREFIX_PATH`, or the compiler toolchain. The path must point to an
SDL development installation containing `include/SDL3/SDL.h` and its link
library.

Set `SKIA_PATH` to a Skia dependency root containing:

```text
<SKIA_PATH>/include/c/sk_types.h
<SKIA_PATH>/out/<system>/<architecture>/release/libSkiaSharp.*
```

The SDL and Skia repositories contain the complete native setup and build
instructions:

- <https://github.com/klaseca/sdl-mbt>
- <https://github.com/klaseca/skia-mbt>

The dynamic libraries must also be available to the operating system when the
application starts. On Windows, add the directories containing `SDL3.dll` and
`libSkiaSharp.dll` to `PATH` or place the DLLs next to the executable.

## Example

```mbt nocheck
///|
fn main raise {
  @skerry.run(
    @skerry.App(title="Counter", width=640, height=360, content=app_view),
  )
}

///|
fn app_view() -> @skerry.View {
  let count = @skerry.signal(0)
  @skerry.column(
    style=@skerry.FlexStyle().spacing(12.0).padding(@skerry.Insets::all(24.0)),
  ) <| [
    @skerry.text_of(count),
    @skerry.button("Increment", on_click=fn() {
      count.update(fn(value) { value + 1 })
    }),
  ]
}
```

The executable package only imports the framework facade:

```mbt nocheck
///|
import {
  "klaseca/skerry",
}
```

`run` uses the SDL application backend and the Skia renderer by default. A
different backend function or renderer provider can be passed independently.
The provider owns its renderer for the duration of the run.

The CPU raster backend explicitly uses SDL's software renderer. Its pixel buffer
is reused between paints; resizing releases the old buffer after its replacement
has been allocated successfully.
This avoids a GPU staging allocation for each CPU-painted frame.

Run the repository example with:

```sh
moon run examples/basic
```

`moon run examples/form` runs a contact form with inline
validation, a reactive Save/Saved button, Enter submission and a result message.
It uses the same built-in application theme and scrolls at smaller window sizes.

`moon run examples/images` demonstrates PNG transparency, JPEG,
reactive replacement, fitting and crop alignment. Run it from the repository root
so its relative asset paths resolve.

## Components and primitives

`klaseca/skerry/view` owns `View`, layout/composition, text, images, scrolling,
input dispatch and the shared component lifecycle. `klaseca/skerry/controls`
provides button, checkbox, radio/radio_group and text_input, with each concrete
style next to its control. Controls depend on public primitives; view has no
production dependency on controls.

The `@skerry` facade re-exports both packages, so applications keep the same
`@skerry.button(...)`, `@skerry.column(...)` and style constructors. Direct imports
of controls and their styles from `@view` should use `@controls` instead.

Most custom components are ordinary functions composing existing views. A custom
drawn leaf can use `element` for typed styles, content measurement and painting:

```mbt check
///|
test "custom measured component through the facade" {
  let title = @skerry.signal("Badge")
  let text = @skerry.TextContent(title)
  let badge = @skerry.element(
    component_name="Badge",
    style=@skerry.BoxStyle().padding(@skerry.Insets::all(6.0)),
    measure=fn(context) {
      @skerry.text_measure(text.get(), context.font, context.text_layout_system)
    },
    painter=@skerry.Painter(fn(context, frame) {
      context.fill_box(frame, context.theme.resolve(@skerry.accent_token), 4.0)
      context.draw_text_block(
        text.get(),
        frame.inset(context.padding),
        context.font,
        context.theme.resolve(@skerry.on_accent_token),
        TextCenter,
      )
    }),
    reactivity=@skerry.Reactivity().with_text(text),
  )
  ignore(badge)
}
```

`measure` is optional. Omit it for drawing whose size comes from styles or its
parent; no intrinsic measurement callback is installed. Supply it for content
such as text whose intrinsic dimensions participate in layout.

```mbt check
///|
test "drawing sized by style" {
  let swatch = @skerry.element(
    style=@skerry.BoxStyle().width(60.0).height(30.0),
    painter=@skerry.Painter(fn(context, frame) {
      context.fill_box(frame, context.theme.resolve(@skerry.accent_token), 0.0)
    }),
  )
  ignore(swatch)
}
```

Create one `TextContent` per leaf; its identity and applied value belong to that
leaf. `TextContent` construction is cold. `Reactivity.with_text` materializes its value
for that leaf at mount; `get()` reads that value during measurement, paint or input without
pulling the producer again. `Reactivity::paint` tracks paint-only state; a custom
mount callback receives `MountContext` for layout/paint invalidation and returns
its disposer. Component functions create their local state with ordinary signals
and capture it in callbacks; no state registration is required.

Each call to `column`, `text_input` or a custom component function creates one
`View` instance. Call the function again for an independent instance. A ready
`View` can be mounted once: placing it in two positions/roots, or mounting it after
disposal, is a programming error. Copies and decorated handles retain the same
identity and lifetime. To intentionally share application state, pass the same
external signal to separately constructed components. `show` calls its builder
again on a real branch transition; `for_each` retains instances for surviving
keys and builds fresh ones for new entries.

`ElementEvents` attaches focus, pointer, keyboard and text-edit behavior. Its
`handle_*` callbacks implement behavior; `on_*` callbacks observe it afterwards.
The constructor also accepts `disabled` sources and a `focus_entry` callback
that selects a preferred node ID within one Tab stop. These sources and callbacks
follow the same mount and context rules as the rest of the element. Custom
primitives configure availability through `element(events=ElementEvents(disabled=...))`.
Built-in controls forward their `disabled` argument into this configuration.
`interactive` preserves existing disabled state, focus grouping and behavior
while adding observers; its explicit `disabled` argument replaces the previous source.
Editable components set `editable=true` and use `dispatch_change`, so default
writes are canceled after prevention, detach, disabling or a superseding proposal.
`element(component_name=...)` names a custom primitive. A composition can declare
its own virtual diagnostic boundary with `view.component("Card")`, preserving the
primitive's name and UI identity. Repeated calls add levels: a Card returning a
Column can appear as `ProfileCard → Card → Column`, with only Column in layout.
`debug(name="summary")` labels the current level. These diagnostic names select
neither styles nor behavior and do not create reactive scopes or mount lifetimes.

```mbt check
///|
test "virtual components preserve the same UI instance" {
  let body = @skerry.column([]).debug(name="body")
  let card = body.component("Card")
  let profile = card.component("ProfileCard").debug(name="summary")
  assert_eq(profile.node_id_at_path([]), body.node_id_at_path([]))
}
```

Snapshots keep `NodeSnapshot.component_name` for the actual UI node and expose
its virtual levels in `NodeSnapshot.components`, outermost first. Component IDs
use a separate diagnostic namespace from UI node IDs; an inspector must retain
that distinction when expanding the virtual tree.
`Painter.with_computed_style` optionally supplies a pure diagnostic resolver.
Its `ComputedStyleContext` contains the outer `frame`, inner `content`, control
state, theme, font and applied style layers. Each component resolves its own
properties; snapshots never execute the drawing callback.

```mbt check
///|
test "pure component diagnostics" {
  let painter = @skerry.Painter::empty().with_computed_style(fn(context) {
    @skerry.ComputedStyle(
      font=context.font,
      indicator_size=context.content.size,
    )
  })
  ignore(painter)
}
```

## Images

Load or decode an image once, before constructing the UI. Both functions are
synchronous and report an `ImageError` for unreadable or invalid input:

```mbt nocheck
let photo = @skerry.load_image("assets/photo.jpg")
// Alternatively: let photo = @skerry.decode_image(encoded_bytes)
let selected = @skerry.signal(photo)
@skerry.image(
  selected,
  style=@skerry.ImageStyle().width(240.0).height(160.0).fit(Cover),
)
```

`image` accepts an Image, Signal, Computed or Binding directly. With no explicit
size it uses the image's intrinsic dimensions, subject to layout constraints.
Setting one dimension preserves the aspect ratio; setting both defines the frame.
`ImageFit::Contain` (the default) fits the whole image, `Cover` crops it to fill the
frame, and `Fill` stretches it. `.align(TopLeft)` and the other eight
`ImageAlignment` values position unused space or select which part to crop.
`ImageStyle` supports typed theme rules and reactive styles, including
`style.select(...)`, like other component styles.

An Image is an immutable shared resource with renderer-independent pixels.
Reuse the same Image across views instead of loading it again. Replacing it with
another image of the same dimensions only repaints; a different intrinsic size
requests layout. Loading and decoding never run as part of painting.
The Skia renderer reuses its native copy across frames and drops unused cache
entries after a frame. Application-held Images remain alive while referenced.
Diagnostic snapshots contain only size and placement, without retaining pixels.

Custom renderers implement `SceneRenderer::draw_image(image, placement)`;
placement supplies source and destination rectangles after fitting and cropping.
`Image::pixels()` exposes immutable, tightly packed BGRA8888 premultiplied bytes,
with dimensions and `row_bytes` available on the Image. `Image(width~, height~,
pixels)` constructs one from already decoded pixels and validates their length.

## Value sources

Properties with a fixed result type accept ordinary values, Signals, Computed
values and explicit Bindings. `disabled` uses `BoolValue`; `text`, control labels
and TextInput placeholders use `StringValue`:

```mbt check
///|
test {
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
  ignore(@skerry.button(title))
  ignore(@skerry.checkbox(label=title))
  ignore(@skerry.radio(label=@skerry.computed(() => "Option: \{title.get()}")))
  ignore(@skerry.text_input(placeholder=title))
}
```

`val(value)` describes a constant, `bind(getter)` describes a getter source,
and `signal.bind()` or `computed_value.bind()` exposes an existing reactive value
as a readonly property source. These operations do not read the getter, subscribe
or add a computed node. Each mounted consumer owns its subscription; constants
need no reactive effect. `Binding.get()` reads its producer without adding a cache.

`computed(getter)` returns a separate `Computed[T]` with a `.get()` method. It
creates one lazy cache shared by its readers, recomputing after a dependency
changes. The factory leaves the getter unevaluated until a value is needed:

```mbt check
///|
test {
  let count = @skerry.signal(1)
  let title : @skerry.Computed[String] = @skerry.computed(() => {
    "Count: \{count.get()}"
  })
  let blocked = @skerry.computed(() => count.get() < 2)
  ignore(@skerry.text(title))
  ignore(@skerry.button("Save", disabled=blocked))
  assert_eq(title.get(), "Count: 1")
  count.set(2)
  assert_eq(title.get(), "Count: 2")
  assert_false(blocked.get())
}
```

A Computed shares one cache even across roots. Capture model handles or Context
values when constructing a shared computation. Use `bind` for expressions that
must resolve providers separately in each mount. Disposing a consumer releases
its subscription; other consumers can keep using the same Computed.

When migrating from the previous getter-returning computed API, replace
`value()` with `value.get()`. APIs expecting a function can use `() => value.get()`.

For a generic readonly property, accept `Binding[T]` directly. A new application
type requires no new source trait:

```mbt check
///|
test {
  let initial = @skerry.val((7, "selected"))
  let model = @skerry.signal((8, "current"))
  let direct : @skerry.Binding[(Int32, String)] = model.bind()
  let derived = @skerry.bind(() => (model.get().0 + 1, "next"))
  assert_eq(initial.constant_value(), Some((7, "selected")))
  assert_eq(direct.get(), (8, "current"))
  assert_eq(derived.get(), (9, "next"))
}
```

Custom components can use `IntValue` and `DoubleValue` for numeric properties.
IntValue accepts Int values and their Signal/Computed/Binding forms; DoubleValue
accepts only the corresponding Double forms. Use `12.0` for DoubleValue parameters.
Numeric conversions are explicit: for an Int signal, use a getter such as
`computed(() => count.get().to_double())` when a Double source is needed.
The fixed-type adapters live in `klaseca/skerry/value`, above the generic
`klaseca/skerry/reactive` primitives. The facade reexports the factories and adapters.

Use `bind(() => model.get())` for updates; `val(model.get())` stores a snapshot.
Callbacks and structural builders keep their function types. Writable input
values, checked/selected models and scroll offsets keep their Signal types.
Static BoxStyle parameters retain their existing types and update rules.

`text`, the labels of `button`, `checkbox` and `radio`, and the `text_input`
placeholder accept String, Signal[String], Computed[String] or Binding[String].
They store applied strings separately in each mount; equal strings remain idle
and visible changes request layout. Updating labels preserves node identity,
focus, presses and checked/selected models. Updating a placeholder preserves the
input value, caret and selection. While the input is filled, placeholder changes
do not request a frame; clearing the input displays the latest placeholder.
Layout, paint, input and snapshots of a mounted root do not call these producers.
`text_of(signal)` remains a formatting helper for `T: Show`; custom formatting
uses `text(bind(() => ...))`.

`radio_group` calls its label factory once per option. Return a String for a
static label, or a Signal, Computed or Binding for a reactive label:

```mbt check
///|
test {
  let selected = @skerry.signal(1)
  let prefix = @skerry.signal("Option")
  ignore(
    @skerry.radio_group(selected, [1, 2], label=fn(option) {
      @skerry.computed(() => "\{prefix.get()} \{option}")
    }),
  )
}
```

The group has one Tab stop: its selected enabled option, or the first enabled
option when the value is absent or unavailable. Tab/Shift+Tab leave the group;
unmodified arrow keys move focus and propose a selection, wrapping at the ends.
Space/Enter select the focused option. A canceled proposal keeps the new focus
and the previous model value. Moving focus reveals the option in a ScrollView.
Nested activation in the group supersedes an older pending selection, including
when the nested action activates the already selected option.

`item_disabled` is an optional predicate tracked separately for each option at
mount. It can read Signals and Context; navigation, paint and snapshots use the
applied availability without evaluating the predicate:

```mbt check
///|
test {
  let selected = @skerry.signal(1)
  let unavailable = @skerry.signal(2)
  ignore(
    @skerry.radio_group(
      selected,
      [1, 2, 3],
      label=fn(option) { "Option \{option}" },
      item_disabled=fn(option) { option == unavailable.get() },
    ),
  )
}
```

Disabled options are skipped. Disabling a focused option moves focus to the next
available option, wrapping if needed, without changing the selected value or
emitting on_change. Empty or fully disabled groups have no Tab stop. Disabling the
group or an ancestor clears its focus. Standalone radio controls retain their
individual Tab stops. Custom hosts use View.tab_focus_paths for Tab traversal;
View.focusable_paths still lists all enabled focus targets.

Standalone `View.layout` and unmounted `LayoutState.layout/paint` sample text once
before each operation without retaining subscriptions. Persistent low-level hosts
mount reactivity and forward layout invalidation, then dispose the returned handle.
Their paint reads the applied string. A reused unmounted LayoutState still needs
invalidation when its data changes. Use UiRoot methods to select the correct
providers when sharing a View across roots.

## Editable state and change proposals

`checkbox.checked`, `radio.selected`, `radio_group.selected` and `text_input.value`
accept Signals directly. Omitting the model on a checkbox, radio or text input
gives the control its own state. Neither case requires a setter callback.

Internal state belongs to the mount. Mounting the same control View in different
roots gives each its own checked/selected value or input text. Passing the same
Signal explicitly shares that value; each input still owns its caret, selection,
horizontal scroll and pointer selection independently. A keyed reorder retains
state; removing and mounting the control again starts a fresh lifetime. The new
mount keeps an external Signal's value and initializes the input caret at its end.

Standalone View operations retain local state on that View until an explicit
mount starts a fresh lifetime. Persistent low-level hosts call mount_reactivity
and its disposer; one standalone View supports one concurrent low-level mount.

Optional `on_change` receives `ChangeEvent[T]` **before** the default write.
`event.value` is the proposed value; reading the model in the handler still
returns the previous value. Call `event.prevent_default()` to reject the edit
or to handle the write yourself:

```mbt check
///|
test {
  let name = @skerry.signal("")
  ignore(
    @skerry.text_input(value=name, on_change=fn(event) {
      if event.value.char_length() > 40 {
        event.prevent_default()
      }
    }),
  )
  let accepted = @skerry.signal(false)
  ignore(
    @skerry.checkbox(checked=accepted, on_change=fn(event) {
      event.prevent_default()
      @skerry.batch(fn() {
        accepted.set(event.value)
        name.set("")
      })
    }),
  )
  // An observer can leave the default write to a control with local state.
  ignore(
    @skerry.checkbox(on_change=fn(event) {
      println("Proposed checked: \{event.value}")
    }),
  )
}
```

Without a handler, or when it returns without cancellation, the control applies
the proposed value. A custom write needs `prevent_default()` to replace that
action. Changes apply synchronously, including successive edits in a batch.
External `Signal.set` calls and initial mount do not emit `on_change`.
Use `watch` to observe the model regardless of the source of a change.

A canceled text edit preserves the text, caret, selection and horizontal scroll.
Replacing a selection with identical text only updates selection and emits no
change proposal. A target removed, replaced or disabled during the handler
cannot apply its old default action; a nested edit supersedes the outer edit.
Availability changes inside an enclosing batch reconcile when that batch ends.
Calling `prevent_default()` after dispatch returns does not undo a completed edit.

When migrating callbacks that previously received `T`, read `event.value`
instead. Handlers now run before the control writes, so reading its Signal is
not a way to obtain the proposed value. `on_submit` still receives the current String.

## Component context

`Context[T]` is a typed key with a default value. Declare keys once, provide
values in App, and read them when building a component. Use an optional default
for required application values. Signals or model objects provide mutable state;
plain context lookup does not subscribe or make construction-time styles reactive.

```mbt nocheck
///|
let count_context : @skerry.Context[@skerry.Signal[Int32]?] = Context(None)

///|
fn application() -> @skerry.App {
  @skerry.App(
    providers=[count_context.provide(Some(@skerry.signal(0)))],
    content=app_view,
  )
}

///|
fn app_view() -> @skerry.View {
  let count = count_context.get().unwrap()
  @skerry.text_of(count)
}
```

App installs root providers and resolves its initial theme before building content.
Each mount owns its bindings, subscriptions and cleanup. A binding may contain a
ready service handle; its resource ownership stays with the caller. The App copies
its provider list, while supplied signals and model objects retain their identity.

Use `provide([key.provide(value)], fn() { ... })` inside a component builder for
a nested override. The nearest owner wins and siblings remain independent.
The helper does not add a layout node. Without an active scope, provide is a
temporary lexical operation and cleans up on return. Build live UI providers
inside App or an explicitly managed Scope.

Input callbacks restore their component scope. Callback-created effects and
deferred work share its lifetime; dynamic branch removal stops their subscriptions.
Input dispatched by another root uses that root instead of a captured foreign
root. Already built values and captured model handles are not rebound when a View
is reused. Read a model once during construction and pass its signals to controls.
Context defaults are also returned outside a live scope or after disposal.

## Themes

Theme support is built into App. `App(content=...)` defaults to `ThemeMode::System`:
SDL reads the system color scheme before building content and handles later theme
change events. An unknown scheme uses the built-in light theme while the selected
preference remains System. Applications need no theme signal, getter or effect.

`ThemeMode` is the preference (`Light`, `Dark`, `System`); `Theme` is the immutable
resolved visual value. App owns its mode and themes. To start with a fixed preference,
use `App(theme_mode=Dark, content=...)`. `app.set_theme_mode(...)` changes it for all
roots mounted by that App. Equal modes request no work; each host retains its own
system scheme. A change from the host does not overwrite the chosen preference.

Components can read the App through context and offer an optional mode selector:

```mbt nocheck
@skerry.App(content=fn() {
  @skerry.button("Use system theme", on_click=fn() {
    @skerry.current_app().set_theme_mode(System)
  })
})
```

`current_app()` reads the existing App from the current component context and
requires a live App scope. Lookup itself does not create a reactive subscription.
`app.theme_mode()` tracks inside effects and reactive getters such as `text(bind(...))`.
The basic example cycles Light/Dark/System
and reads the current mode without managing a separate signal or provider.

`Theme` contains the default font, token assignments and concrete component defaults. Built-in and custom colors share the same token
collection. `Palette` is an input preset that fills the built-in keys, rather
than a separate color store in Theme. App and subtree scopes
accept separate `light_theme` and `dark_theme` properties. App chooses the active
variant automatically; a missing variant uses its corresponding built-in theme.
No theme bundle or selection callback is required.

```mbt check
///|
test {
  let dark = @skerry.Theme(
    palette=@skerry.Palette::dark(),
    styles=@skerry.Styles().add(
      @skerry.TextInputStyle()
      .focused(@skerry.Appearance().stroke(@skerry.Color::white(), width=2.0))
      .placeholder(@skerry.TextStyle().color(@skerry.muted_text_token)),
    ),
  )
  ignore(@skerry.App(dark_theme=dark, content=@skerry.empty))
}
```

App follows System by default, with no application signals or selection callback.
`current_color_scheme()` and `root.color_scheme()` report concrete Light or Dark,
independently of whether the corresponding Theme values happen to be equal.
Each root retains its own host scheme.

Styles accept both literal colors and typed theme tokens through the same setters.
Literal colors stay fixed. Token references resolve in the consuming view's
nearest theme, so one BoxStyle can be reused in several themes. `Appearance`,
component marker/caret/selection/placeholder colors and `ScrollbarStyle` accept
the same inputs. No `val`, `bind` or computed is needed for these references.

```mbt check
///|
pub let notice_color : @skerry.ThemeToken[@skerry.Color] = ThemeToken(
  "NoticeColor",
  fallback=@skerry.Color::rgb(r=180, g=110, b=30),
)

///|
test {
  let shared = @skerry.BoxStyle()
    .background(@skerry.accent_token)
    .color(@skerry.on_accent_token)
    .stroke(notice_color)
  let fixed = @skerry.BoxStyle().background(
    @skerry.Color::rgb(r=150, g=50, b=60),
  )
  let light = @skerry.Theme().token(notice_color, @skerry.Color::black())
  let dark = @skerry.Theme(palette=@skerry.Palette::dark()).token(
    notice_color,
    @skerry.Color::white(),
  )
  ignore(
    @skerry.App(light_theme=light, dark_theme=dark, content=fn() {
      @skerry.column() <| [
        @skerry.button(
          "Theme color",
          style=@skerry.ButtonStyle().surface(shared),
        ),
        @skerry.button(
          "Fixed color",
          style=@skerry.ButtonStyle().surface(fixed),
        ),
      ]
    }),
  )
  assert_eq(dark.resolve(notice_color), @skerry.Color::white())
}
```

Custom tokens are optional: use them for shared semantic color roles. A concrete
component style already exposes its parts; configuring a part does not require
a new token. For example, CardStyle can set its border directly or reference the
built-in accent_token.

Declare custom token keys once alongside the code that owns their role and import
those keys in theme packages. Names are diagnostic: constructing a second token
with the same name creates a different key. A missing custom assignment uses the inherited
value, then the token's literal fallback. ThemeToken is generic; the supported
value kind in this release is Color. Numeric/font references will be added with
support in their corresponding layout properties.

Token assignments compare by key and value, independently of insertion order.
ThemeToken supports hashing while retaining identity-based equality;
separately declared keys with the same name remain distinct in maps and sets.

Built-in keys are `surface_token`, `control_surface_token`, `text_token`,
`muted_text_token`, `accent_token`, `on_accent_token`, `border_token`,
`selection_token`, `scrollbar_track_token` and `scrollbar_thumb_token`. They use
the same identity, assignment, lookup and fallback rules as custom keys.
`Theme()` fills them from the default light Palette; `Theme(palette=...)` fills
them from a chosen preset. Supplied `tokens=` values apply after that preset.
There is one stored collection, `theme.tokens`, and `theme.resolve(key)` reads it.
Missing keys use their literal fallback. Passing a resolved color to BoxStyle stores
a literal, not a theme dependency.

`theme.token(key, color)` replaces one assignment. `theme.palette(preset)` writes
the preset's built-in assignments into that same collection, retaining custom
keys, fonts and styles. Later assignments take priority:

```mbt check
///|
test {
  let red = @skerry.Color::rgb(r=180, g=40, b=50)
  let theme = @skerry.Theme()
    .token(notice_color, red)
    .palette(@skerry.Palette::dark())
    .token(@skerry.accent_token, red)
  assert_eq(theme.resolve(@skerry.accent_token), red)
  assert_eq(theme.resolve(notice_color), red)
}
```

`style_scope(light_theme?, dark_theme?, styles?, inherit_styles?=true)` is the
single subtree provider. Its content runs once, keeps node identity and adds no
layout box. Each supplied Theme replaces base defaults for that scheme. Missing
variants inherit the parent base theme for the current scheme; they never select
the opposite variant. Additional outer style declarations continue to apply.
`styles=Styles(...)` appends a later layer. Set `inherit_styles=false` to discard
outer additional declarations while retaining the selected base Theme's own Styles.

```mbt check
///|
test {
  let light = @skerry.Theme(palette=Palette(accent=@skerry.Color::black()))
  ignore(
    @skerry.App(content=fn() {
      @skerry.style_scope(light_theme=light) <| fn() {
        @skerry.button("Custom light theme; inherited dark theme")
      }
    }),
  )
}
```

Both App and style_scope accept a plain Theme, Signal[Theme], Computed[Theme], or
Binding[Theme] through the ThemeSource conversion trait. Plain themes retain a
constant value without creating a computation. Only the selected variant's source
is read and tracked, and switching schemes releases the previous dependencies.
Sources are evaluated in the consuming lifetime, not by snapshots or painters.
A shared Binding has an independent subscription for each mounted consumer.

To derive from the parent, use an ordinary binding in the subtree's parent scope.
`current_theme()` returns the effective parent theme, including its component defaults.
When copying that whole theme, set `inherit_styles=false` to avoid appending those
same additional declarations again. Assign the binding to one variant to change
only that scheme, or to both variants for a shared transformation:

```mbt check
///|
test {
  ignore(
    @skerry.App(content=fn() {
      let font_theme = @skerry.bind(fn() {
        let parent = @skerry.current_theme()
        { ..parent, font: parent.font.size(18.0), }
      })
      @skerry.style_scope(
        light_theme=font_theme,
        dark_theme=font_theme,
        inherit_styles=false,
      ) <| fn() { @skerry.button("Parent palette, larger font") }
    }),
  )
}
```

Subtree themes merge the parent's assignments with their own; the child's values
take priority for every key. A complete child Theme supplies its own built-in
colors from its initial preset, while missing custom assignments inherit. A record
update retains the copied token values. At App level, construct sources from explicit Theme values or
application models; the App establishes its root theme itself.

Theme changes preserve models, node IDs, focus, pointer capture and selection.
Effective metric/font changes request layout; color changes request paint and
retain layout/text caches. Repeating equal resolved state requests no work.
Paint, scrollbar input and computed styles share the same node theme and geometry.
`specified_style` retains token references; `computed_style` contains concrete RGBA.
A ScrollbarSnapshot similarly records the declared `style` alongside concrete
`track_color` and `thumb_color` used to paint it.

`current_theme()` reads the effective value during construction, effects and
callbacks, or defaults outside a live scope. The accessor creates no effects;
its signal read tracks when an effect is active. Custom painters receive
`PaintContext.theme` and `PaintContext.font` for their painted node.

Custom App hosts pass their initial scheme to `App.mount`, then call
`root.set_system_theme(Some(scheme))` for changes; None means unknown and resolves
to Light in System. Low-level `mount(theme=..., color_scheme=...)` does not create
an App. `root.set_theme(value)` retains its current scheme; pass `color_scheme=`
to publish both atomically. Dark Palette values alone do not infer a Dark scheme.
Custom LayoutState hosts forward `on_theme_change` to `set_theme_override` and
request a frame when it returns true; `needs_layout()` distinguishes metric changes.

Controls resolve built-in token defaults and automatic interaction feedback,
then declarations of the matching concrete type in order, then the local style.
Each declaration applies its normal properties followed by its active states.
Disabled normal colors fade once; explicit disabled colors remain literal.

`CheckboxStyle` and `RadioStyle` contain `indicator: BoxStyle`, `label: TextStyle`
and an independent `marker_color`. Their `frame` sets the whole control's metrics
and shared defaults; `gap` sets the space before the label. Indicator
width and height participate in measurement and painting. TextInput has `surface`,
`text`, `placeholder`, `caret_color` and `selection_color`. Placeholder font,
alignment and state color are independent of the edited text. Unspecified part
colors use built-in tokens. Normal fonts affect layout; state overrides remain
paint-only. Radio indicators keep a rounded shape.

Box/FillBox and the SDL window background use `surface_token`; Text uses
`text_token`. Omitted scrollbar styles use track/thumb tokens with
the existing geometry defaults. An explicit `ScrollbarStyle` keeps its complete
appearance. `WindowOptions.clear` is optional: omitted clear follows the root's
surface at each SDL paint, while an explicit color stays fixed. Custom renderer
hosts continue to supply their clear color.

Custom painters receive `PaintContext.theme`. `UiSnapshot.theme` describes the
completed paint; computed styles include resolved marker, placeholder, caret and
selection colors. Snapshot reads never invoke custom painters or control getters.

### Concrete component styles and defaults

Factories accept their concrete styles: ButtonStyle, TextInputStyle,
CheckboxStyle, RadioStyle and TextStyle. Rows, columns and radio-group containers
use FlexStyle. BoxStyle is the reusable surface/frame fragment. FlexStyle owns
spacing/justify_content/align_items; grow/shrink/align_self describe an item and
remain in the common box fragment.

Style constructors take no arguments. Configure properties and parts through
methods, for example `ButtonStyle().surface(shared).label(label)`. Repeated
fragment setters merge their supplied fields; omitted properties stay unchanged.

```mbt check
///|
test {
  let surface = @skerry.BoxStyle().radius(12.0).height(44.0)
  let label = @skerry.TextStyle().color(@skerry.text_token)
  let field = @skerry.TextInputStyle()
    .surface(surface)
    .text(label)
    .placeholder(@skerry.TextStyle().color(@skerry.muted_text_token))
    .caret_color(@skerry.accent_token)
  ignore(@skerry.text_input(placeholder="Name", style=field))
  ignore(
    @skerry.button(
      "Save",
      style=@skerry.ButtonStyle().surface(surface).label(label),
    ),
  )
  ignore(
    @skerry.column(
      [],
      style=@skerry.FlexStyle().spacing(12.0).padding(@skerry.Insets::all(16.0)),
    ),
  )
}
```

The style's concrete type selects its defaults. No class declaration, key or
registration accompanies a component. A theme contains different style types in
one ordered collection:

```mbt check
///|
test {
  let styles = @skerry.Styles()
    .add(
      @skerry.ButtonStyle().surface(
        @skerry.BoxStyle().height(44.0).radius(22.0),
      ),
    )
    .add(
      @skerry.TextInputStyle().surface(
        @skerry.BoxStyle().height(44.0).radius(12.0),
      ),
    )
    .add(@skerry.FlexStyle().spacing(12.0))
  ignore(
    @skerry.App(
      light_theme=@skerry.Theme(styles~),
      dark_theme=@skerry.Theme(palette=@skerry.Palette::dark(), styles~),
      content=fn() {
        @skerry.column() <| [
          @skerry.text_input(placeholder="Name"),
          @skerry.button("Save"),
        ]
      },
    ),
  )
  let buttons : ReadOnlyArray[@skerry.ButtonStyle] = styles.get()
  assert_eq(buttons.length(), 1)
}
```

Both row and column consume FlexStyle defaults. Unrelated nominal style types
remain distinct even when their fields have the same shape. `Styles.get()` uses
its expected result type and returns original declarations in source order.
`merge` appends declarations into a new collection; repeated declarations remain
separate normal/state layers. Later normal values override earlier active states.
Local declarations follow defaults. Setters and merge preserve omitted fields
and explicit zero values.

A standalone TextStyle controls its frame and item participation. Inline label
and placeholder styles supply typography and paint states; their component's
surface/frame controls outer layout. Indicator size, choice gap and placeholder
font participate in measurement. Appearance/TextAppearance state overrides remain
paint-only.

`style_scope(styles=...)` appends defaults for a subtree while following its
parent's font, tokens and Light/Dark selection. A nested scope can override either
scheme or set inherit_styles=false to isolate inherited defaults:

```mbt check
///|
test {
  ignore(
    @skerry.App(content=fn() {
      @skerry.style_scope(
        styles=@skerry.Styles().add(
          @skerry.ButtonStyle().surface(@skerry.BoxStyle().radius(12.0)),
        ),
      ) <| fn() { @skerry.button("Save") }
    }),
  )
}
```

Custom and built-in component styles share StyleSpec: Eq, Debug and a required
merge method. Parameterless constructors start with unset fragments; field setters and merge
compose explicitly supplied properties, preserving omitted fields and zero values.
Empty styles derive Default from their fields; constructors delegate to Default::default(),
so adding a field does not require updating the constructor. Styles with configured
defaults, such as ScrollbarStyle, implement Default explicitly.
A composition implements merge for its fields and projects them into ordinary style arguments:

```mbt check
///|
#derive(Eq, Debug, Default)
pub struct CardStyle {
  surface : @skerry.FlexStyle
  title : @skerry.TextStyle
}

///|
pub fn CardStyle::CardStyle() -> CardStyle {
  Default::default()
}

///|
pub fn CardStyle::surface(
  self : CardStyle,
  value : @skerry.FlexStyle,
) -> CardStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
pub fn CardStyle::title(
  self : CardStyle,
  value : @skerry.TextStyle,
) -> CardStyle {
  { ..self, title: self.title.merge(value), }
}

///|
pub impl @skerry.StyleSpec for CardStyle with fn merge(self, other) {
  {
    surface: self.surface.merge(other.surface),
    title: self.title.merge(other.title),
  }
}

///|
pub extend CardStyle with @skerry.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
pub extend CardStyle with Eq::{equal, not_equal}

///|
pub extend CardStyle with Debug::{to_repr}

///|
pub fn card(
  title : String,
  body : @skerry.View,
  style~ : CardStyle,
) -> @skerry.View {
  @skerry.column(
    [@skerry.text(title, style=style.select(s => s.title)), body],
    style=style.select(s => s.surface),
  )
}

///|
test {
  let style = CardStyle()
    .surface(@skerry.FlexStyle().padding(@skerry.Insets::all(16.0)))
    .title(@skerry.TextStyle().color(@skerry.accent_token))
  ignore(
    @skerry.App(light_theme=@skerry.Theme(styles=@skerry.Styles().add(style)), content=fn() {
      card("Title", @skerry.text("Body"), style=CardStyle())
    }),
  )
}
```

`select` preserves the dependency between a composite style and its typed child
style. It creates no View and does not rebuild the component. Rule lookups are
shared by concrete family; unrelated font/token/theme changes do not re-run pure
selectors. Signal reads inside a selector are tracked by its mounted consumer.
Paint and snapshots read materialized data and never invoke selectors.

Numeric bounds, grow/shrink and flex spacing accept constants, Signal[Double],
Computed[Double] or Binding[Double] directly. An entire built-in style can use
its `computed` constructor:

```mbt check
///|
test {
  let width = @skerry.signal(120.0)
  let spacing = @skerry.computed(fn() { width.get() / 10.0 })
  let style = @skerry.TextStyle::computed(fn() {
    @skerry.TextStyle().color(
      if width.get() > 100.0 {
        @skerry.Color::white()
      } else {
        @skerry.Color::black()
      },
    )
  })
  ignore(
    @skerry.column(
      [
        @skerry.text("Live", style~),
        @skerry.box(style=@skerry.BoxStyle().width(width).height(24.0)),
      ],
      style=@skerry.FlexStyle().spacing(spacing),
    ),
  )
}
```

A plain custom composite can select its fields using only StyleSpec. To receive
a projection as that custom type, or provide its own computed constructor, opt
into SourceStyle: add one optional StyleSource[Self] field, implement
StyleSpec.split_source and SourceStyle.with_source, and wrap the existing
field-wise merge with merge_sources. These are whole-type hooks; no property
keys, field descriptors, generated getters, codecs or code generator are needed.
The examples/theming/CardStyle stays a plain composite; it needs no source hooks.
As with regular Computed, a whole-style computed shares one cache. Capture model
handles for shared computations; use Type::bind(bind(...)) for expressions that
must read providers separately in each mounted consumer.

Leaf style implementations can override StyleSpec.root_style for common root
properties and metrics for extra intrinsic dimensions/fonts. Component-specific
paint data stays in the concrete type, beside its factory and painter. StyleSpec
requires merge and has no payload codec or registration methods. StyleDeclaration retains the
concrete value; get() retrieves it by its expected type. Storage uses a private
runtime type boundary, covered by native debug and release tests.

The examples/theming package contains the complete CardStyle and component,
separate light/dark theme functions and App configuration. It imports only the
Skerry facade. Theme updates preserve models, node IDs, focus and selection;
colors request paint, effective metric changes request layout.

```sh
moon run examples/theming
```

A theme package imports the component style types and returns ordinary Theme
values. An existing app connects them directly:

```mbt nocheck
App(light_theme=@material.light(), dark_theme=@material.dark(), content=app_view)
```

## Control states

`Appearance` is the shared visual fragment for normal styles and control states:
background, text color, radius and stroke. Compose the normal appearance with
`BoxStyle().appearance(fragment)`. The `background`, `color`, `radius` and `stroke`
setters override individual fields. Combine existing styles with `BoxStyle.merge`;
only explicitly supplied fields in the later style override earlier values.

```mbt nocheck
///|
let surface = @skerry.Appearance()
  .background(@skerry.Color::accent())
  .radius(6.0)

///|
let base = @skerry.BoxStyle().appearance(surface).width(120.0)

///|
let adjusted = base.background(@skerry.Color::black())

///|
let combined = base.merge(
  @skerry.BoxStyle().appearance(
    @skerry.Appearance().stroke(@skerry.Color::white()),
  ),
)
// Both derived styles preserve base's radius and width.
```

Buttons, checkboxes, radio buttons (including radio groups) and text inputs have
hover, pressed, focused and disabled appearances. Use paint-only overrides on
`BoxStyle`; their colors, radius and stroke widths do not change layout or hit geometry:

```mbt nocheck
///|
let button_style = @skerry.ButtonStyle().surface(
  @skerry.BoxStyle()
  .background(@skerry.Color::accent())
  .stroke(@skerry.Color::black(), width=1.0)
  .hovered(
    @skerry.Appearance().background(@skerry.Color::rgb(r=40, g=130, b=230)),
  )
  .focused(@skerry.Appearance().stroke(@skerry.Color::black(), width=2.0))
  .pressed(
    @skerry.Appearance().background(@skerry.Color::rgb(r=20, g=90, b=180)),
  )
  .disabled(
    @skerry.Appearance()
    .background(@skerry.Color::rgb(r=220, g=225, b=235))
    .color(@skerry.Color::rgb(r=100, g=110, b=125)),
  ),
)
```

Enabled controls first resolve component defaults for active states, including
the focus outline. Buttons, checkboxes, radio indicators and Select options also
adjust their default background on hover/press: dark colors become lighter and
light colors become darker, preserving alpha. This follows the resolved color,
including custom token values. Text inputs and the Select field keep their
background steady; their border still indicates hover/focus. Text input text
colors also stay steady while hovering, focusing and selecting text.
Explicit base properties then apply, followed by explicit
active-state overrides in order: hovered,
focused, pressed. Unset fields preserve the earlier result. A background set on
the base stays literal on hover/press; set state backgrounds for custom feedback.
Explicit hover properties also survive focus/press defaults, until an explicit
later-state property overrides them.

Disabled controls, including descendants of a disabled ancestor, resolve the
normal appearance, fade its colors to 45% alpha, and apply explicit disabled
overrides. Other state overrides do not participate. Explicit disabled colors
replace the fade literally. `stroke(..., width=0.0)` hides the outline, including
the default focus stroke when applied to an active state or the base.
Checkbox/radio background and stroke apply to the indicator, and `color` applies
to the label. Radius applies to buttons, checkbox indicators and text inputs;
radio radius follows the indicator size. The text input placeholder keeps its separate
default color. `BoxStyle.merge` merges each state's explicitly set fields.
Repeated `hovered`, `pressed`, `focused` and `disabled` calls use the same rule:
independent properties accumulate, and the last explicitly supplied value wins.
An empty `Appearance()` preserves earlier overrides.

```mbt nocheck
///|
let base = @skerry.BoxStyle().hovered(
  @skerry.Appearance().background(@skerry.Color::accent()),
)

///|
let extended = base.hovered(@skerry.Appearance().color(@skerry.Color::white()))
// Both hover background and text color are retained.
```

An unset property in a merge patch means "keep the previous value". An empty
`BoxStyle()` does not reset explicit width/height to auto or remove state overrides.

State belongs to each mounted root, even with shared Views. A pointer press stays
captured when dragged outside, but its pressed appearance clears until the
pointer returns. Release activates only over the same live target. Focus loss,
removal, disabling and cancellation end the press. Enter/Space activation retains
key-down semantics, with its pressed appearance lasting until matching key-up or
blur. Custom painters receive `PaintContext.state`; `PaintContext.focused` remains
available. Snapshots expose the last painted `NodeSnapshot.state` and the same
resolved palette used by the painter.

Custom hosts should send `pointer_move` even without capture, `pointer_leave` when
the pointer leaves the host, `key_up` when releasing a key, and `focus_lost` on
window blur. Mouse leave clears hover and preserves capture. The SDL backend
handles these events. `pointer_move`'s return value still reports capture dispatch;
hover updates can request a frame even when it returns false. Repeated moves
inside one target do not request frames, and states need no polling or timers.

## Typography

`Theme.font` supplies the default `FontSpec` for text, button labels, checkbox and
radio labels, and text input values and placeholders. Configure it in an App's
light/dark themes or a `style_scope(light_theme=..., dark_theme=...)` subtree. The default remains 16px.

```mbt check
///|
test "theme and inherited fonts" {
  let body = @skerry.FontSpec::default().size(18.0)
  let app = @skerry.App(
    light_theme=@skerry.Theme(font=body),
    dark_theme=@skerry.Theme(font=body, palette=@skerry.Palette::dark()),
    content=fn() {
      @skerry.column([
        @skerry.text("Inherited 18px body"),
        @skerry.column(
          [
            @skerry.text("Inherited 24px section"),
            @skerry.button("Also 24px"),
            @skerry.text("Local override", style=@skerry.TextStyle().font(body)),
          ],
          style=@skerry.FlexStyle().font(body.size(24.0)),
        ),
      ])
    },
  )
  assert_eq(app.options().title, "Skerry")
}
```

The closest explicit `BoxStyle.font` wins. It applies to descendants, including
through ScrollView, Stack, dynamic branches, keyed entries and themed subtrees.
Without an explicit ancestor font, the closest theme supplies its default.
A scoped theme can retain its parent's colors and change just the font:

```mbt nocheck
let large = @skerry.signal(false)
let font_theme = @skerry.bind(fn() {
  let parent = @skerry.current_theme()
  { ..parent, font: parent.font.size(if large.get() { 22.0 } else { 16.0 }), }
})
@skerry.style_scope(
  light_theme=font_theme,
  dark_theme=font_theme,
  inherit_styles=false,
) <| fn() {
  @skerry.column([@skerry.text("Body"), @skerry.button("Action")])
}
```

Font changes recompute measurement and layout without rebuilding components or
resetting their state, focus, text or selection. Paint, caret hit testing and
`computed_style.font` use the same resolved font. Measurements for previous fonts
remain cached. Changes limited to palette/appearance retain layout. The basic
example includes an interactive text-size control.

`FontSpec` currently describes size; the backend owns the font resource.
Inherited font does not scale explicit pixel dimensions, padding or indicators.
Containers' colors and text alignment do not inherit.

## Where style properties apply

Common fragments contain geometry, appearance, inherited font defaults and item
participation. Concrete component styles determine how their parts consume these
fragments. Container arrangement belongs to FlexStyle.

| View | Style | Parts and layout |
|---|---|---|
| Text | TextStyle | Font/color/alignment, frame padding and item bounds |
| Box/FillBox | BoxStyle | Surface and frame properties |
| Row/Column | FlexStyle | Surface/frame, spacing and child arrangement |
| ScrollView | BoxStyle | Viewport surface/padding; child controls content layout |
| Button | ButtonStyle | Surface and label |
| Checkbox/Radio | CheckboxStyle/RadioStyle | Frame, label, indicator size/appearance, gap and marker |
| TextInput | TextInputStyle | Surface, edited text, placeholder, caret and selection |

Stroke is an overlay and reserves no layout space. Containers can draw an outline
without a background; radius rounds the painted surface, without clipping children.

`grow`, `shrink`, min/max bounds and `align_self` apply to styled built-ins through
the shared layout adapter. `justify_content` and `align_items` apply to Row/Column.
The host owns root allocation. Stack and Custom currently use their own composition
or painter contracts; they have no ordinary `style` argument.

## Keyed lists

`for_each(items, key, render)` retains each entry's view and local state when its
key is reused or reordered. The render callback receives a reactive getter
(`() -> T`) for the current entry, so a changed value with the same key can update
both text and event callbacks:

```mbt nocheck
///|
fn list_view() -> @skerry.View {
  let entries = @skerry.signal([(1, "First"), (2, "Second")])
  @skerry.column([
    @skerry.for_each(fn() { entries.get() }, fn(entry) { entry.0 }, fn(entry) {
      @skerry.interactive(@skerry.text(@skerry.bind(fn() { entry().1 })), on_click=fn() {
        println(entry().1)
      })
    }),
    @skerry.button("Update", on_click=fn() {
      entries.set([(2, "Second updated"), (1, "First")])
    }),
  ])
}
```

Use `entry()` to read the value, and read it inside `text(bind(...))`, `show`, or an event
callback when subsequent updates matter. A value captured once while building
the entry remains a snapshot. Keep keys unique for identity to follow each item;
repeated keys are matched in occurrence order and their state follows that order.

## Reactive lifetimes

Subscriptions created in the `mount` builder belong to that root. Each visible
`show` branch and each `for_each` entry owns its `effect`, `watch` and
`render_effect` subscriptions. Hiding a branch, removing an entry or disposing
the root stops those subscriptions. Showing the branch again creates a fresh
lifetime; updating or reordering an entry with the same key preserves its
subscriptions. Roots have independent lifetimes.

`on_cleanup` called while building a component runs when that component is
removed. Inside an effect, it runs before the next execution and at final
disposal. Each registration runs once, and signal reads in cleanup do not
subscribe the effect. Effect and cleanup callbacks keep their original scope
even when another component triggers the update. Descendant scopes finish
cleanup before their parent.

Effects and watches return an idempotent disposer for early cancellation.
Effects created outside a UI scope require manual disposal. Registering
`on_cleanup` outside a component or effect has no lifetime to attach to.

On native, `effect` and `render_effect` run immediately on creation and
synchronously after dependency changes. `watch` records its initial value and
calls its callback with `(new_value, old_value)` on subsequent changes.
`batch` defers dependent reruns until the outermost batch finishes; it does not
delay the initial execution of a newly created effect. UI state and reactive
callbacks run on the UI thread. Layout and painting occur when the backend
processes the resulting dirty root.

## Frames and diagnostics

The SDL backend processes queued input and synchronous reactive updates before
layout, paint and presentation. Requests accumulate in `DirtyState`: layout
takes priority over paint, and multiple updates can be rendered in one frame.
An update during measurement or painting requests a following frame. Calling
`paint` recursively also requests a following frame.

When there is no pending work, the backend waits for an SDL event without a
periodic polling timeout. Expose presents the cached frame; resize callbacks
can render synchronously during a platform modal resize loop. Before waiting,
the backend finishes pending texture shrinking. Disposing the root cancels
pending frames and stops the application loop.

`UiRoot::frame_stats()` returns cumulative `layout_count`, `paint_count` and
`present_count`, plus `presented_frame`. Layout cache reuse does not increase
`layout_count`; the count includes computations requested by hit testing.
`paint_revision()` returns the completed paint count used to label host buffers.
`presented_frame` identifies the buffer most recently presented by the host,
which can be older than the latest painted frame. Presenting a cached frame
increases `present_count` without increasing `paint_count`.

`observe_frames(callback)` attaches one observer, replacing the previous one.
It reports `Invalidated(DirtyState)`, `Painted(FrameStats)` and
`Presented(FrameStats)`. Statistics contain copied values; reading them does
not request a frame. Callbacks run untracked in an independent scope, and
nested notifications are suppressed. The returned disposer detaches that
registration; root disposal also releases it. Without an observer, event
snapshots are not built.

`frame_stats()` includes root totals for `layout_count`, `layout_pass_count` and
`text_measure_count`. A layout computation can run several Crater passes to resolve
wrapped heights. Text measurements count actual `TextMetricsProvider` calls, not
text nodes or layout requests; wrapping can invoke the provider many times.
Provider internals and renderer-native work outside this contract are not counted.
Each mounted root has an independent text measurement session, even with a shared
view/provider. Counts also include work requested by input. Counters use the same
wrapping `Int` behavior as the existing frame counters.

`last_paint: PaintStats?` contains counts for the last completed root paint call,
identified by `paint_count`; it is `None` before the first paint. Earlier input
layout is in the root totals but not in this paint's counts. Paint-only updates
reuse geometry; text paint can still measure text. Statistics reflect that work
rather than assume it was cached. Only the latest small value record is retained,
and previously captured records remain readable after updates/disposal.

Pass `timings=true` to `observe_frames` to enable `last_paint.layout_ms` and
`paint_ms` using the root's monotonic millisecond clock. Layout time includes tree
construction, text measurement and reflow. Paint time includes clear/drawing and
its text work, excluding layout. Observer delivery, scheduling, present and
backend-internal asynchronous work are outside these timings. A cached layout
contributes zero layout time. Nested layout work is timed once.

```mbt nocheck
///|
let stop = root.observe_frames(
  fn(event) {
    if event is @skerry.Painted(stats) && stats.last_paint is Some(paint) {
      println("layout: \{paint.layout_ms}, paint: \{paint.paint_ms}")
    }
  },
  timings=true,
)
```

Timing is disabled by default. Detachment, replacement without `timings=true`
and root disposal stop profiling clock reads. A registration change during paint
leaves that paint's timings `None`, rather than publishing partial durations.
Attaching/detaching or reading diagnostics keeps idle roots idle; clocks run
untracked and reads never call metrics, application getters or the clock.
Repeated present changes only present totals, retaining the last paint's record;
`last_paint` belongs to `paint_count`, even when `presented_frame` labels an older
buffer. Hosts should use those labels to correlate painted and presented data.

### Text caches

Each text session retains two LRU caches: metrics by `(text, FontSpec)` and layout
by `(text, FontSpec, max_width)`. Layout and paint share the mounted root's session;
caret hit testing uses it too. Text, font and width changes select matching entries,
and ordinary geometry invalidation keeps useful text data. Roots and standalone
sessions have independent caches, counters and policies.

Limits are 256 metric entries and 64 layout entries, each with a 256 KiB accounted
payload budget. Payload covers UTF-16 strings, caret doubles and line values;
fixed records, map/allocator overhead and transient computation/results are
outside this accounting. Both entry counts and retained payload are bounded.
Oversized entries are used without retention and do not flush useful cached data.
LRU eviction may make a later request measure again. Cold wrapping/shaping costs
are not eliminated by caching, and this does not introduce grapheme/bidi shaping.

`FrameStats.text_cache` exposes `enabled`, cumulative `measure_hits`/`layout_hits`
and `evictions`, current `measure_entries`/`layout_entries` and `payload_bytes`.
`text_measure_count` still counts actual provider calls, excluding cache hits.
Read/observe diagnostics does not access cache entries or change their LRU order.
Public result arrays are copied independently of retained metrics/layout data;
changing `lines` or `caret_positions` cannot corrupt future cache hits. Caches
retain text/font/value data, with no node, scope, callback or native pointer entries.

Caching is enabled by default and assumes stable provider metrics for text/font.
For a provider whose results depend on changing external state, use
`TextLayoutSystem::from_metrics(provider, cache=false)`. A standalone session can
change its policy with `set_cache_enabled`; new sessions inherit the current policy,
while already mounted sessions keep their own. Caches do not track reactive reads
made inside a provider or infer resource changes.

After external font/scale resources change, call `root.invalidate_text()`: it clears
text caches, invalidates geometry and requests a frame through normal scheduling.
Repeated invalidations coalesce. Standalone systems use `clear_cache()`; custom
hosts using `LayoutState::clear_text_cache()` also invalidate their geometry.
Clearing preserves cumulative counters and prevents in-flight pre-clear results
from being stored. Unmount releases retained text/geometry and disables further
cache filling by in-flight work. Old diagnostic values remain readable.

Custom hosts use `needs_frame()` and `is_disposed()` to control their loop.
After successfully presenting a buffer, call `record_present(frame)` with
the `paint_revision()` captured for that buffer.

## Diagnostic snapshots

`UiRoot::snapshot()` returns an immutable `UiSnapshot` for a consistent completed
paint, or `None` when the root is disposed, has pending frame work, has not painted
yet, is delivering actions/present callbacks, or its layout changed since paint.
Reading never computes layout, calls application getters or requests a frame.
Repeated reads use the cached projection and do not add reactive subscriptions.

Selection uses `(snapshot.root_id, node.id)`. Keyed reorder preserves node IDs;
newly constructed instances receive fresh IDs. Logical `fragment`, `show` and
`for_each` regions remain visible. `tree.nodes` is a read-only preorder list with
explicit parent and child IDs, logical kinds, frame/content geometry,
padding/border, effective clips, scroll viewport/extent/offset and input capabilities.
Geometry uses the same projection and root coordinates as
paint and input. Disabled state includes ancestors; focusable/hit-testable flags
describe each node's own capabilities. Interactive decorators preserve identity
and the underlying kind.

`snapshot.frame.paint_count` identifies the painted tree. `presented_frame` and
`present_count` record the host's present state at capture time; a host can still
be showing an earlier buffer. Returned values contain no callbacks, signals,
native pointers or live nodes, and remain readable after removal/root disposal.
The root retains no snapshot history.

`observe_snapshots(callback)` attaches one observer and returns an idempotent
disposer. It immediately delivers an available snapshot, then delivers after each
consistent paint's `Painted` notification. Values are captured before that frame
observer can mutate the application. Paints invalidated during measurement or
drawing do not publish a mixed snapshot; a subsequent consistent paint does.
Cached presents do not duplicate tree notifications; use `observe_frames` for
present updates. Replacing/detaching the observer disposes its independent scope.
Callbacks run untracked, and nested painting/action/present delivery is blocked.

Attachment, reads and detachment keep idle roots idle. Without an attached
observer or explicit query, no diagnostic tree is built. Neutral value types live
in `klaseca/skerry/diagnostics` and are re-exported by the root facade; this is the
foundation for an optional inspector addon. Inspector UI, detailed invalidation
traces and additional phase timings are subsequent steps.

### Component boundaries and diagnostic metadata

`View::component(name)` adds a named virtual component boundary before passing the
result to a parent or mounting it. The name is a required positional argument.
Each call creates a distinct diagnostic boundary, including repeated equal names.
The returned view retains the same UI node, children, layout, input and lifetime.
There are no extra reactive owners, callbacks or layout nodes.

`View::debug(name=..., source=...)` sets static values on the current level:
the outermost component when present, otherwise the underlying UI node. Omitted
fields preserve existing values; specified fields replace them. It returns a new
decorated handle, leaving the original handle's metadata unchanged. The same
mount-once rule applies to all aliases. `interactive`, `stack` and structural
decorators preserve metadata, including on custom controls.

```mbt nocheck
///|
let save = @skerry.button("Save").debug(
  name="save button",
  source=@skerry.SourceLocation(file="src/editor.mbt", line=42, column=5),
)

///|
let card = @skerry.column([])
  .debug(name="body")
  .component("Card")
  .debug(name="summary")
```

In this card, the actual Column has `debug_name=Some("body")`. Its first
`components` entry has `name="Card"` and `debug_name=Some("summary")`. A later
`.component("ProfileCard")` adds an outer level while retaining both values.
ComponentSnapshot records contain only stable diagnostic IDs, names, labels and
source tags. Their containing NodeSnapshot supplies geometry and UI parent/child
links; virtual levels have no independent styles, input or layout box.

`SourceLocation` stores the file path as provided and uses one-based line/column
coordinates; column is optional. Source tags are explicit values. Automatic caller
location capture is a later tooling task.

`for_each(..., key_label=formatter)` optionally labels each rendered entry root.
The formatter receives the key and runs once when that entry is constructed,
untracked in its component scope. Payload updates and reorder retain the saved
label; a newly constructed entry formats its key again. Labels do not participate
in matching, and repeated keys still use occurrence order. Keys need only `Eq`;
no `Show` or `Debug` bounds are added.

Snapshots expose `node.debug_name`, `node.source`, `node.key_label` and
`node.components` as immutable values. Key labels always describe the keyed UI
entry root, independently of any component boundaries above it. Reading/observing
snapshots never invokes the formatter or application
getters. Node labels/source and key labels remain `None` unless explicitly set;
the component list is empty when no virtual boundaries were declared. No fallback
labels are formatted. Supplying `key_label` opts into formatting during
entry construction, even before an inspector is attached; omit it in a production
composition when labels are unnecessary. Saved snapshots retain these values
after removal/root disposal without retaining the component lifetime.

These are diagnostics of the displayed composition. A boundary added to a
function's result cannot identify the signals/effects created earlier in that
function; reactive ownership remains separate. Metadata is stored during
construction so a later inspector query can read it without rerunning setup.

### Specified and computed styles

`NodeSnapshot.specified_style` retains the local concrete declaration, including
unset fields and token references. `style_type` identifies its concrete type.
Use declaration.get() with an expected type to inspect its data. Its layout field
contains cached common root properties; component-specific values remain in the
original typed value.

`computed_style` describes a painter's resolved font, main text color,
background, radius and logical text alignment, plus container spacing. Its fields
are optional when inapplicable. Effective dimensions/content/padding/border come
from the existing snapshot geometry; host sizing can override specified dimensions.
There is no style inheritance beyond the framework's current actual behavior.

`stroke_color`/`stroke_width` describe the focus-dependent visual stroke, distinct
from layout border insets. `marker_color` is the checkbox/radio marker palette;
`placeholder_color` is the text input placeholder palette. These palettes remain
available even when their decoration is not shown. Checkbox/radio backgrounds
describe the indicator fill. The computed main text color remains distinct from
the placeholder color. This is resolved style data rather than a list of drawing
commands or a signal/state dump.

Values use the same immutable specs and color/stroke rules as built-in paint.
Focus is saved with each root's painted projection, so shared views cannot mix
different roots' focus styles. Input disabling inherited from an ancestor is
reported by `node.disabled`; computed colors follow the painter's existing own
disabled-color behavior. Reading styles never calls text/value/selection getters,
custom painters, measurement or layout and does not request a frame. No computed
style records are built during ordinary painting without a snapshot query/observer.

Custom paint callbacks have no inferred computed style. A custom painter can
provide an explicit pure resolver with `Painter.with_computed_style`. Explicit
declarations remain inspectable through the element's style contract.
Editable overrides and inspector UI remain subsequent extensions.

## Deferred UI actions

`UiRoot::post(callback)` queues work and returns a cancellation function.
Callbacks run FIFO after input processing and before the following layout/paint,
in one reactive batch. Work posted by a callback waits for the next action pass.
Posting during paint also waits; it does not reenter drawing. A task that changes
no UI state does not request a paint.

Cancellation skips an action that has not started. Root disposal cancels pending
actions and disconnects its wakeup notifier. Actions posted from a component
scope are also skipped if that scope is disposed before delivery. Callbacks run
untracked under their posting scope, or the root scope when posted outside a
component; subscriptions created by them share that lifetime.

`App(on_mount=...)` provides the mounted root before the first frame, under root
ownership. Use it to post initial work or attach completion listeners, registering
their disposal with `on_cleanup`.

The SDL host wakes its waiting event loop when work arrives. Native results can
arrive through SDL's main-thread event-watch bridge and then call `post`.
`post`, timers, present callbacks, signals and roots themselves are UI-thread APIs:
a foreign producer passes native data through the bridge rather than sharing
MoonBit objects.
Skerry's wakeup event contains only a registered SDL event type; it carries no
MoonBit references or payload pointers.

`UiRoot::post_delayed(delay_ms, callback)` schedules a one-shot action and returns
a cancellation function. A non-positive delay behaves like `post`. Due timers
run after queued posts in the same reactive batch, ordered by deadline and FIFO
for equal deadlines. A timer created during a callback waits for the next action
pass, even if it has become due. Future timers do not request a paint.

`UiRoot::after_present(callback)` requests a frame and returns a cancellation
function. The callback runs once after the next successful present, including a
cached-frame present, after the `Presented` observer notification. Registration
during paint can use that frame without requesting another paint. Callbacks run
in a batch under their posting scopes; changes request a subsequent frame.
Callbacks registered during present delivery wait for another present. Cancelling
the callback does not undo an already requested frame.

Both kinds of task follow the root and posting component lifetime. Disposed
scopes are pruned on the next scheduling pass; callbacks are never delivered
after disposal. Cancellation immediately releases the pending callback. The host
recalculates its wait after adding an earlier timer or cancelling a timer.

Custom hosts install `set_wakeup(notify)`, call `drain_actions()` after input and
before rendering, and call `record_present(paint_revision)` after a successful
present. Wait only when `needs_frame()` and `has_pending_actions()` are false;
`next_action_delay()` supplies the maximum wait in milliseconds, or `None` for
an indefinite wait. Zero means an action pass is due. The SDL host uses this
deadline with `SDL_WaitEventTimeout`; a timeout resumes the loop without
dispatching the previous event again. With no work or timers, it waits indefinitely.

The notifier only wakes the loop; it must not drain the queue. Attaching it after
actions or timers were posted immediately notifies the host. Root disposal also
notifies the host so a blocked loop can exit. `mount(..., clock=...)` and
`App::mount(..., clock=...)` accept a monotonic millisecond clock for custom hosts
or deterministic tests. The default comes from MoonBit's monotonic clock.

## Text and layout

Text, button labels, checkbox labels and radio labels wrap by character at their
laid out content width. Button padding reduces the width available to its label
and contributes to the outer height. An automatic height follows the wrapped
content, including inside nested rows and columns and after resizing or reactive
text updates. Elements in a row with automatic height can stretch to the row's
height.
Checkbox and radio labels use the width remaining after their indicator and gap.

For text, controls, rows and columns, `BoxStyle.width` and `BoxStyle.height` describe the
outer frame. A row can shrink an element's width when space is limited; wrapping
uses the resulting width. An explicit height stays fixed, so content can extend
beyond a frame that is too short. The root frame uses the size passed to layout
or paint.

Text input keeps one line and scrolls its value horizontally.

Cursor movement and selection changes request paint and reuse layout and cached
text measurements. Repeated navigation at a boundary, repeated Select All, empty
edits and copying text request no frame when the visible state stays unchanged.
Replacing a selection with the same text only repaints the collapsed selection
and does not call `on_change`. Actual text changes invalidate layout because they
can change intrinsic sizing. Submit callbacks request work through their own state
changes; consuming Enter alone does not require redraw.

Mounted view reactivity owns these requests. Custom hosts connect
`View.mount_reactivity` to their paint/layout scheduling; input return values
report whether an event was handled, rather than imply layout invalidation.

`BoxStyle.grow(weight)` distributes positive free space among children of a row or
column. The default is zero. `BoxStyle.shrink(weight)` distributes a space deficit,
weighted by each child's preferred size; its default is one. `shrink(0.0)` keeps
an item from shrinking. Growth starts from the preferred size, so `grow(1.0)`
does not imply equal-sized children with different preferred sizes.

`min_width`, `max_width`, `min_height` and `max_height` constrain the outer frame
in logical UI units, including its padding. Bounds are unset by default.
Specify weights and bounds as finite non-negative values. A minimum takes precedence over a conflicting
maximum and can cause overflow. A bound can change an explicit width or height.
Bounds limit allocation; clipping remains controlled by `clip` or `scroll_view`.
The root frame always follows the host size passed to layout or paint.

Use `min_width(0.0)` to let a row child shrink below its automatic content minimum.
The corresponding main axis in a column is height. A growing ScrollView can fill
the remaining space; its content retains its natural scroll extent. The basic
example keeps its header and Run button fixed while its input and list adapt:

```mbt nocheck
///|
let input = @skerry.text_input(
  style=@skerry.TextInputStyle().surface(
    @skerry.BoxStyle().grow(1.0).min_width(0.0).max_width(600.0).height(44.0),
  ),
)

///|
let button = @skerry.button(
  "Run",
  style=@skerry.ButtonStyle().surface(
    @skerry.BoxStyle().width(120.0).height(44.0).shrink(0.0),
  ),
)

///|
let toolbar = @skerry.row(
  [input, button],
  style=@skerry.FlexStyle().spacing(12.0),
)

///|
let list = @skerry.scroll_view(
  content,
  style=@skerry.BoxStyle().grow(1.0).min_height(0.0),
)
```

`justify_content` and `align_items` position children of a `row` or `column`.
In a row, the main axis is horizontal and the cross axis is vertical; in a column
they are vertical and horizontal. `BoxStyle.align` controls text inside its frame.

- `justify_content`: `Start` (default), `Center`, `End`, `SpaceBetween`,
  `SpaceAround`, `SpaceEvenly`. Distribution uses space remaining after preferred
  sizes, grow/shrink, padding and fixed `spacing`.
- `align_items`: `Stretch` (default), `Start`, `Center`, `End`.
- `align_self`: `Auto` (default) inherits the parent's `align_items`; `Start`,
  `Center`, `End` and `Stretch` override it for one child.

Stretch fills automatic cross-axis sizes within min/max bounds. Controls and
containers with explicit cross-axis dimensions keep those dimensions. A box's
width/height supply its preferred size; use bounds or a non-stretch alignment
to constrain its cross-axis allocation.

```mbt nocheck
///|
let toolbar = @skerry.row(
  [input, button],
  style=@skerry.FlexStyle()
    .height(56.0)
    .spacing(12.0)
    .justify_content(SpaceBetween)
    .align_items(Center),
)

///|
let title = @skerry.text("Skerry", style=@skerry.TextStyle().align_self(Center))
```

The alignment enums are available from `@skerry` and `@style`. Explicit
`Start`, `Stretch` and `Auto` overrides survive the corresponding style merge, while unspecified
properties preserve the original values. `ScrollView` keeps its content anchored
at the scroll origin. Set container alignment on rows/columns inside it and use
`align_self` to place the viewport in an enclosing row/column.

`BoxStyle.merge` preserves unspecified properties and treats zero as an explicit
override. Layout properties are retained in snapshot `specified_style`, with
the resolved allocation in `frame` and `content`.

## Scrolling and clipping

`scroll_view(child, axis=Vertical, offset=signal, style=...)` displays one child
inside a bounded viewport. Its size comes from the root host or parent layout,
or from `BoxStyle.width`/`BoxStyle.height`. The child keeps its natural extent on the
scroll axis. Padding belongs to the viewport; children are clipped to its content
box. The default axis is vertical and the default offset is an internal signal.

```mbt nocheck
///|
let offset = @skerry.signal(0.0)

///|
let list = @skerry.scroll_view(
  @skerry.column(Array::makei(100, index => @skerry.text("Row \{index}"))),
  offset~,
  style=@skerry.BoxStyle().height(240.0),
)
```

Positive offsets move content toward the start. Each mounted viewport clamps
the requested signal value to its own content extent. Painting and resizing
do not write the clamped value back to the signal; wheel input writes the new
effective offset. Scrolling requests paint and reuses the layout cache.

An overlay scrollbar appears on the right for vertical scrolling or at the
bottom for horizontal scrolling. It keeps the content width/height unchanged,
uses a proportional thumb with a minimum target size, and disappears when the
content fits. The default is a 12-unit theme-colored track with an 8-unit thumb
inset by 2 units. These logical dimensions follow the display scale.
Set `scrollbar_gutter=true` to reserve the styled track thickness in layout and
child clipping. This strip remains when content fits, so its cross-axis size
stays stable. A disabled scrollbar reserves no space. Select uses this mode.
Use `ScrollbarStyle()` with methods to configure thickness, track/thumb
colors, separate corner radii and thumb inset:

```mbt nocheck
@skerry.scroll_view(
  content,
  scrollbar_style=@skerry.ScrollbarStyle().thickness(24.0).track_color(@skerry.Color::rgb(r=235, g=235, b=235)).thumb_color(@skerry.Color::rgb(r=100, g=100, b=100)).thumb_radius(3.0).thumb_inset(3.0),
)
```

Set `scrollbar=false` to hide it. Dragging keeps the grab position
within the thumb and continues outside the viewport. Pressing the track pages
once by the viewport length; holding does not repeat. Scrollbar input preserves
keyboard focus and does not activate controls underneath. Capture follows node
identity through keyed reorder and ends on cancellation, removal or focus loss.
Hosts using `LayoutState` directly pass `HitTarget.scrollbar` to each
`pointer_*_path` call for the captured press, call `LayoutState::pointer_cancel`
on cancellation, and preserve focus/suppress activation for scrollbar targets.
`UiRoot` handles this routing automatically.

The SDL backend supports fractional vertical and horizontal wheel input,
including flipped direction. It currently maps one wheel unit to 40 logical UI
units. Custom hosts call `UiRoot::scroll_at(size~, point~, delta~)` with root
coordinates and logical deltas; positive deltas scroll down/right. The deepest
eligible viewport consumes the event. At a boundary it bubbles to an enclosing
viewport; partial movement consumes the whole event. Disabled overlays block
wheel input as well as pointer input.

Tab and Shift+Tab reveal the newly focused control with minimal movement,
starting with its innermost scroll viewport. Padding and static clips are
respected; an oversized control keeps an already visible region. Manual
scrolling does not continually pull the viewport back to the focused control.

Controls handle keyboard events first. Unhandled, unmodified navigation keys
scroll the nearest eligible ancestor: arrows move 40 pixels on the matching
axis, PageUp/PageDown move one viewport length, and Home/End move to a boundary.
At a boundary the key can bubble to an enclosing viewport. With no focus, a
root `ScrollView` handles these keys. Text input retains its caret/selection
handling for Left/Right and Home/End.

`UiRoot::key_down(event, size=host_size)` accepts the current logical viewport size;
otherwise it uses the last paint or pointer/wheel input size. The SDL backend
supplies the size for navigation keys. If Tab arrives before any host size is
known, reveal is deferred to preparation of the first paint, before drawing.

`view.translated(Point(...))` moves paint and input coordinates without changing
layout allocation, scroll extent or identity. Repeating it replaces that node's
translation. `view.clip()` clips the node and its descendants to its translated
outer frame. Paint and hit testing share ancestor clips and offsets, including
visible child overflow. Clips exclude their bottom and right edges. Captured
pointer move/release still reach their target outside a clip, while click
activation requires a visible hit on release.

Virtualized lists are a future extension.

## Select

`select` builds a single-value selector on top of `popup` from an
`ArrayView[SelectOption[T]]`. Each option describes a value of type `T`, its label
and whether it is disabled. The writable model is `Signal[T?]`; `None` displays the placeholder.
Without `selected`, the control owns an initially empty selection.

```mbt check
///|
test "select with a typed model" {
  let selected = @skerry.signal(Some("moonbit"))
  let rust_label = @skerry.signal("Rust")
  let go_disabled = @skerry.signal(true)
  let control = @skerry.select(
    [
      @skerry.SelectOption("moonbit", label="MoonBit"),
      @skerry.SelectOption("rust", label=rust_label),
      @skerry.SelectOption("go", label="Go", disabled=go_disabled),
    ],
    selected~,
    placeholder="Choose a language",
    style=@skerry.SelectStyle()
      .surface(@skerry.BoxStyle().width(220.0))
      .list(@skerry.BoxStyle().max_height(180.0)),
    on_change=fn(event) {
      if event.value == Some("rust") {
        event.prevent_default()
      }
    },
  )
  ignore(control)
}
```

Click, Enter, Space or Up/Down opens the list at the selected enabled option
(otherwise the first enabled one; Up starts at the last when selection is empty).
Up/Down wraps through enabled options. Home/End goes to the first/last enabled
option. Navigation moves focus and reveals that option without writing the model.
Enter, Space or a click confirms it. A prevented change keeps the list open;
confirming the current value simply closes it without another change event.
Escape or an outside press dismisses without committing. Tab stays within the
open popup. Closing restores focus to the field.

Text input searches enabled labels by a case-insensitive prefix. A pause longer
than 700 ms starts a new prefix; repeating a letter cycles matching options.
Searching schedules no timer or idle work. Options are copied once. Each label
accepts String, Signal[String], Computed[String] or Binding[String]; disabled
accepts the corresponding Bool sources and defaults to false. Construction reads
neither source. Option labels and availability are subscribed while the list is
open; the selected field label is also subscribed while closed. Input, painting
and snapshots read applied values. Descriptions can be reused in several Select
instances; each instance owns its nodes and subscriptions. Values require Eq and
do not need to implement Show.
Empty options disable the field. A model value absent from the options displays
the placeholder and is preserved until a user confirms another value.

The floating list matches the field width, flips at window edges and contains a
scroll viewport with a stable gutter so options do not lie beneath the scrollbar.
The arrow and check are vector strokes, independent of font glyph coverage.
Custom renderers implement `SceneRenderer::draw_line(start, end, color, width)`
in logical coordinates; the Skia backend scales and antialiases these strokes.
`SelectStyle` has `surface`, `label`, `placeholder`, `list`,
`option` and `selected` parts. `option` and `selected` accept `ButtonStyle` for
their surface/text declarations; `selected` layers over `option` for the committed
value, also marked with a check, while focus marks the active navigation target.
Global SelectStyle rules,
theme tokens and reactive styles work through the same style projections as
custom components. `placement` accepts the same positions as `popup`.

## Popups

`popup` attaches floating content to an anchor while keeping its logical parent,
context, theme and disabled state. It occupies only the anchor's space in normal
layout. The surface paints above ordinary content, including later siblings,
and escapes ancestor clips and scroll viewports. Paint, hit testing and snapshots
share the same logical window coordinates.

```mbt nocheck
///|
fn actions() -> @skerry.View {
  @skerry.popup(@skerry.button("Actions"), placement=BottomEnd) <| fn(close) {
    @skerry.column(
      style=@skerry.FlexStyle()
        .width(200.0)
        .spacing(8.0)
        .padding(@skerry.Insets::all(12.0))
        .background(@skerry.surface_token)
        .stroke(@skerry.border_token)
        .radius(8.0),
    ) <| [
      @skerry.button("Close", on_click=close),
    ]
  }
}
```

The popup owns its initially closed state by default. Click, Enter and Space
toggle its anchor, preserving the anchor's existing handlers. An optional
`open=signal` exposes that same state to its owner. `trigger=Manual` leaves the
anchor's behavior intact for opening controlled by the application; use it with
an external signal. Trigger behavior and placement are independent.

The content builder runs once per open session. Closing disposes its subscriptions
and local state; reopening builds fresh content. Keep persistent application data
in an external model. Equal open values and paint-only updates retain the current
instances and layout cache. Its `close` function follows the popup's change policy
and becomes inactive when that session is disposed, so a retained callback cannot
close a later session.

Placement defaults to `BottomStart`, with a gap of 4 logical units. `BottomEnd`,
`TopStart`, `TopEnd`, `LeftStart` and `RightStart` are also available. Placement
flips to the opposite side when that side has more space, then clamps to the
window. Natural content size is bounded by the viewport; use `scroll_view` within
the content when a large surface needs scrolling. Popup content does not increase
the anchor's scroll extent, and focus reveal or wheel input inside it does not
scroll the anchor's outer containers.

An outside press closes the topmost popup and consumes the press, so its release
cannot activate the content underneath. The anchor is excluded from outside
dismissal; its Click trigger toggles the popup. Escape first reaches the focused control;
if unhandled, it closes the topmost popup, including when nothing is focused.
The optional `on_change` receives `ChangeEvent(true)` before opening and
`ChangeEvent(false)` before closing and may prevent either change. Outside
dismissal and the content's `close` function use this same policy. Programmatic
writes to `open` remain ordinary model updates.

By default, opening focuses the first available Tab stop. Tab and Shift+Tab cycle
within the topmost popup that owns focus. Closing restores previous live focus or
the anchor; closing a nested popup returns focus to its parent. `focus=false`
preserves initial keyboard focus and does not contain Tab navigation, for passive
surfaces. Disabled anchors or ancestors suspend popup painting and input while retaining its
model and content; re-enabling makes it available again.

Layers follow logical tree order: later popup surfaces appear above earlier ones,
and nested surfaces appear above their parents. Snapshots retain the logical tree;
the floating `Popup` node's `popup_anchor` identifies its anchor. Geometry and theme
are frozen with the completed paint, as for ordinary nodes.

Custom hosts can use `View::popup_targets`, `View::popup_tab_paths` and
`LayoutState::popup_contains` to implement the same dismissal and focus policy.
`UiRoot` wires this automatically.

## Disabled controls and wrappers

Controls and containers accept the same named `disabled` property:

```mbt nocheck
///|
let blocked = @skerry.signal(false)

///|
let permanently_disabled = @skerry.button("Unavailable", disabled=true)

///|
let direct = @skerry.button("Save", disabled=blocked)

///|
let derived = @skerry.button(
  "Save",
  on_click=submit,
  disabled=@skerry.bind(fn() { !model.valid() }),
)

///|
let section = @skerry.column(children, disabled=blocked)
```

The property accepts a Bool, a Signal[Bool], a Computed[Bool], or a Binding[Bool]
through the readonly BoolValue source protocol. Constant values need no
subscriptions.
A Binding describes a pure producer; construction neither evaluates it nor
creates an effect. Each mount owns its subscription and resolved value.
Capture model handles when building content. Binding restores its construction
context within the same root; a foreign root supplies its own mount context.

Reactive sources materialize on mount and after dependency changes. Paint,
input and snapshots read concrete values and never evaluate the disabled
producer. Equal results remain idle; changes request paint while retaining
layout and text caches. In a batch the final values materialize before
availability callbacks and invalidation observers run.

Disabled applies to the view and its entire subtree: pointer/direct activation,
keyboard/text input, clipboard, focus traversal, wheel and scrollbar input.
Children cannot override a disabled ancestor with disabled=false. An interactive
wrapper preserves its child's local property when disabled is omitted; an
explicit disabled argument replaces that same node's local source, preserving
identity. BoxStyle.disabled(Appearance) configures the visual state separately.

Disabled views keep their layout and paint. Inside their frame they block
pointer targeting of siblings behind them and enclosing click handlers.
Later stack children are in front; an enabled control in front can receive input.
Disabling ends active pointer/scrollbar capture, keyboard press and focused
sessions. Re-enabling retains values and caret/selection but does not restore
focus or resume a cancelled press. Branch/root disposal stops subscriptions.
Snapshots retain the effective disabled value of the completed paint.

UiRoot manages all binding and input lifecycle work. Low-level custom hosts
must mount_reactivity before painting or dispatching reactive properties, and
use on_disabled_change to revalidate focus/capture, including descendants.
The callback runs after source values materialize; invalidate before invoking
application callbacks. Bare View operations do not select a particular root;
use UiRoot input methods for views shared across roots with different providers.

For `interactive(button(...))`, pointer release, `click_at`, Enter and Space
activate the button and each wrapper's `on_click` once, from inside out. The same
rule applies to checkbox and radio activation. Key observers are preserved.
Enter handled by a text input's `on_submit` submits the value without
activating wrapper click handlers.

## Input lifecycle

The SDL backend automatically follows the operating system's display scale.
App width/height, styles, font sizes, pointer positions, scroll offsets and snapshot
geometry use logical UI units. At 150%, a 100-unit control occupies 150 physical
pixels. No application signals or style multipliers are needed.

Windows are created with high pixel density enabled. Initial App dimensions are
converted to the platform's window coordinates; later resize and display-scale
changes preserve the mounted UI, focus, control values and subscriptions. Skia
rasterizes text, images, strokes and clips directly into a physical pixel buffer
using the display transform. A scale change also invalidates a cached frame when
the pixel extent stays unchanged. An unchanged logical viewport reuses layout and
text measurements. Window mouse coordinates are converted to the same logical
space for hit testing, selection, dragging and wheel input.

Custom hosts pass logical viewport sizes and input coordinates to UiRoot. Custom
raster renderers read `RasterTarget.scale` and paint at `target.logical_size()`,
applying the scale to their drawing surface. Width/height/row_bytes still describe
physical pixel storage; scale defaults to 1.0 for existing custom hosts. Source
image rectangles remain image pixels and destination rectangles use logical units.

Use `UiRoot::click_at` for direct activation. Native pointer input uses
`pointer_down`, `pointer_move`, and `pointer_up`: release activates a control only
after a press captured that same live control. A release without a press is
ignored. Direct activation does not produce pointer down/up callbacks.

`pointer_cancel` ends capture without release or activation and calls
`on_pointer_cancel`. Button, checkbox, radio, text input, and interactive wrappers
accept this optional callback. Text input stops dragging and retains its selection.
`focus_lost` cancels capture and blurs the focused control; custom hosts should call
it when their window loses input focus. The SDL backend handles this automatically.

Removing a focused or captured control runs blur/cancel before detachment.
Reordering a retained keyed control preserves focus and capture. `dispose` cancels
input and releases subscriptions once; subsequent input on that root is ignored.

## API stability

Application code should normally use the root `klaseca/skerry` package. The
lower-level view, runtime, text and backend packages are available for custom
integrations, but may change during the `0.x` releases.

## Current scope

This is a preview release. It does not yet provide GPU rendering, multiple
windows, accessibility integration, IME composition, complex text shaping,
animation or SVG. Font selection is currently limited to
the platform default typeface and configurable size.
