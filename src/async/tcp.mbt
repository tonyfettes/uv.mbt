///|
struct Tcp {
  loop_ : Loop
  tcp : @uv.Tcp
}

///|
impl ToStream for Tcp with to_stream(self : Tcp) -> Stream {
  self.tcp.to_stream()
}

///|
pub fn Loop::tcp(self : Loop) -> Tcp!Errno {
  let tcp = @uv.tcp_alloc()
  @uv.tcp_init(self._, tcp) |> errno!()
  { loop_: self, tcp }
}

///|
type SockaddrIn @uv.SockaddrIn

///|
pub fn ip4_addr(ip : Bytes, port : Int) -> SockaddrIn {
  let addr = @uv.sockaddr_in_alloc()
  @uv.ip4_addr(ip, port, addr)
  addr
}

///|
pub fn Tcp::bind(self : Tcp, sock_addr : SockaddrIn, flags : Int) -> Unit!Errno {
  @uv.tcp_bind(self.tcp, sock_addr._, flags) |> errno!()
}

///|
pub async fn Tcp::listen(self : Tcp, backlog : Int) -> Unit!Errno {
  self.to_stream().listen!!(backlog)
}

///|
pub fn Tcp::accept(self : Tcp) -> Tcp!Errno {
  let other = self.loop_.tcp!()
  let status = @uv.accept(self.tcp.to_stream(), other.tcp.to_stream())
  if status < 0 {
    @uv.close(other.tcp.to_stream().to_handle(), fn(_) {  })
    raise Errno(status)
  } else {
    other
  }
}

///|
pub async fn Tcp::read(self : Tcp) -> BytesView!Errno {
  self.to_stream().read!!()
}

///|
pub async fn Tcp::write(self : Tcp, bytes : BytesView) -> BytesView!Errno {
  self.to_stream().write!!(bytes)
}
