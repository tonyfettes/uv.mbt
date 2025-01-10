///|
type Code

///|
type Data

///|
pub extern "c" fn moonbit_ffi_make_closure(code : Code, data : Data) -> Data = "moonbit_ffi_make_closure"

///|
fn init {
  moonbit_ffi_make_closure |> ignore
}

///|
fn identity[T, U](value : T) -> U = "%identity"
