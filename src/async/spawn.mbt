///|
pub(all) enum ProcessInput {
  Ignore
  Stdin
  Pipe(Pipe)
  Inherit(File)
}

///|
pub(all) enum ProcessOutput {
  Ignore
  Stdout
  Stderr
  Pipe(Pipe)
  Inherit(File)
}

///|
fn ProcessInput::create(
  self : ProcessInput,
  stdio : Array[@uv.StdioContainer]
) -> Unit {
  match self {
    Ignore => stdio.push(@uv.StdioContainer::ignore())
    Inherit(file) => stdio.push(@uv.StdioContainer::inherit_file(file._))
    Pipe(pipe) =>
      stdio.push(@uv.StdioContainer::create_pipe(pipe._, readable=true))
    Stdin => stdio.push(@uv.StdioContainer::inherit_file(@uv.stdin()))
  }
}

///|
fn ProcessOutput::create(
  self : ProcessOutput,
  stdio : Array[@uv.StdioContainer]
) -> Unit {
  match self {
    Ignore => stdio.push(@uv.StdioContainer::ignore())
    Inherit(file) => stdio.push(@uv.StdioContainer::inherit_file(file._))
    Pipe(pipe) =>
      stdio.push(@uv.StdioContainer::create_pipe(pipe._, writable=true))
    Stdout => stdio.push(@uv.StdioContainer::inherit_file(@uv.stdout()))
    Stderr => stdio.push(@uv.StdioContainer::inherit_file(@uv.stderr()))
  }
}

///|
struct Process {
  mut process : @uv.Process?
  resolve : Array[() -> Unit]
  mut status : Int?
  mut signal : Int?
}

///|
async fn Process::wait(self : Process) -> Unit {
  if self.status is Some(_) {
    return
  }
  async_suspend!(fn(resolve) { self.resolve.push(fn() { resolve(()) }) })
}

///|
pub async fn Process::status(self : Process) -> Int {
  self.wait!()
  guard self.status is Some(status)
  status
}

///|
pub async fn Process::signal(self : Process) -> Int {
  self.wait!()
  guard self.signal is Some(signal)
  signal
}

///|
pub fn Process::kill(self : Process, signum : Signum) -> Unit!Error {
  guard self.process is Some(process)
  let signum = match signum {
    SIGHUP => @uv.Signum::sighup()
    SIGINT => @uv.Signum::sigint()
    SIGQUIT => @uv.Signum::sigquit()
    SIGABRT => @uv.Signum::sigabrt()
    SIGTERM => @uv.Signum::sigterm()
    SIGWINCH => @uv.Signum::sigwinch()
    SIGPIPE => @uv.Signum::sigpipe!()
  }
  process.kill!(signum)
}

///|
trait Executable {
  spawn(
    Self,
    Array[@string.View],
    cwd~ : Path?,
    stdin~ : ProcessInput,
    stdout~ : ProcessOutput,
    stderr~ : ProcessOutput,
  ) -> Process!Error
}

///|
pub impl Executable for String with spawn(
  self : String,
  args : Array[@string.View],
  cwd~ : Path?,
  stdin~ : ProcessInput,
  stdout~ : ProcessOutput,
  stderr~ : ProcessOutput
) -> Process!Error {
  let uv = uv!()
  let args : Array[@string.View] = [
      self,
      ..args.map(fn(arg) { arg.to_string().view() }),
    ]
  let cwd = cwd.map(fn(cwd) { cwd.to_string().view() })
  let stdio = []
  stdin.create(stdio)
  stdout.create(stdio)
  stderr.create(stdio)
  let process = Process::{
    process: None,
    resolve: [],
    status: None,
    signal: None,
  }
  let options = @uv.ProcessOptions::new(self, args, stdio~, cwd?, fn(
    child,
    exit_status,
    term_signal
  ) {
    process.status = Some(exit_status.to_int())
    process.signal = Some(term_signal)
    child.close(fn(_) {
      for resolve in process.resolve {
        resolve()
      }
    })
  })
  process.process = Some(uv.spawn!(options))
  process
}

///|
pub impl Executable for &ToPath with spawn(
  self : &ToPath,
  args : Array[@string.View],
  cwd~ : Path?,
  stdin~ : ProcessInput,
  stdout~ : ProcessOutput,
  stderr~ : ProcessOutput
) -> Process!Error {
  self.to_string() |> Executable::spawn(args, cwd~, stdin~, stdout~, stderr~)
}

///|
pub async fn[Exec : Executable] spawn(
  exec : Exec,
  args : Array[@string.View],
  cwd? : &ToPath,
  stdin~ : ProcessInput = Ignore,
  stdout~ : ProcessOutput = Ignore,
  stderr~ : ProcessOutput = Ignore
) -> Process! {
  exec.spawn!(args, cwd=cwd.map(_.to_path()), stdin~, stdout~, stderr~)
}
