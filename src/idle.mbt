///|
type Idle

///|
pub extern "c" fn idle_alloc(loop_ : Loop) -> Idle = "auv_idle_alloc"

///|
pub extern "c" fn idle_init(loop_ : Loop, idle : Idle) -> Int = "auv_idle_init"

///|
pub extern "c" fn idle_start(idle : Idle, cb : (Idle) -> Unit) -> Int = "auv_idle_start"

///|
pub extern "c" fn idle_stop(idle : Idle) -> Int = "auv_idle_stop"

///|
pub extern "c" fn idle_free(idle : Idle) -> Int = "auv_idle_free"
