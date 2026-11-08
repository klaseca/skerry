// TODO(moonbit-implicit-impl): Remove these compatibility extensions when the
// compiler no longer implicitly promotes public impl methods. Trait-only hooks
// and Default are called through their traits; direct method calls must warn.
// Keep warning 79 enabled for new impls. These existing implicit methods are
// deprecated and hidden from documentation until they can be removed.

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend ImageStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend ImageStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend ImageStyle with @style.SourceStyle::{with_source}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend FlexStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend FlexStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend FlexStyle with @style.SourceStyle::{with_source}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextAppearance with Default::{default}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextStates with Default::{default}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextStyle with @style.SourceStyle::{with_source}
