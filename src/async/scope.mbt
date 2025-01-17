///|
struct Scope {
  loop_ : Loop
  mut schedule : Int
  mut finished : Int
  mut canceled : Bool
  resolve : (Unit) -> Unit
  reject : (Error) -> Unit
}

///|
pub let active_scope : Ref[Scope?] = @ref.new(None)

///|
fn Scope::resolve(self : Scope) -> Unit {
  self.finished += 1
  if self.schedule == self.finished {
    if self.canceled {
      (self.reject)(Errno(@uv.EAI_CANCELED))
    }
  }
}

///|
fn Scope::reject(self : Scope, error : Error) -> Unit {
  self.canceled = true
  self.finished += 1
  if self.schedule == self.finished {
    if self.canceled {
      (self.reject)(Errno(@uv.EAI_CANCELED))
    } else {
      (self.reject)(error)
    }
  }
}

///|
pub async fn Loop::scope(self : Loop, f :  async(Scope) -> Unit!) -> Unit! {
  async_suspend!!(fn(resolve, reject) {
    let scope = Scope::{
      loop_: self,
      schedule: 0,
      finished: 0,
      canceled: false,
      resolve,
      reject,
    }
    async_run(fn() {
      scope.schedule += 1
      try {
        f!!(scope)
        scope.resolve()
      } catch {
        error => {
          scope.reject(error)
        }
      }
    })
  })
}

///|
pub fn Scope::start(self : Scope, f :  async() -> Unit!) -> Unit {
  if self.canceled {
    return
  }
  async_run(fn() {
    self.schedule += 1
    try {
      f!!()
      self.resolve()
    } catch {
      error => self.reject(error)
    }
  })
}

///|
pub fn Scope::cancel(self : Scope) -> Unit!Errno {
  self.canceled = true
  raise Errno(@uv.EAI_CANCELED)
}
