///|
test "open" {
  @async.start!(fn() {
    let moon_mod_json = @async.path!("moon.mod.json").read!().text!()
      |> @json.parse!()
    assert_true!(moon_mod_json is Object({ "name": "tonyfettes/uv", .. }))
  })
}

///|
test "scandir" {
  @async.start!(fn() {
    @json.inspect!(@async.path!(["test", "fixtures"]).iter!().collect(), content=[
      "test/fixtures/example.txt",
    ])
  })
}
