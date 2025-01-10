///|
fn main {
  println("here")
  let loop_ = @auv.loop_alloc()
  @auv.loop_init(loop_) |> ignore
  let idle = @auv.idle_alloc(loop_)
  @auv.idle_init(loop_, idle) |> ignore
  let mut i = 3
  println("idle: \{i}")
  @auv.idle_start(idle, fn(idle) {
    i += 1
    println("idle: \{i}")
    if i >= 100 {
      @auv.idle_stop(idle) |> ignore
    }
  })
  |> ignore
  @auv.loop_run(loop_, 0) |> ignore
  @auv.loop_close(loop_) |> ignore
}
