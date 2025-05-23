///|
pub(all) enum ProcessInput {
  Ignore
  Stdin
  Pipe(Pipe)
  Inherit(File)
  Bytes(@bytes.View)
  Reader(AsyncIter[@bytes.View])
}

///|
pub(all) enum ProcessOutput {
  Ignore
  Stdout
  Stderr
  Inherit(File)
  Buffer(@buffer.T)
  Writer((@bytes.View) -> Unit!Async + Error)
}

///|
fn ProcessInput::create(
  self : ProcessInput,
  pipes~ : Array[@uv.Pipe?],
  tasks~ : Array[() -> Unit!Async + Error],
  stdio~ : Array[@uv.StdioContainer]
) -> Unit!Error {
  let uv = uv!()
  match self {
    Ignore => {
      pipes.push(None)
      stdio.push(@uv.StdioContainer::ignore())
    }
    Inherit(file) => {
      pipes.push(None)
      stdio.push(@uv.StdioContainer::inherit_file(file._))
    }
    Stdin => {
      pipes.push(None)
      stdio.push(@uv.StdioContainer::inherit_file(@uv.stdin()))
    }
    Pipe(pipe) => {
      pipes.push(Some(pipe._))
      stdio.push(@uv.StdioContainer::create_pipe(pipe._, writable=true))
    }
    Bytes(bytes) => {
      let pipe = @uv.Pipe::new!(uv)
      pipes.push(Some(pipe))
      stdio.push(@uv.StdioContainer::create_pipe(pipe, readable=true))
      tasks.push(fn() {
        Writable::write!(pipe.to_stream(), bytes).each!(fn(_) {  })
        suspend!(fn(resolve : (Unit) -> Unit) {
          pipe.close(fn(_) { resolve(()) })
        })
      })
    }
    Reader(reader) => {
      let pipe = @uv.Pipe::new!(uv)
      pipes.push(Some(pipe))
      stdio.push(@uv.StdioContainer::create_pipe(pipe, readable=true))
      tasks.push(fn() {
        reader.each!(fn(bytes) {
          Writable::write!(pipe.to_stream(), bytes).each!(fn(_) {  })
        })
        suspend!(fn(resolve : (Unit) -> Unit) {
          pipe.close(fn(_) { resolve(()) })
        })
      })
    }
  }
}

///|
fn ProcessOutput::create(
  self : ProcessOutput,
  pipes~ : Array[@uv.Pipe?],
  tasks~ : Array[() -> Unit!Async + Error],
  stdio~ : Array[@uv.StdioContainer]
) -> Unit!Error {
  let uv = uv!()
  match self {
    Ignore => {
      pipes.push(None)
      stdio.push(@uv.StdioContainer::ignore())
    }
    Inherit(file) => {
      pipes.push(None)
      stdio.push(@uv.StdioContainer::inherit_file(file._))
    }
    Stdout => {
      pipes.push(None)
      stdio.push(@uv.StdioContainer::inherit_file(@uv.stdout()))
    }
    Stderr => {
      pipes.push(None)
      stdio.push(@uv.StdioContainer::inherit_file(@uv.stderr()))
    }
    Buffer(buffer) => {
      let pipe = @uv.Pipe::new!(uv)
      pipes.push(Some(pipe))
      stdio.push(@uv.StdioContainer::create_pipe(pipe, writable=true))
      tasks.push(fn() {
        pipe
        .to_stream()
        .read!()
        .each!(fn(bytes) { buffer.write_bytesview(bytes) })
      })
    }
    Writer(writer) => {
      let pipe = @uv.Pipe::new!(uv)
      pipes.push(Some(pipe))
      stdio.push(@uv.StdioContainer::create_pipe(pipe, writable=true))
      tasks.push(fn() {
        pipe.to_stream().read!().each!(fn(bytes) { writer!(bytes) })
      })
    }
  }
}

///|
struct CompletedProcess {
  status : Int
}

///|
pub fn CompletedProcess::status(self : CompletedProcess) -> Int {
  self.status
}

///|
trait Executable {
  spawn(
    Self,
    Array[&Show],
    stdin~ : ProcessInput,
    stdout~ : ProcessOutput,
    stderr~ : ProcessOutput,
  ) -> CompletedProcess!Async + Error
}

///|
pub impl Executable for String with spawn(
  self : String,
  args : Array[&Show],
  stdin~ : ProcessInput,
  stdout~ : ProcessOutput,
  stderr~ : ProcessOutput
) -> CompletedProcess!Async + Error {
  let uv = uv!()
  let args : Array[@string.View] = [
      self,
      ..args.map(fn(arg) { arg.to_string().view() }),
    ]
  let mut cancelled = false
  async_suspend_with_error!(fn(
    resolve : (CompletedProcess) -> Unit,
    reject : (Error) -> Unit
  ) {
    try {
      let pipes = []
      let tasks = []
      let stdio = []
      stdin.create!(pipes~, stdio~, tasks~)
      stdout.create!(pipes~, stdio~, tasks~)
      stderr.create!(pipes~, stdio~, tasks~)
      let options = @uv.ProcessOptions::new(self, args, stdio~, fn(
        child,
        exit_status,
        term_signal
      ) {
        child.close(fn(_) {
          ignore(term_signal)
          CompletedProcess::{ status: exit_status.to_int() } |> resolve()
        })
      })
      ignore(uv.spawn!(options))
      for task in tasks {
        async_run(fn() {
          try task!() catch {
            e =>
              if not(cancelled) {
                cancelled = true
                reject(e)
              }
          }
        })
        if cancelled {
          break
        }
      }
    } catch {
      e => reject(e)
    }
  })
}

///|
pub impl Executable for Path with spawn(
  self : Path,
  args : Array[&Show],
  stdin~ : ProcessInput,
  stdout~ : ProcessOutput,
  stderr~ : ProcessOutput
) -> CompletedProcess!Async + Error {
  let path = self.to_string()
  path.spawn!(args, stdin~, stdout~, stderr~)
}

///|
pub fn[Exec : Executable] spawn(
  exec : Exec,
  args : Array[&Show],
  stdin~ : ProcessInput = Ignore,
  stdout~ : ProcessOutput = Ignore,
  stderr~ : ProcessOutput = Ignore
) -> CompletedProcess!Async + Error {
  exec.spawn!(args, stdin~, stdout~, stderr~)
}
