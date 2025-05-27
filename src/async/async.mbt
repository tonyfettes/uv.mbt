///|
async fn[T] suspend(f : ((T) -> Unit) -> Unit) -> T!Async = "%async.suspend"

///|
fn[T, E : Error] async_suspend_with_error(
  f : ((T) -> Unit, (E) -> Unit) -> Unit
) -> T!E + Async = "%async.suspend"

///|
fn async_run(f : () -> Unit!Async) -> Unit = "%async.run"

///|
priv struct Context {
  uv : @uv.Loop
  mut id : Int
}

///|
let context_ref : Ref[Context?] = Ref::new(None)

///|
fn context() -> Context! {
  match context_ref.val {
    Some(context) => context
    None => {
      let uv = @uv.Loop::new!()
      let context = Context::{ uv, id: 0 }
      context_ref.val = Some(context)
      context
    }
  }
}

///|
fn Context::id(self : Context) -> Int {
  let id = self.id
  self.id += 1
  id
}

///|
priv struct Scope {
  context : Context
  tasks : Set[Int]
  resolve : (Unit) -> Unit
  reject : (Error) -> Unit
}

///|
fn Scope::new(
  context : Context,
  resolve : (Unit) -> Unit,
  reject : (Error) -> Unit
) -> Scope {
  Scope::{ context, tasks: Set::new(), resolve, reject }
}

///|
fn Scope::launch(self : Scope, f : () -> Unit!Async + Error) -> Unit {
  let id = self.context.id()
  self.tasks.add(id)
  async_run(fn() {
    try {
      f!()
      self.resolve(id~)
    } catch {
      e => self.reject(id~, e)
    }
  })
}

///|
fn Scope::resolve(self : Scope, id~ : Int) -> Unit {
  if self.tasks.contains(id) {
    self.tasks.remove(id)
    if self.tasks.is_empty() {
      (self.resolve)(())
    }
  }
}

///|
fn Scope::reject(self : Scope, id~ : Int, e : Error) -> Unit {
  if self.tasks.contains(id) {
    self.tasks.remove(id)
    if self.tasks.is_empty() {
      (self.reject)(e)
    }
  }
}

///|
type File @uv.File

///|
fn[T] Context::start(self : Context, f : () -> T!Async + Error) -> T! {
  let uv = self.uv
  let mut value = None
  let mut error = None
  async_run(fn() {
    try {
      value = Some(f!())
    } catch {
      e => error = Some(e)
    }
  })
  uv.run!(Default)
  uv.stop()
  uv.close!()
  if error is Some(error) {
    raise error
  }
  guard value is Some(value)
  value
}

///|
fn[T] Context::scope(
  self : Context,
  f : () -> T!Async + Error
) -> T!Async + Error {
  let mut value = None
  async_suspend_with_error!(fn(resolve, reject) {
    let scope = Scope::new(self, resolve, reject)
    scope.launch(fn() { value = Some(f()) })
  })
  guard value is Some(value)
  value
}

///|
pub fn[T] scope(f : () -> T!Async + Error) -> T!Async + Error {
  let context = context!()
  context.scope(f)
}

///|
type Pipe @uv.Pipe

///|
pub fn Pipe::new(ipc~ : Bool = false) -> Pipe! {
  let uv = context!().uv
  @uv.Pipe::new!(uv, ipc~)
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
