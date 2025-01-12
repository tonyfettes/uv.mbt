///|
fn async_run(f :  async() -> Unit) -> Unit = "%async.run"

///|
async fn async_suspend[T, E : Error](
  f : ((T) -> Unit, (E) -> Unit) -> Unit
) -> T!E = "%async.suspend"
