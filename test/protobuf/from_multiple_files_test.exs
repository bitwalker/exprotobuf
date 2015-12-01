defmodule Protobuf.FromMultipleFiles.Test do
  use Protobuf.Case

  test "generates all messages nested under TopLevel" do
    defmodule TopLevel do
      use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                           Path.expand("../proto/import.proto", __DIR__),
                           Path.expand("../proto/imported.proto", __DIR__)]
    end

    assert %{reason: "hi"} = TopLevel.WrongAuthorizationHttpMessage.new(reason: "hi")
    assert %{f1: 255} = TopLevel.Basic.new(f1: 255)
    assert %{authorization: "please?"} = TopLevel.WebsocketServerContainer.new(authorization: "please?")
  end
end
