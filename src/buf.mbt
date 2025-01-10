///|
pub type Buf

///|
pub extern "c" fn buf_alloc() -> Buf = "auv_buf_alloc"

///|
pub extern "c" fn buf_init(buf : Buf, bytes : FixedArray[Byte]) -> Int = "auv_buf_init"

pub extern "c" fn buf_set_len(buf : Buf, len : UInt64) -> Int = "auv_buf_set_len"