///|
type Loop @uv.Loop

///|
pub fn run[E : Error](f :  async(Loop) -> Unit!E) -> Unit! {
  let loop_ = @uv.loop_alloc()
  @uv.loop_init(loop_) |> errno!()
  let mut error : E? = None
  async_run(fn() {
    try {
      f!!(loop_)
    } catch {
      err => error = Some(err)
    }
  })
  @uv.run(loop_, @uv.UV_RUN_DEFAULT) |> errno!()
  @uv.loop_close(loop_) |> errno!()
  @uv.loop_free(loop_)
  match error {
    None => ()
    Some(error) => raise error
  }
}

///|
pub fn Loop::alive(self : Loop) -> Bool {
  @uv.loop_alive(self._) != 0
}
