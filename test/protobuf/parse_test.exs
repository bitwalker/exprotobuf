defmodule Protobuf.Parse.Test do
  use Protobuf.Case
  alias Protobuf.Parse

  test "parse string" do
    msg = "message Msg { required uint32 field1 = 1; }"
    {:ok, [msg | _]} = Parse.parse(msg)
    assert is_tuple(msg)
  end

  test "parse process defs" do
    msg = [{
      {:msg, :Msg}, [
        {{:enum, :Type}, [TYPE1: 1]},
        {:field, :field1, 1, :undefined, {:ref, [:Type]}, :required, []}
      ]
    }]

    [_, {msg, [field]} | _] = Parse.parse!(msg)

    assert {:msg, :Msg} == msg
    assert {:enum, :"Msg.Type"} == elem(field, 4)
  end

  test "return erro for parse error" do
    {result, _} = Parse.parse("message ;")
    assert :error == result
  end

  test "raise exception with parse error" do
    assert_raise Parse.ParseError, fn ->
      Parse.parse!("message ;")
    end
  end
end
