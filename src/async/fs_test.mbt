///|
test "open" {
  @async.start!(fn() {
    @async.path!("moon.mod.json").read!().text!()
    |> @json.parse!()
    |> @json.inspect!(content={
      "name": "tonyfettes/uv",
      "version": "0.2.0",
      "deps": { "tonyfettes/c": "0.1.13", "tonyfettes/encoding": "0.3.1" },
      "readme": "README.md",
      "repository": "https://github.com/tonyfettes/uv.mbt",
      "license": "Apache-2.0",
      "keywords": [],
      "description": "MoonBit binding to libuv",
      "source": "src",
    })
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
