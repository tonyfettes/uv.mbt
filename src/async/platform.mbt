///|
let utsname_ref : Ref[@uv.Utsname?] = Ref::new(None)

///|
fn utsname() -> @uv.Utsname! {
  if utsname_ref.val is Some(utsname) {
    return utsname
  }
  let utsname = @uv.os_uname!()
  utsname_ref.val = Some(utsname)
  return utsname
}

///|
pub fn system() -> String! {
  utsname().sysname()
}
