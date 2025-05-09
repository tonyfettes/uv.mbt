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
  Stdout
  Stderr
  Inherit(File)
  Capture
}

///|
priv struct Process {
  mut stdin : Connection[@bytes.View, Pipe]?
  mut stdout : Connection[Pipe, @buffer.T]?
  mut stderr : Connection[Pipe, @buffer.T]?
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
      self.stdin = Some(Connection::new!(writer=pipe, reader=bytes))
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
    Stdout::Stdout => @uv.StdioContainer::inherit_file(@uv.stdout())
    Stdout::Stderr => @uv.StdioContainer::inherit_file(@uv.stderr())
    Stdout::Inherit(file) => @uv.StdioContainer::inherit_file(file._)
    Stdout::Capture => {
      let pipe = pipe!(ipc=false)
      let container = @uv.StdioContainer::create_pipe(pipe._, writable=true)
      self.stdout = Some(Connection::new!(reader=pipe, writer=@buffer.new()))
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
    Stdout::Stdout => @uv.StdioContainer::inherit_file(@uv.stdout())
    Stdout::Stderr => @uv.StdioContainer::inherit_file(@uv.stderr())
    Stdout::Inherit(file) => @uv.StdioContainer::inherit_file(file._)
    Stdout::Capture => {
      let pipe = pipe!(ipc=false)
      let container = @uv.StdioContainer::create_pipe(pipe._, writable=true)
      self.stderr = Some(Connection::new!(reader=pipe, writer=@buffer.new()))
      container
    }
  }
}

///|
struct CompletedProcess {
  status : Int
  stdout : Bytes?
  stderr : Bytes?
}

///|
pub fn CompletedProcess::status(self : CompletedProcess) -> Int {
  self.status
}

///|
pub fn CompletedProcess::stdout(
  self : CompletedProcess
) -> AsyncIter[@bytes.View]!Async + Error {
  self.stdout.or_error!(MissingStdout).read!()
}

///|
pub fn CompletedProcess::stderr(
  self : CompletedProcess
) -> AsyncIter[@bytes.View]!Async + Error {
  self.stderr.or_error!(MissingStderr).read!()
}

///|
pub type! ProcessError {
  Terminated(Int)
  Failed(Int)
  MissingStdout
  MissingStderr
} derive(Show)

///|
pub fn spawn[Path : ToPath + Show](
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
            stdout: process.stdout.map(fn(stdout) {
              stdout.writable().contents()
            }),
            stderr: process.stderr.map(fn(stderr) {
              stderr.writable().contents()
            }),
          })
        }
      })
    })
    try {
      ignore(uv.spawn!(options))
      if process.stdin is Some(stdin) {
        run(fn() {
          try {
            stdin.start!()
          } catch {
            e => reject(e)
          }
        })
      }
      if process.stdout is Some(stdout) {
        run(fn() {
          try {
            stdout.start!()
          } catch {
            e => reject(e)
          }
        })
      }
      if process.stderr is Some(stderr) {
        run(fn() {
          try {
            stderr.start!()
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
