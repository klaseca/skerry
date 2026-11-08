///|
fn main raise {
  @skerry.run(
    App(title="Skerry Form", width=640, height=560, content=() => {
      form_view(FormModel())
    }),
  )
}
