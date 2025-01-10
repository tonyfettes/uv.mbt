///|
type Loop

///|
pub extern "c" fn loop_alloc() -> Loop = "auv_loop_alloc"

///|
pub extern "c" fn loop_init(loop_ : Loop) -> Int = "auv_loop_init"

///|
pub extern "c" fn loop_run(loop_ : Loop, mode : Int) -> Int = "auv_loop_run"

///|
pub extern "c" fn loop_close(loop_ : Loop) -> Int = "auv_loop_close"

///|
pub extern "c" fn loop_free(loop_ : Loop) -> Int = "auv_loop_free"
