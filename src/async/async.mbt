///|
fn suspend_with_error[T, E : Error](
  f : ((T) -> Unit, (E) -> Unit) -> Unit
) -> T!E + Async = "%async.suspend"

///|
fn run(f : () -> Unit!Async) -> Unit = "%async.run"

///|
let uv_ref : Ref[@uv.Loop?] = Ref::new(None)

///|
fn uv() -> @uv.Loop! {
  if uv_ref.val is Some(uv) {
    return uv
  }
  let uv = @uv.Loop::new!()
  uv_ref.val = Some(uv)
  return uv
}

///|
type File @uv.File

///|
pub fn start(f : () -> Unit!Async + Error) -> Unit! {
  let uv = uv!()
  let mut error = None
  run(fn() {
    try {
      f!()
    } catch {
      e => {
        println("start: f(): \{e}")
        error = Some(e)
      }
    }
  })
  uv.run!(Default)
  uv_ref.val = None
  uv.stop()
  uv.close!()
  if error is Some(error) {
    println("start: uv.run!(): \{error}")
    raise error
  } else {
    println("start: uv.run!(): done")
  }
}

///|
type Pipe @uv.Pipe

///|
pub fn pipe(ipc~ : Bool = false) -> Pipe! {
  let uv = uv!()
  @uv.Pipe::new!(uv, ipc~)
}
