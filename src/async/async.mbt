///|
async fn[T] suspend(f : ((T) -> Unit) -> Unit) -> T!Async = "%async.suspend"

///|
fn[T, E : Error] async_suspend_with_error(
  f : ((T) -> Unit, (E) -> Unit) -> Unit
) -> T!E + Async = "%async.suspend"

///|
fn async_run(f : () -> Unit!Async) -> Unit = "%async.run"

///|
let uv_ref : Ref[@uv.Loop?] = Ref::new(None)

///|
struct Context {
  uv : @uv.Loop
}

///|
struct Scope[T] {
  resolve : (T) -> Unit
  reject : (Error) -> Unit
}

///|
fn uv() -> @uv.Loop!@uv.Errno {
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
pub fn[T] start(f : () -> T!Async + Error) -> T! {
  let uv = uv!()
  let mut value = None
  let mut error = None
  async_run(fn() {
    try {
      let _ = {
        value = Some(f!())
      }

    } catch {
      e => error = Some(e)
    }
  })
  uv.run!(Default)
  uv_ref.val = None
  uv.stop()
  uv.close!()
  if error is Some(error) {
    raise error
  }
  guard value is Some(value)
  value
}

///|
pub fn cwd() -> Path! {
  path!(@uv.cwd!())
}

///|
struct Task[T] {
  f : () -> T!Async + Error
}

///|
pub fn[T] Task::new(f : () -> T!Async + Error) -> Task[T] {
  Task::{ f, }
}

///|
pub fn[T] Task::start(self : Task[T]) -> T!Async + Error {
  async_suspend_with_error!(fn(resolve, reject) {
    async_run(fn() {
      try resolve((self.f)!()) catch {
        e => reject(e)
      }
    })
  })
}
