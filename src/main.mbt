fn main {
  run_async(async fn() {
    println("here");
    let loop_ = Loop::new()
    let idle = Idle::new(loop_)
    let mut i = 3
    println("idle: \{i}")
    let idle = idle.start!!();
    i += 1;
    println("idle: \{i}")
    if i >= 100 {
      println("idle: \{i}")
      idle.stop() |> ignore
    }
    loop_.run(0) |> ignore
    loop_.close() |> ignore
  })
}
