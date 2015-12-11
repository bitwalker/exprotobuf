defmodule Protobuf.Parse.Test do
  use Protobuf.Case
  alias Protobuf.Parser

  test "parse string" do
    msg = "message Msg { required uint32 field1 = 1; }"
    [msg | _] = Parser.parse_string!(msg)
    assert is_tuple(msg)
  end

  test "parse process defs" do
    msg = [{
      {:msg, :Msg}, [
        {{:enum, :Type}, [TYPE1: 1]},
        {:field, :field1, 1, :undefined, {:ref, [:Type]}, :required, []}
      ]
    }]

    [_, {msg, [field]} | _] = Parser.parse_string!(msg)

    assert {:msg, :Msg} == msg
    assert {:enum, :"Msg.Type"} == elem(field, 4)
  end

  test "raise exception with parse error" do
    assert_raise Parser.ParserError, fn ->
      Parser.parse_string!("message ;")
    end
  end
end
