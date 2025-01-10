///|
type Tcp

///|
pub extern "c" fn tcp_alloc() -> Tcp = "auv_tcp_alloc"

///|
pub fn tcp_to_stream(tcp : Tcp) -> Stream = "%identity"

///|
type SockaddrIn

///|
pub extern "c" fn sockaddr_in_alloc() -> SockaddrIn = "auv_sockaddr_in_alloc"

///|
type SockaddrIn6

///|
pub extern "c" fn tcp_init(loop_ : Loop, tcp : Tcp) -> Int = "auv_tcp_init"

///|
pub extern "c" fn ip4_addr(ip : Bytes, port : Int, addr : SockaddrIn) -> Int = "auv_ip4_addr"

///|
pub extern "c" fn ip6_addr(ip : Bytes, port : Int, addr : SockaddrIn6) -> Int = "auv_ip6_addr"

///|
pub extern "c" fn tcp_bind(tcp : Tcp, addr : SockaddrIn, flags : Int) -> Int = "auv_tcp_bind"

///|
type Stream

///|
pub fn stream_to_handle(stream : Stream) -> Handle = "%identity"

///|
pub extern "c" fn listen(
  stream : Stream,
  backlog : Int,
  cb : (Stream, Int) -> Unit
) -> Int = "auv_listen"

///|
pub extern "c" fn accept(server : Stream, client : Stream) -> Int = "auv_accept"

///|
pub extern "c" fn read_start(
  stream : Stream,
  alloc_cb : (Handle, UInt64, Buf) -> Unit,
  read_cb : (Stream, Int64, Buf) -> Unit
) -> Int = "auv_read_start"

///|
pub extern "c" fn read_stop(stream : Stream) -> Int = "auv_read_stop"

///|
type Handle

///|
pub extern "c" fn close(handle : Handle, cb : (Handle) -> Unit) -> Unit = "auv_close"

///|
type Write

///|
pub extern "c" fn write_alloc() -> Write = "auv_write_alloc"

///|
pub extern "c" fn write(
  write : Write,
  handle : Stream,
  bufs : FixedArray[Buf],
  cb : (Write, Int) -> Unit
) -> Int = "auv_write"
