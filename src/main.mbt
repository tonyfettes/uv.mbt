///|
fn main {
  println("here")
  let loop_ = Loop::new()
  let idle = Idle::new(loop_)
  let mut i = 3
  println("idle: \{i}")
  idle.start(fn(idle) {
    i += 1
    println("idle: \{i}")
    if i >= 100 {
      println("idle: \{i}")
      idle.stop() |> ignore
    }
  })
  |> ignore
  loop_.run(0) |> ignore
  loop_.close() |> ignore
}
