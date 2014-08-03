defmodule Protobuf.Decoder.Test do
  use Protobuf.Case
  alias Protobuf.Decoder, as: D

  test "fix :undefined values to nil value" do
    mod = def_proto_module "message Msg {
      optional int32 f1 = 1;
      required int32 f2 = 2;
    }"

    module = mod.Msg
    assert %{:__struct__ => ^module, :f1 => nil, :f2 => 150} = D.decode(<<16, 150, 1>>, mod.Msg)
  end

  test "fix repeated values" do
    mod = def_proto_module "message Msg {
      repeated string f1 = 1;
    }"

    bytes = <<10, 3, 102, 111, 111, 10, 3, 98, 97, 114>>
    module = mod.Msg
    assert %{:__struct__ => ^module, :f1 => ["foo", "bar"]} = D.decode(bytes, mod.Msg)
  end

  test "fixing string values" do
    mod = def_proto_module "message Msg {
      required string f1 = 1;

      message SubMsg {
        required string f1 = 1;
      }

      optional SubMsg f2 = 2;
    }"

    bytes = <<10,11,?a,?b,?c,0o303,0o245,0o303,0o244,0o303,0o266,0o317,0o276>>
    module = mod.Msg
    submod = mod.Msg.SubMsg
    assert %{:__struct__ => ^module, :f1 => "abcåäöϾ", :f2 => nil} = D.decode(bytes, mod.Msg)

    bytes = <<10, 1, 97, 18, 5, 10, 3, 97, 98, 99>>
    assert %{:__struct__ => ^module, :f1 => "a", :f2 => %{:__struct__ => ^submod, :f1 => "abc"}} = D.decode(bytes, mod.Msg)
  end

  test "enums" do
    mod = def_proto_module """
      message Msg {
        message SubMsg {
          required uint32 value = 1;
        }

        enum Version {
          V1 = 1;
          V2 = 2;
        }

        required Version version = 2;
        optional SubMsg sub = 1;
      }
      """
    msg = mod.Msg.new(version: :'V2')
    encoded = mod.Msg.encode(msg)
    decoded = mod.Msg.decode(encoded)
    assert ^msg = decoded
  end
end
