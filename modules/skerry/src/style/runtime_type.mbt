// Private runtime type boundary for heterogeneous style storage.
// The conversion primitives are not a public casting API. Always box Ref[T],
// check the monomorphized witness and complete type description before restoring.
// Native debug/release tests cover nominal types, package names and generics.
// Uses the same type-witness technique as tonyfettes/any; no per-style user codec.

///|
priv type StylePayload

///|
// Always erase a GC reference, including for scalar style representations.
fn[T] erase_style(value : Ref[T]) -> StylePayload = "%identity"

///|
fn[T] restore_style(value : StylePayload) -> Ref[T] = "%identity"

///|
fn[T] describe_style(value : T) -> String = "%any.to_string"

///|
// A monomorphized trait implementation supplies an automatic identity for T.
// Keep this compiler-dependent boundary covered by debug/release native tests.
priv trait StyleWitness {
  fn identity() -> Unit = _
  fn witness(() -> Self) -> () -> Unit = _
}

///|
impl StyleWitness with fn identity() {
  ()
}

///|
impl StyleWitness with fn witness(_) {
  Self::identity
}

///|
impl[T] StyleWitness for Ref[T]
