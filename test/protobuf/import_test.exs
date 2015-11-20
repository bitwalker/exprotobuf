defmodule Protobuf.Import.Test do
  use Protobuf.Case

  defmodule WebsocketServerContainer do
    use Protobuf, from: Path.expand("../proto/import.proto", __DIR__)
  end

  @tag :skip # this behavior is replaced by the ability to pass a list of files in the `from:` option
  test "can import protos" do
    msg = WebsocketServerContainer.AuthorizationServerMessage.new(next_synchronization_token: "2")
    assert %{next_synchronization_token: "2"} = msg
  end
end
