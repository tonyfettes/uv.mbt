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
pub fn Tcp::bind(
  self : Tcp,
  sock_addr : @uv.SockaddrIn,
  flags : Int
) -> Unit!Errno {
  @uv.tcp_bind(self.tcp, sock_addr, flags) |> errno!()
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
