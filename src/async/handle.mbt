///|
type Handle @uv.Handle

///|
pub trait ToHandle {
  to_handle(Self) -> Handle
}

///|
pub fn Handle::close(self : Handle) -> Unit {
  @uv.close(self._, fn(_) {  })
}
