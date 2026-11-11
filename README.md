# Skerry

Skerry is an experimental native desktop UI framework for MoonBit. It provides
reactive state, layout, text, images, basic controls, scrolling, themes and anchored
popups. The default backend uses SDL 3 for windows and input and Skia for CPU
rendering.

## Getting started

Clone the repository:

```sh
git clone https://github.com/klaseca/skerry.git
cd skerry
```

Prepare the development environment:

- Use the MoonBit compiler version recorded in [`.moonbit-version`](.moonbit-version).
- Install Node.js; the SDL and Skia native build hooks use it.
- Make a native C compiler available. Windows builds require an MSVC-compatible
  toolchain.
- Install the SDL 3 development headers and libraries. Set `SDL3_INSTALL_PATH` to
  their absolute installation path if SDL is not discovered automatically.
- Set `SKIA_PATH` to an absolute dependency root containing `include/c/sk_types.h`
  and `out/<system>/<architecture>/release/libSkiaSharp.*`.

See the [SDL setup instructions](https://github.com/klaseca/sdl-mbt#requirements)
and [Skia build instructions](https://github.com/klaseca/skia-mbt#building-the-native-dependency-from-source)
for preparing the native libraries. MoonBit downloads the published bindings
when resolving workspace dependencies.

On Windows x64, configure the paths in a PowerShell session with the native
compiler available. Adjust these example paths to your installations:

```powershell
$env:SDL3_INSTALL_PATH = "C:\Libraries\SDL3"
$env:SKIA_PATH = "C:\Libraries\skia"
$env:PATH = "$env:SDL3_INSTALL_PATH\lib\x64;$env:SKIA_PATH\out\windows\x64\release;$env:PATH"
```

The directories added to `PATH` must contain `SDL3.dll` and `libSkiaSharp.dll`.

Run the basic example from the repository root:

```sh
moon run examples/basic
```

Only the native target is supported. The current setup has been verified on
Windows; Linux and macOS have not yet been verified for Skerry.

## Examples

Run these commands from the repository root:

```sh
moon run examples/form
moon run examples/images
moon run examples/theming
```

The examples cover form validation, image rendering and custom themed components.

## Development

With the native dependencies configured, run:

```sh
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build --deny-warn
```

## Documentation

See the [API guide](modules/skerry/README.mbt.md) for components, reactive values,
styling, themes, lifecycle and custom backends.

This is an experimental project with an evolving API. GPU rendering, multiple
windows, accessibility, IME composition and complex text shaping are future work.
