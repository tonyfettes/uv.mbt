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
  let uv = @uv.Loop::new()
  uv_ref.val = Some(uv)
  return uv
}

///|
pub fn[T] start(f : async () -> T!) -> T! {
  let uv = uv()
  let mut value = None
  let mut error = None
  async_run(fn() {
    try {
      let _ = {
        value = Some(f())
      }

    } catch {
      e => error = Some(e)
    }
  })
  uv.run(Default)
  uv_ref.val = None
  uv.stop()
  uv.close()
  if error is Some(error) {
    raise error
  }
  guard value is Some(value)
  value
}

///|
pub fn cwd() -> Path! {
  Path::new(@uv.cwd())
}

///|
priv struct Scope[E] {
  mut launched : Int
  mut canceled : Bool
  resolve : (Unit) -> Unit
  reject : (E) -> Unit
}

///|
fn[E] Scope::resolve(self : Scope[E]) -> Unit {
  self.launched -= 1
  if self.launched == 0 {
    (self.resolve)(())
  }
}

///|
fn[E] Scope::reject(self : Scope[E], error : E) -> Unit {
  self.canceled = true
  self.launched -= 1
  if self.launched == 0 {
    (self.reject)(error)
  }
}

///|
fn[E : Error] Scope::launch(self : Scope[E], f : async () -> Unit!E) -> Unit {
  if self.canceled {
    return
  }
  self.launched += 1
  async_run(fn() {
    try {
      f()
      self.resolve()
    } catch {
      e => self.reject(e)
    }
  })
}

///|
async fn[T, E : Error] Scope::new(f : async (Scope[E]) -> T!E) -> T!E {
  let mut value = None
  async_suspend_with_error(fn(resolve, reject : (E) -> Unit) {
    let scope = Scope::{ launched: 0, canceled: false, resolve, reject }
    scope.launch(fn() { value = Some(f(scope)) })
  })
  guard value is Some(value)
  value
}

///|
pub fn args() -> Array[String] {
  @uv.args()
}
