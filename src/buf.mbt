///|
pub type Buf

///|
pub extern "c" fn buf_alloc() -> Buf = "auv_buf_alloc"

///|
pub extern "c" fn buf_init(buf : Buf, bytes : FixedArray[Byte]) -> Int = "auv_buf_init"

///|
pub extern "c" fn buf_set_base(buf : Buf, base : Bytes) -> Int = "auv_buf_set_base"

///|
pub extern "c" fn buf_set_len(buf : Buf, len : UInt64) -> Unit = "auv_buf_set_len"

///|
pub extern "c" fn buf_free(buf : Buf) -> Unit = "auv_buf_free"
