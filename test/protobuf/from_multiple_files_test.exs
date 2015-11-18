defmodule Protobuf.FromMultipleFiles.Test do
  use Protobuf.Case

  defmodule TopLevel do
    use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                         Path.expand("../proto/mumble.proto", __DIR__)]
  end

  test "generates all messages nested under TopLevel" do
    assert %{f1: 255} = TopLevel.Basic.new(f1: 255)
    assert %{version: 127} = TopLevel.MumbleProto.Version.new(version: 127)
    assert %{packet: "abc"} = TopLevel.MumbleProto.UDPTunnel.new(bytes: "abc")
  end

  defmodule NoTopLevel do
    use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                         Path.expand("../proto/mumble.proto", __DIR__)],
                  inject: true
  end

  test "generates all messages without nesting under NoTopLevel" do
    assert %{reason: "deal with it"} = Authorization.WrongAuthorizationHttpMessage.new(reason: "deal with it")
    assert %{authorization: "I do what I want"} = Chat.WebsocketServerContainer.new(authorization: "I do what I want")
  end
end
