defmodule Protobuf.Parse.Test do
  use Protobuf.Case
  alias Protobuf.Parser

  test "parse string" do
    msg = "message Msg { required uint32 field1 = 1; }"
    [msg | _] = Parser.parse_string!("nofile", msg, [])
    assert is_tuple(msg)
  end

  test "raise exception with parse error" do
    assert_raise Parser.ParserError, fn ->
      Parser.parse_string!("nofile", "message ;", [])
    end
  end
end
