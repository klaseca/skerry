///|
/// A typed styling key. Names are diagnostic; separately created keys differ.
/// Declare a shared key once next to the component that consumes it.
pub struct ThemeToken[T] {
  priv identity : Ref[Unit]
  priv name : String
  priv fallback : T
}

///|
pub fn[T] ThemeToken::ThemeToken(name : String, fallback~ : T) -> ThemeToken[T] {
  { identity: Ref(()), name, fallback, }
}

///|
pub impl[T] Eq for ThemeToken[T] with fn equal(self, other) {
  physical_equal(self.identity, other.identity)
}

///|
pub impl[T] Hash for ThemeToken[T] with fn hash_combine(self, hasher) {
  // Names distribute keys; Eq still distinguishes separately declared tokens.
  Hash::hash_combine(self.name, hasher)
}

///|
pub impl[T] Debug for ThemeToken[T] with fn to_repr(self) {
  Repr(self.name)
}

///|
pub extend ThemeToken with Eq::{equal, not_equal}

///|
pub extend ThemeToken with Hash::{hash, hash_combine}

///|
pub extend ThemeToken with Debug::{to_repr}

///|
/// Immutable concrete assignments. No subscriptions, callbacks or UI owners.
/// Equality compares keys and values independently of assignment order.
#derive(Eq, Debug)
pub struct TokenValues {
  priv colors : Map[ThemeToken[@foundation.Color], @foundation.Color]
}

///|
pub extend TokenValues with Eq::{equal, not_equal}

///|
pub extend TokenValues with Debug::{to_repr}

///|
pub fn TokenValues::TokenValues() -> TokenValues {
  { colors: Map([]), }
}

///|
// All keys use the same merge: the incoming values take priority.
fn TokenValues::merge(self : TokenValues, next : TokenValues) -> TokenValues {
  if self.colors.is_empty() {
    return next
  }
  if next.colors.is_empty() {
    return self
  }
  let colors = self.colors.copy()
  for (key, color) in next.colors {
    colors[key] = color
  }
  { colors, }
}

///|
/// Supported theme value kinds. Color tokens are currently supported; numeric
/// and font references will be added together with their layout properties.
pub trait ThemeValue {
  fn put_token(ThemeToken[Self], Self, TokenValues) -> TokenValues
  fn find_token(ThemeToken[Self], Theme) -> Self?
}

///|
pub impl ThemeValue for @foundation.Color with fn put_token(key, value, values) {
  let colors = values.colors.copy()
  colors[key] = value
  { colors, }
}

///|
pub impl ThemeValue for @foundation.Color with fn find_token(key, theme) {
  theme.tokens.colors.get(key)
}

///|
/// Assign a concrete value without changing the input theme or the key.
pub fn[T : ThemeValue] Theme::token(
  self : Theme,
  token : ThemeToken[T],
  value : T,
) -> Theme {
  { ..self, tokens: T::put_token(token, value, self.tokens), }
}

///|
/// Resolve against this theme. Passing the result to a BoxStyle stores a literal;
/// pass the token itself when the BoxStyle should follow the consuming theme.
pub fn[T : ThemeValue] Theme::resolve(self : Theme, token : ThemeToken[T]) -> T {
  T::find_token(token, self).unwrap_or(token.fallback)
}

///|
/// Inherit missing token assignments from a parent. This theme's values take
/// priority, including the built-in colors filled by its palette preset. Subtree
/// scopes apply this automatically when a light/dark theme is supplied.
pub fn Theme::inherit_tokens(self : Theme, parent : Theme) -> Theme {
  { ..self, tokens: parent.tokens.merge(self.tokens), }
}
