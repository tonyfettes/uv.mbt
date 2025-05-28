///|
type Pipe @uv.Pipe

///|
pub fn Pipe::new(ipc~ : Bool = false) -> Pipe! {
  let uv = uv!()
  @uv.Pipe::new!(uv, ipc~)
}

///|
pub fn Pipe::close(self : Pipe) -> Unit!Async {
  async_suspend!(fn(resolve) { self._.close(fn(_) { resolve(()) }) })
}

///|
pub impl Readable for Pipe with read(self : Pipe) {
  self._.to_stream().read!()
}

///|
pub impl Writable for Pipe with write(self : Pipe, bytes : @bytes.View) -> Iter[
  Int,
]!Async +
Error {
  Writable::write!(self._.to_stream(), bytes)
}
