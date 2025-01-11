///|
type Handle

///|
pub trait ToHandle {
  to_handle(Self) -> Handle
}

///|
pub extern "c" fn close(handle : Handle, cb : (Handle) -> Unit) -> Unit = "moonbit_uv_close"
