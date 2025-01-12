
///|
/// Write a char into buffer as UTF8.
fn write_utf8_char(buf : @buffer.T, value : Char) -> Unit {
  let code = value.to_uint()
  match code {
    _..<0x80 => {
      let b0 = ((code & 0x7F) | 0x00).to_byte()
      buf.write_byte(b0)
    }
    _..<0x0800 => {
      let b0 = (((code >> 6) & 0x1F) | 0xC0).to_byte()
      let b1 = ((code & 0x3F) | 0x80).to_byte()
      buf.write_byte(b0)
      buf.write_byte(b1)
    }
    _..<0x010000 => {
      let b0 = (((code >> 12) & 0x0F) | 0xE0).to_byte()
      let b1 = (((code >> 6) & 0x3F) | 0x80).to_byte()
      let b2 = ((code & 0x3F) | 0x80).to_byte()
      buf.write_byte(b0)
      buf.write_byte(b1)
      buf.write_byte(b2)
    }
    _..<0x110000 => {
      let b0 = (((code >> 18) & 0x07) | 0xF0).to_byte()
      let b1 = (((code >> 12) & 0x3F) | 0x80).to_byte()
      let b2 = (((code >> 6) & 0x3F) | 0x80).to_byte()
      let b3 = ((code & 0x3F) | 0x80).to_byte()
      buf.write_byte(b0)
      buf.write_byte(b1)
      buf.write_byte(b2)
      buf.write_byte(b3)
    }
    _ => abort("Char out of range")
  }
}

///|
pub fn string_to_utf8(string : String) -> Bytes {
  let buffer = @buffer.new(size_hint=string.length() * 2)
  for char in string {
    write_utf8_char(buffer, char)
  }
  buffer.contents()
}

///|
pub fn utf8_to_string(bytes : Bytes) -> String {
  let buffer = @buffer.new(size_hint=bytes.length())
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int()
    let char = if b0 < 0x80 {
      i += 1
      Char::from_int(b0)
    } else if b0 < 0xE0 {
      let b1 = bytes[i + 1].to_int()
      i += 2
      Char::from_int(((b0 & 0x1F) << 6) | (b1 & 0x3F))
    } else if b0 < 0xF0 {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      i += 3
      Char::from_int(((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F))
    } else {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      let b3 = bytes[i + 3].to_int()
      i += 4
      Char::from_int(
        ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F),
      )
    }
    buffer.write_char(char)
  }
  buffer.contents().to_unchecked_string()
}
