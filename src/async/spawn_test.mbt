///|
test "spawn: capture stdout and stderr" {
  @async.start!(fn() {
    let stdout = @async.Pipe::new!()
    let process = @async.spawn!("moon", ["--help"], stdout=Pipe(stdout))
    @json.inspect!(process.status!(), content=0)
    inspect!(
      stdout.read_text!(encoding=UTF8),
      content=
        #|The build system and package manager for MoonBit.
        #|
        #|Usage: moon [OPTIONS] <COMMAND>
        #|
        #|Commands:
        #|  new                    Create a new MoonBit module
        #|  build                  Build the current package
        #|  check                  Check the current package, but don't build object files
        #|  run                    Run a main package
        #|  test                   Test the current package
        #|  clean                  Remove the target directory
        #|  fmt                    Format source code
        #|  doc                    Generate documentation
        #|  info                   Generate public interface (`.mbti`) files for all packages in the module
        #|  bench                  Run benchmarks in the current package
        #|  add                    Add a dependency
        #|  remove                 Remove a dependency
        #|  install                Install dependencies
        #|  tree                   Display the dependency tree
        #|  login                  Log in to your account
        #|  register               Register an account at mooncakes.io
        #|  publish                Publish the current module
        #|  package                Package the current module
        #|  update                 Update the package registry index
        #|  coverage               Code coverage utilities
        #|  generate-build-matrix  Generate build matrix for benchmarking (legacy feature)
        #|  upgrade                Upgrade toolchains
        #|  shell-completion       Generate shell completion for bash/elvish/fish/pwsh/zsh to stdout
        #|  version                Print version information and exit
        #|  help                   Print this message or the help of the given subcommand(s)
        #|
        #|Options:
        #|  -h, --help  Print help
        #|
        #|Common Options:
        #|  -C, --directory <SOURCE_DIR>   The source code directory. Defaults to the current directory
        #|      --target-dir <TARGET_DIR>  The target directory. Defaults to `source_dir/target`
        #|  -q, --quiet                    Suppress output
        #|  -v, --verbose                  Increase verbosity
        #|      --trace                    Trace the execution of the program
        #|      --dry-run                  Do not actually run the command
        #|      --build-graph              Generate build graph
        #|
      ,
    )
  })
}

///|
test "spawn: send stdin" {
  @async.start!(fn() {
    if @async.system() != "Windows" {
      let stdin = @async.Pipe::new!()
      let stdout = @async.Pipe::new!()
      let process = @async.spawn!(
        "cat",
        [],
        stdin=Pipe(stdin),
        stdout=Pipe(stdout),
      )
      stdin.write_bytes!("hello\n")
      stdin.close!()
      @json.inspect!(process.status!(), content=0)
      @json.inspect!(stdout.read_text!(encoding=UTF8), content="hello\n")
    }
  })
}
