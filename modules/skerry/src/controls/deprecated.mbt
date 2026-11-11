// TODO(moonbit-implicit-impl): Remove with the view/style compatibility extensions.

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend SelectStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend SelectStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend SelectStyle with @style.SourceStyle::{with_source}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend ButtonStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend ButtonStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend ButtonStyle with @style.SourceStyle::{with_source}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend CheckboxStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend CheckboxStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend CheckboxStyle with @style.SourceStyle::{with_source}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend RadioStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend RadioStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend RadioStyle with @style.SourceStyle::{with_source}

///|
#deprecated("Call Default methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextInputStyle with Default::{default}

///|
#deprecated("Call StyleSpec methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextInputStyle with @style.StyleSpec::{
  has_source,
  split_source,
  freeze_fields,
}

///|
#deprecated("Call SourceStyle methods through the trait; this compatibility method will be removed")
#doc(hidden)
pub extend TextInputStyle with @style.SourceStyle::{with_source}
