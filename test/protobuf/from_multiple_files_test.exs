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

  test "can parse custom options" do
    defmodule TopLevel do
      use Protobuf, from: [Path.expand("../proto/custom_option.proto", __DIR__),
                           Path.expand("../proto/descriptor.proto", __DIR__)],
        use_package_names: true
    end

    msg_def = TopLevel.Basic.defs |> Enum.filter(
      fn {{type, ns}, _} -> type == :msg and
        ns == Protobuf.FromMultipleFiles.Test.TopLevel.Basic end)
    opts = get_in(msg_def, [Access.at(0), Access.elem(1), Access.at(0), Access.key(:opts)])
    my_field_option = Enum.filter(opts, fn opt ->
      is_tuple(opt) and elem(opt, 0) |> Enum.at(0) == :my_field_option end) |> Enum.at(0)
    assert {[:my_field_option], 4.5} = my_field_option
  end

  test "can parse custom options works with inject" do
    defmodule Basic do
      use Protobuf, from: [Path.expand("../proto/custom_option.proto", __DIR__),
                           Path.expand("../proto/descriptor.proto", __DIR__)],
        use_package_names: true, inject: true
    end

    msg_def = Basic.defs |> Enum.filter(
      fn {{type, ns}, _} -> type == :msg and
        ns == Basic end)
    IO.inspect(Basic.defs)
    opts = get_in(msg_def, [Access.at(0), Access.elem(1), Access.at(0), Access.key(:opts)])
    my_field_option = Enum.filter(opts, fn opt ->
      is_tuple(opt) and elem(opt, 0) |> Enum.at(0) == :my_field_option end) |> Enum.at(0)
    assert {[:my_field_option], 4.5} = my_field_option
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
