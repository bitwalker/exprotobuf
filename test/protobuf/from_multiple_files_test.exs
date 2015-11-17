defmodule Protobuf.FromMultipleFiles.Test do
  use Protobuf.Case

  defmodule Broker do
    use Protobuf, from: Path.wildcard(Path.expand("../proto/broker/*.proto", __DIR__))
  end

  test "all the messages are generated" do
    assert %Broker.Error{field: "test"} = Broker.Error.new(field: "test")
    assert %Broker.Exchange{id: "test"} = Broker.Exchange.new(id: "test")
  end
end
