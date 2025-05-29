///|
async fn[T] async_suspend(f : ((T) -> Unit) -> Unit) -> T = "%async.suspend"

///|
async fn[T, E : Error] async_suspend_with_error(
  f : ((T) -> Unit, (E) -> Unit) -> Unit
) -> T!E = "%async.suspend"

///|
fn async_run(f : async () -> Unit) -> Unit = "%async.run"

///|
let uv_ref : Ref[@uv.Loop?] = Ref::new(None)

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
pub fn[T] start(f : async () -> T!) -> T! {
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
  f : async () -> T!
}

///|
pub fn[T] Task::new(f : async () -> T!) -> Task[T] {
  Task::{ f, }
}

///|
pub async fn[T] Task::start(self : Task[T]) -> T! {
  async_suspend_with_error!(fn(resolve, reject) {
    async_run(fn() {
      try resolve((self.f)!()) catch {
        e => reject(e)
      }
    })
  })
}
