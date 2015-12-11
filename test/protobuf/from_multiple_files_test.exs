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

  test "prefixs module names with the package names" do
    defmodule WithPackageNames do
      use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                           Path.expand("../proto/import.proto", __DIR__),
                           Path.expand("../proto/imported.proto", __DIR__)],
                    use_package_names: true
    end

    assert %{reason: "hi"} = WithPackageNames.Authorization.WrongAuthorizationHttpMessage.new(reason: "hi")
    assert %{f1: 255} = WithPackageNames.Basic.new(f1: 255)
    assert %{authorization: "please?"} = WithPackageNames.Chat.WebsocketServerContainer.new(authorization: "please?")
  end

  test "can specify an arbitrary namespace for defining protobuf messages" do
    defmodule UnusedNamespace do
      use Protobuf, from: [Path.expand("../proto/basic.proto", __DIR__),
                           Path.expand("../proto/import.proto", __DIR__),
                           Path.expand("../proto/imported.proto", __DIR__)],
                    use_package_names: true,
                    namespace: :"Elixir"
    end

    assert %{reason: "hi"} = Authorization.WrongAuthorizationHttpMessage.new(reason: "hi")
    assert %{f1: 255} = Basic.new(f1: 255)
    assert %{authorization: "please?"} = Chat.WebsocketServerContainer.new(authorization: "please?")
  end
end
