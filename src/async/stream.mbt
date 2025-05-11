///|
type AsyncIter[T] ((T) -> Unit!Async + Error) -> Unit!Async + Error

///|
pub fn AsyncIter::text(
  self : AsyncIter[@bytes.View],
  encoding~ : @encoding.Encoding = UTF8
) -> String!Async + Error {
  let decoder = @encoding.decoder(encoding)
  let builder = StringBuilder::new()
  (self._)!(fn(bytes) { decoder.decode_to!(bytes, builder, stream=true) })
  builder.to_string()
}

///|
pub fn AsyncIter::bytes(self : AsyncIter[@bytes.View]) -> Bytes!Async + Error {
  let buffer = @buffer.new()
  (self._)!(fn(bytes) { buffer.write_bytesview(bytes) })
  buffer.contents()
}

///|
pub fn AsyncIter::each[T](
  self : AsyncIter[T],
  f : (T) -> Unit
) -> Unit!Async + Error {
  (self._)!(fn(item) {
    f(item)
  })
}

///|
pub trait Readable {
  read(Self) -> AsyncIter[@bytes.View]!Async + Error
  read_text(Self, encoding~ : @encoding.Encoding) -> String!Async + Error = _
  read_bytes(Self) -> Bytes!Async + Error = _
}

///|
impl Readable with read_text(self : Self, encoding~ : @encoding.Encoding) {
  let decoder = @encoding.decoder(encoding)
  let builder = StringBuilder::new()
  (self.read!()._)!(fn(bytes) {
    decoder.decode_to!(bytes, builder, stream=true)
  })
  builder.to_string()
}

///|
impl Readable with read_bytes(self : Self) {
  let buffer = @buffer.new()
  (self.read!()._)!(fn(bytes) { buffer.write_bytesview(bytes) })
  buffer.contents()
}

///|
pub trait Writable {
  write(Self, @bytes.View) -> Unit!Async + Error
}

///|
impl Readable for @uv.Stream with read(self : @uv.Stream) {
  fn(yield_) -> Unit!Async + Error {
    suspend_with_error!(fn(resolve, reject) {
      try {
        self.read_start!(
          fn(_, _) { Bytes::make(256, 0)[:] },
          fn(_, count, bytes) {
            run(fn() {
              try {
                yield_!(bytes[:count])
              } catch {
                e => reject(e)
              }
            })
          },
          fn(_, e) {
            self.read_stop?() |> ignore()
            self.close(fn(_) {
              if e is Errno(EOF) {
                resolve(())
              } else {
                reject(e)
              }
            })
          },
        )
      } catch {
        e => self.close(fn(_) { reject(e) })
      }
    })
  }
}

///|
impl Writable for @uv.Stream with write(self : @uv.Stream, bytes : @bytes.View) {
  suspend_with_error!(fn(resolve, reject) {
    try {
      self.write!([bytes], fn(_) { resolve(()) }, fn(_, e) { reject(e) })
    } catch {
      e => reject(e)
    }
  })
}

///|
pub impl Readable for @bytes.View with read(self : @bytes.View) {
  fn(yield_) { yield_!(self) }
}

///|
pub impl Readable for Bytes with read(self : Bytes) {
  fn(yield_) { yield_!(self[:]) }
}

///|
pub impl Writable for @buffer.T with write(
  self : @buffer.T,
  bytes : @bytes.View
) {
  self.write_bytesview(bytes)
}

///|
pub impl Readable for Pipe with read(self : Pipe) {
  self._.to_stream().read!()
}

///|
pub impl Writable for Pipe with write(self : Pipe, bytes : @bytes.View) {
  Writable::write!(self._.to_stream(), bytes)
}

///|
priv struct Connection[Readable, Writable] {
  readable : Readable
  writable : Writable
}

///|
fn Connection::new[Readable : Readable, Writable : Writable](
  reader~ : Readable,
  writer~ : Writable
) -> Connection[Readable, Writable]!Async {
  Connection::{ readable: reader, writable: writer }
}

///|
fn Connection::readable[Readable, Writable](
  self : Connection[Readable, Writable]
) -> Readable {
  self.readable
}

///|
fn Connection::writable[Readable, Writable](
  self : Connection[Readable, Writable]
) -> Writable {
  self.writable
}

///|
fn Connection::start[Readable : Readable, Writable : Writable](
  self : Connection[Readable, Writable]
) -> Unit!Async + Error {
  (self.readable.read!()._)!(fn(bytes) { self.writable.write!(bytes) })
}
