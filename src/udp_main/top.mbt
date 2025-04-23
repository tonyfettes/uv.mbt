///| Execute `scripts/test-udp.py` in advance
fn main {
  try {
    let uv = @uv.Loop::new!()
    let in_socket = @uv.Udp::new!(uv)
    let out_socket = @uv.Udp::new!(uv)
    let addr : @uv.SockaddrIn = @uv.ip4_addr("0.0.0.0", 8543)
    in_socket.bind!(addr, @uv.UdpFlags::new())
    in_socket.recv_start!(
      fn(_, _) { Bytes::make(100, b'\x00')[:] },
      fn(_, buf, data, sockaddr, flags) { println(data) },
      fn(_, _) { panic() },
    )
    out_socket.send!(
      [b"Hello World"],
      fn(_) { out_socket.close(fn(_) {  }) },
      fn(_, e) {
        println("Error: \{e}")
        out_socket.close(ignore)
      },
      addr~,
    )
    uv.run!(Default)
    uv.stop()
    uv.close!()
  } catch {
    e => println(e)
  }
}
