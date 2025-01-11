///|
let counter : Ref[Int] = @ref.new(0)

///|
fn wait_for_a_while(handle : @uv.Idle) -> Unit {
  counter.val += 1
  if counter.val >= 10000000 {
    @uv.idle_stop(handle) |> ignore
  }
}

///|
fn main {
  let idler = @uv.idle_alloc()
  @uv.idle_init(@uv.default_loop(), idler) |> ignore
  @uv.idle_start(idler, wait_for_a_while) |> ignore
  println("Idling...")
  @uv.run(@uv.default_loop(), 0) |> ignore
  @uv.loop_close(@uv.default_loop()) |> ignore
}
