defmodule Protobuf.FromMultipleFiles.Test do
  use Protobuf.Case

  test "generates all messages nested under TopLevel" do
    defmodule TopLevel do
      use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                           Path.expand("../proto/imported.proto", __DIR__)]
    end

    assert %{f1: 255} = TopLevel.Basic.new(f1: 255)
    assert %{reason: "hi"} = TopLevel.Authorization.WrongAuthorizationHttpMessage.new(reason: "hi")
  end

  test "generates all messages without nesting under NoTopLevel" do
    defmodule NoTopLevel do
      use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                           Path.expand("../proto/imported.proto", __DIR__)],
                    inject: true
    end

    assert %{reason: "deal with it"} = Authorization.WrongAuthorizationHttpMessage.new(reason: "deal with it")
    assert %{f2: "I do what I want"} = Basic.new(f2: "I do what I want")
  end
end
