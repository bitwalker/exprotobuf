defmodule Protobuf.FromMultipleFiles.Test do
  use Protobuf.Case

  test "generates all messages nested under TopLevel" do
    defmodule TopLevel do
      use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                           Path.expand("../proto/import.proto", __DIR__),
                           Path.expand("../proto/imported.proto", __DIR__)]
    end

    assert %{reason: "hi"} = TopLevel.Authorization.WrongAuthorizationHttpMessage.new(reason: "hi")
    assert %{f1: 255} = TopLevel.Basic.new(f1: 255)
    assert %{authorization: "please?"} = TopLevel.Chat.WebsocketServerContainer.new(authorization: "please?")
  end

  test "generates all messages without nesting under NoTopLevel" do
    defmodule NoTopLevel do
      use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                           Path.expand("../proto/import.proto", __DIR__),
                           Path.expand("../proto/imported.proto", __DIR__)],
                    inject: true
    end

    assert %{reason: "deal with it"} = Authorization.WrongAuthorizationHttpMessage.new(reason: "deal with it")
    assert %{f2: "I do what I want"} = Basic.new(f2: "I do what I want")
    assert %{authorization: "please?"} = Chat.WebsocketServerContainer.new(authorization: "please?")
  end
end
