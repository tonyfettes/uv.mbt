///|
extern type Handle

///|
pub extern "c" fn close(handle : Handle, cb : (Handle) -> Unit) -> Unit = "moonbit_uv_close"

///|
pub extern "c" fn handle_get_loop(handle : Handle) -> Loop = "moonbit_uv_handle_get_loop"
