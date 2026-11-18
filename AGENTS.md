# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- The repository root is a MoonBit workspace. The publishable
  `klaseca/skerry` module lives in `modules/skerry`; its packages are under
  `modules/skerry/src`.

## Development priorities and future DevTools support

- Prioritize application capabilities such as scrolling, text input and layout.
  Further profiling, tracing and inspector UI are deferred tracks, not prerequisites
  for implementing framework features.
- Consider future native UI DevTools compatibility where practical when changing
  node identity/composition, layout, input, scheduling, text or custom controls.
  Preserve existing stable IDs, shared paint/input geometry and diagnostic contracts;
  extend diagnostics alongside a feature when useful for representing its behavior.
- Keep inspector UI in an optional addon and out of production defaults;
  diagnostics must not alter reactive ownership or keep idle applications active.
- Inspector requirements apply when that track is undertaken; compatibility
  considerations should not make it the default next task or expand unrelated
  feature work into a profiling project.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- Expose intended trait methods through explicit `pub extend` declarations.
  Keep `Default` and internal `StyleSpec`/`SourceStyle` hooks trait-only; callers
  use constructors or the trait directly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.
