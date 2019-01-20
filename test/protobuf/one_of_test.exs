defmodule Protobuf.Oneof.Test do
  use Protobuf.Case

  defmodule Msgs do
    use Protobuf, from: Path.expand("../proto/one_of.proto", __DIR__)
  end

  test "oneof macro in dynamic expression" do
    require Msgs.SampleOneofMsg.OneOf.Foo, as: Foo
    assert {:body, "HELLO"} == Foo.body("hello" |> String.upcase)
    assert {:code, 0} == Foo.code(1 - 1)
  end

  test "oneof macro in pattern matching" do
    require Msgs.SampleOneofMsg, as: Msg
    require Msgs.SampleOneofMsg.OneOf.Foo, as: Foo
    %Msg{
      one: "hello",
      foo: Foo.body("world" |> String.upcase)
    }
    |> Msg.encode
    |> Msg.decode
    |> case do
      %Msg{one: "hello", foo: Foo.body("WORLD")} -> assert true
      %Msg{} -> assert false
    end
  end

  test "can create one_of protos" do
    msg = Msgs.SampleOneofMsg.new(one: "test", foo: {:body, "xxx"})
    assert %{one: "test", foo: {:body, "xxx"}} = msg
  end

  test "can encode simple one_of protos" do
    msg = Msgs.SampleOneofMsg.new(one: "test", foo: {:body, "xxx"})

    encoded = Protobuf.Serializable.serialize(msg)
    binary = <<10, 4, 116, 101, 115, 116, 26, 3, 120, 120, 120>>

    assert binary == encoded
  end

  test "can decode simple one_of protos" do
    binary = <<10, 4, 116, 101, 115, 116, 26, 3, 120, 120, 120>>

    msg = Msgs.SampleOneofMsg.decode(binary)
    assert %Msgs.SampleOneofMsg{foo: {:body, "xxx"}, one: "test"} == msg
  end

  test "stucture parsed simple one_of proto properly" do
    defs = Msgs.SampleOneofMsg.defs(:field, :foo)

    assert %Protobuf.OneOfField{fields: [%Protobuf.Field{fnum: 3, name: :body, occurrence: :optional, opts: [], rnum: 3, type: :string},
              %Protobuf.Field{fnum: 4, name: :code, occurrence: :optional, opts: [], rnum: 3, type: :uint32}], name: :foo, rnum: 3} = defs

  end

  test "can create one_of protos with sub messages" do
    msg = Msgs.AdvancedOneofMsg.new(one: Msgs.SubMsg.new(test: "xxx"),
                                          foo: {:body, Msgs.SubMsg.new(test: "yyy")})

    assert %{one: %{test: "xxx"}, foo: {:body, %{test: "yyy"}}} = msg
  end

  test "can encode one_of protos with sub messages" do
    msg = Msgs.AdvancedOneofMsg.new(one: Msgs.SubMsg.new(test: "xxx"), foo: {:body, Msgs.SubMsg.new(test: "yyy")})


    encoded = Protobuf.Serializable.serialize(msg)

    binary = <<10, 5, 10, 3, 120, 120, 120, 26, 5, 10, 3, 121, 121, 121>>

    assert binary == encoded
  end

  test "can decode one_of protos with sub messages" do
    binary = <<10, 5, 10, 3, 120, 120, 120, 26, 5, 10, 3, 121, 121, 121>>

    msg = Msgs.AdvancedOneofMsg.decode(binary)
    assert %Msgs.AdvancedOneofMsg{foo: {:body,  Msgs.SubMsg.new(test: "yyy")}, one: Msgs.SubMsg.new(test: "xxx")} == msg
  end

  test "can encode one_of protos with one_of field on first position" do
    msg = Msgs.ReversedOrderOneOfMsg.new(foo: {:code, 32}, bar: "hi")
    enc_msg = Protobuf.Serializable.serialize(msg)

    assert is_binary(enc_msg)
  end

  test "can decode one_of protos with one_of field on first position" do
    enc_msg= <<16, 32, 26, 2, 104, 105>>
    dec_msg = Msgs.ReversedOrderOneOfMsg.decode(enc_msg)

    assert Msgs.ReversedOrderOneOfMsg.new(foo: {:code, 32}, bar: "hi") == dec_msg
  end


end
