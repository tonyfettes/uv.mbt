///|
pub type! Errno Int

///|
pub fn errno(status : Int) -> Unit!Errno {
  if status < 0 {
    raise Errno(status)
  }
}

///|
let errno_map : Map[Int, String] = Map::new()

///|
pub impl Show for Errno with output(self : Errno, logger : &Logger) -> Unit {
  let Errno(errno) = self
  if errno_map.get(errno) is Some(message) {
    logger.write_string(message)
    return
  }
  let message = Bytes::make(256, 0)
  @uv.strerror_r(errno, message)
  let message = utf8_to_string(message)
  errno_map[errno] = message
  logger.write_string(message)
}
