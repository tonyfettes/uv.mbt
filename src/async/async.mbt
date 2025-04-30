///|
fn suspend_with_error[T, E : Error](
  f : ((T) -> Unit, (E) -> Unit) -> Unit
) -> T!E + Async = "%async.suspend"

///|
fn run(f : () -> Unit!Async) -> Unit = "%async.run"

///|
let uv_ref : Ref[@uv.Loop?] = Ref::new(None)

///|
fn uv() -> @uv.Loop! {
  if uv_ref.val is Some(uv) {
    return uv
  }
  let uv = @uv.Loop::new!()
  uv_ref.val = Some(uv)
  return uv
}

///|
type File @uv.File

///|
pub(all) enum Stdin {
  Ignore
  Pipe(Pipe)
  Stdin
  Inherit(File)
  Bytes(@bytes.View)
}

///|
pub(all) enum Stdout {
  Ignore
  Pipe(Pipe)
  Stdin
  Stdout
  Stderr
  Inherit(File)
  Capture
  Buffer(@buffer.T)
}

///|
priv struct Process {
  mut stdin : WritableStream?
  mut stdout : ReadableStream?
  mut stderr : ReadableStream?
}

///|
fn Process::new() -> Process {
  Process::{ stdin: None, stdout: None, stderr: None }
}

///|
fn Process::stdin(
  self : Process,
  stdin : Stdin
) -> @uv.StdioContainer!Async + Error {
  match stdin {
    Stdin::Ignore => @uv.StdioContainer::ignore()
    Stdin::Pipe(pipe) => @uv.StdioContainer::create_pipe(pipe._, readable=true)
    Stdin::Stdin => @uv.StdioContainer::inherit_file(@uv.stdin())
    Stdin::Inherit(file) => @uv.StdioContainer::inherit_file(file._)
    Stdin::Bytes(bytes) => {
      let pipe = pipe!(ipc=false)
      let container = @uv.StdioContainer::create_pipe(pipe._, readable=true)
      self.stdin = Some(WritableStream::new(pipe._, bytes))
      container
    }
  }
}

///|
fn Process::stdout(
  self : Process,
  stdout : Stdout
) -> @uv.StdioContainer!Async + Error {
  match stdout {
    Stdout::Ignore => @uv.StdioContainer::ignore()
    Stdout::Pipe(pipe) => @uv.StdioContainer::create_pipe(pipe._, writable=true)
    Stdout::Stdin => @uv.StdioContainer::inherit_file(@uv.stdin())
    Stdout::Stdout => @uv.StdioContainer::inherit_file(@uv.stdout())
    Stdout::Stderr => @uv.StdioContainer::inherit_file(@uv.stderr())
    Stdout::Inherit(file) => @uv.StdioContainer::inherit_file(file._)
    Stdout::Capture => {
      let pipe = pipe!(ipc=false)
      let container = @uv.StdioContainer::create_pipe(pipe._, writable=true)
      self.stdout = Some(ReadableStream::new(pipe._))
      container
    }
    Stdout::Buffer(buffer) => {
      let pipe = pipe!(ipc=false)
      let container = @uv.StdioContainer::create_pipe(pipe._, writable=true)
      self.stdout = Some(ReadableStream::new(buffer~, pipe._))
      container
    }
  }
}

///|
fn Process::stderr(
  self : Process,
  stderr : Stdout
) -> @uv.StdioContainer!Async + Error {
  match stderr {
    Stdout::Ignore => @uv.StdioContainer::ignore()
    Stdout::Pipe(pipe) => @uv.StdioContainer::create_pipe(pipe._, writable=true)
    Stdout::Stdin => @uv.StdioContainer::inherit_file(@uv.stdin())
    Stdout::Stdout => @uv.StdioContainer::inherit_file(@uv.stdout())
    Stdout::Stderr => @uv.StdioContainer::inherit_file(@uv.stderr())
    Stdout::Inherit(file) => @uv.StdioContainer::inherit_file(file._)
    Stdout::Capture => {
      let pipe = pipe!(ipc=false)
      let container = @uv.StdioContainer::create_pipe(pipe._, writable=true)
      self.stderr = Some(ReadableStream::new(pipe._))
      container
    }
    Stdout::Buffer(buffer) => {
      let pipe = pipe!(ipc=false)
      let container = @uv.StdioContainer::create_pipe(pipe._, writable=true)
      self.stderr = Some(ReadableStream::new(buffer~, pipe._))
      container
    }
  }
}

///|
struct CompletedProcess {
  status : Int
  stdout : ReadableStream?
  stderr : ReadableStream?
}

///|
pub fn CompletedProcess::status(self : CompletedProcess) -> Int {
  self.status
}

///|
pub fn CompletedProcess::stdout(self : CompletedProcess) -> ReadableStream! {
  self.stdout.or_error!(MissingStdout)
}

///|
pub fn CompletedProcess::stderr(self : CompletedProcess) -> ReadableStream! {
  self.stderr.or_error!(MissingStderr)
}

///|
pub type! ProcessError {
  Terminated(Int)
  Failed(Int)
  MissingStdout
  MissingStderr
} derive(Show)

///|
pub fn spawn[Path : @path.ToPath + Show](
  path : Path,
  args : Array[&Show],
  stdin~ : Stdin = Stdin,
  stdout~ : Stdout = Stdout,
  stderr~ : Stdout = Stderr
) -> CompletedProcess!Async + Error {
  let uv = uv!()
  let path = path.to_path!()
  let args = args.map(fn(arg) { arg.to_string().view() })
  let stdio = []
  let process = Process::new()
  stdio.push(process.stdin!(stdin))
  stdio.push(process.stdout!(stdout))
  stdio.push(process.stderr!(stderr))
  suspend_with_error!(fn(
    resolve : (CompletedProcess) -> Unit,
    reject : (Error) -> Unit
  ) {
    let options = @uv.ProcessOptions::new(path, args, stdio~, fn(
      child,
      exit_status,
      term_signal
    ) {
      child.close(fn(_) {
        if term_signal != 0 {
          reject(ProcessError::Terminated(term_signal))
        } else if exit_status != 0 {
          reject(ProcessError::Failed(exit_status.to_int()))
        } else {
          resolve(CompletedProcess::{
            status: exit_status.to_int(),
            stdout: process.stdout,
            stderr: process.stderr,
          })
        }
      })
    })
    try {
      ignore(uv.spawn!(options))
      if process.stdin is Some(stdin) {
        run(fn() {
          try {
            stdin.write!()
          } catch {
            e => reject(e)
          }
        })
      }
      if process.stdout is Some(stdout) {
        run(fn() {
          try {
            stdout.read!()
          } catch {
            e => reject(e)
          }
        })
      }
      if process.stderr is Some(stderr) {
        run(fn() {
          try {
            stderr.read!()
          } catch {
            e => reject(e)
          }
        })
      }
    } catch {
      e => reject(e)
    }
  })
}

///|
pub fn start(f : () -> Unit!Async + Error) -> Unit! {
  let uv = uv!()
  let mut error = None
  run(fn() {
    try {
      f!()
    } catch {
      e => error = Some(e)
    }
  })
  println("running")
  uv.run!(Default)
  println("ran")
  uv.stop()
  uv.close!()
  if error is Some(error) {
    raise error
  }
}

///|
type Pipe @uv.Pipe

///|
pub fn pipe(ipc~ : Bool = false) -> Pipe! {
  let uv = uv!()
  @uv.Pipe::new!(uv, ipc~)
}
