///|
type Loop

///|
type Code

///|
type Data

///|
pub extern "c" fn moonbit_ffi_make_closure(code : Code, data : Data) -> Data = "moonbit_ffi_make_closure"

///|
fn init {
  moonbit_ffi_make_closure |> ignore
}

///|
pub extern "c" fn Loop::new() -> Loop = "auv_loop_new"

///|
pub extern "c" fn Loop::run(self : Loop, mode : Int) -> Int = "auv_loop_run"

///|
pub extern "c" fn Loop::close(self : Loop) -> Int = "auv_loop_close"

///|
type Idle

///|
pub extern "c" fn Idle::new(loop_ : Loop) -> Idle = "auv_idle_new"

///|
pub extern "c" fn Idle::start(self : Idle, cb : (Idle) -> Unit) -> Int = "auv_idle_start"

///|
pub extern "c" fn Idle::stop(self : Idle) -> Int = "auv_idle_stop"
