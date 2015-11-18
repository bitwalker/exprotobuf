defmodule Protobuf.Parse.Test do
  use Protobuf.Case
  alias Protobuf.Parser

  test "parse string" do
    msg = "message Msg { required uint32 field1 = 1; }"
    {:ok, [msg | _]} = Parser.parse(msg)
    assert is_tuple(msg)
  end

  test "parse process defs" do
    msg = [{
      {:msg, :Msg}, [
        {{:enum, :Type}, [TYPE1: 1]},
        {:field, :field1, 1, :undefined, {:ref, [:Type]}, :required, []}
      ]
    }]

    [_, {msg, [field]} | _] = Parser.parse!(msg)

    assert {:msg, :Msg} == msg
    assert {:enum, :"Msg.Type"} == elem(field, 4)
  end

  @tag :skip # this behavior is replaced by the ability to pass a list of files in the `from:` option
  test "parse imports" do
    import_dir = Path.join("test", "proto") |> Path.expand
    proto      = File.read!(Path.join(import_dir, "import.proto"))
    expected = [{:package, :chat},
                {:option, [:java_package], 'com.appunite.chat'},
                {:import, 'imported.proto'},
                {{:msg, :WebsocketServerContainer}, [{:field, :authorization, 1, 2, :string, :required, []}]},
                {:package, :authorization},
                {:option, [:java_package], 'com.appunite.chat'},
                {{:msg, :WrongAuthorizationHttpMessage}, [{:field, :reason, 1, 2, :string, :required, []}]},
                {{:msg, :AuthorizationServerMessage}, [{:field, :next_synchronization_token, 1, 2, :string, :required, []}]}]
    assert expected == Parser.parse!(proto, [imports: [import_dir]])
  end

  test "return erro for parse error" do
    {result, _} = Parser.parse("message ;")
    assert :error == result
  end

  test "raise exception with parse error" do
    assert_raise Parser.ParserError, fn ->
      Parser.parse!("message ;")
    end
  end
end
