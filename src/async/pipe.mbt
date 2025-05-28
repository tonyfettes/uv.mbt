///|
type Pipe @uv.Pipe

///|
pub fn Pipe::new(ipc~ : Bool = false) -> Pipe! {
  let uv = uv!()
  @uv.Pipe::new!(uv, ipc~)
}
