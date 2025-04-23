///| Execute `scripts/test-udp.py` in advance
fn main {
  try {
    let uv = @uv.Loop::new!()
    let socket = @uv.Udp::new!(uv)
    let addr : @uv.SockaddrIn = @uv.ip4_addr("0.0.0.0", 8543)
    socket.send!(
      [
        b"GET / HTTP/1.1\r\n", b"Host: www.example.com\r\n", b"User-Agent: libuv-client/1.0\r\n",
        b"Connection: close\r\n", b"\r\n",
      ],
      fn(_) { socket.close(fn(_) {  }) },
      fn(_, e) {
        println("Error: \{e}")
        socket.close(ignore)
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
