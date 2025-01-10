///|
type Fs

///|
pub extern "c" fn fs_alloc() -> Fs = "auv_fs_alloc"

///|
pub extern "c" fn fs_open(
  loop_ : Loop,
  req : Fs,
  path : Bytes,
  flags : Int,
  mode : Int,
  cb : (Fs) -> Unit
) -> Int = "auv_fs_open"

///|
pub extern "c" fn fs_close(
  loop_ : Loop,
  req : Fs,
  file : Int64,
  cb : (Fs) -> Unit
) -> Int = "auv_fs_close"

///|
pub extern "c" fn fs_get_result(req : Fs) -> Int64 = "auv_fs_get_result"

///|
/// * Windows: HANLDE (void *)
/// * Unix (Linux/macOS): ssize_t
pub(readonly) typealias File = Int64

///|
pub extern "c" fn fs_read(
  loop_ : Loop,
  req : Fs,
  file : File,
  bufs : FixedArray[Buf],
  offset : Int64,
  cb : (Fs) -> Unit
) -> Int = "auv_fs_read"

///|
pub extern "c" fn fs_write(
  loop_ : Loop,
  req : Fs,
  file : File,
  bufs : FixedArray[Buf],
  offset : Int64,
  cb : (Fs) -> Unit
) -> Int = "auv_fs_write"

///|
pub const O_RDONLY : Int = 0x0000
