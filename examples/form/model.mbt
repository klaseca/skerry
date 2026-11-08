///|
#derive(Eq)
priv enum EmailFormat {
  PlainText
  Html
}

///|
fn EmailFormat::label(self : EmailFormat) -> String {
  match self {
    PlainText => "Plain text"
    Html => "HTML"
  }
}

///|
priv struct FormModel {
  name : @skerry.Signal[String]
  email : @skerry.Signal[String]
  format : @skerry.Signal[EmailFormat]
  accepted : @skerry.Signal[Bool]
  name_touched : @skerry.Signal[Bool]
  email_touched : @skerry.Signal[Bool]
  attempted : @skerry.Signal[Bool]
  submitted : @skerry.Signal[String?]
}

///|
fn FormModel::FormModel() -> FormModel {
  {
    name: @skerry.signal(""),
    email: @skerry.signal(""),
    format: @skerry.signal(PlainText),
    accepted: @skerry.signal(false),
    name_touched: @skerry.signal(false),
    email_touched: @skerry.signal(false),
    attempted: @skerry.signal(false),
    submitted: @skerry.signal(None),
  }
}

///|
fn FormModel::name_error(self : FormModel) -> String? {
  if self.name.get().trim().is_empty() {
    Some("Enter your name.")
  } else {
    None
  }
}

///|
fn FormModel::email_error(self : FormModel) -> String? {
  let value = self.email.get().trim().to_owned()
  if value.is_empty() {
    Some("Enter your email address.")
  } else {
    // A small example rule, not a complete email-address parser.
    let parts = value.split("@").collect()
    match parts {
      [mailbox, domain] if !mailbox.is_empty() &&
        !domain.is_empty() &&
        !domain.has_prefix(".") &&
        !domain.has_suffix(".") &&
        domain.contains(".") &&
        !value.contains(" ") &&
        !value.contains("\t") &&
        !value.contains("\n") => None
      _ => Some("Use an address such as name@example.com.")
    }
  }
}

///|
fn FormModel::valid(self : FormModel) -> Bool {
  self.name_error() is None && self.email_error() is None && self.accepted.get()
}

///|
fn FormModel::submit(self : FormModel) -> Unit {
  @skerry.batch(fn() {
    self.attempted.set(true)
    if self.valid() {
      self.submitted.set(
        Some(
          "Saved \{self.name.get().trim()} <\{self.email.get().trim()}> [\{self.format.get().label()}]",
        ),
      )
    } else {
      self.submitted.set(None)
    }
  })
}

///|
fn FormModel::changed(self : FormModel) -> Unit {
  if self.submitted.peek() is Some(_) {
    self.submitted.set(None)
  }
}
