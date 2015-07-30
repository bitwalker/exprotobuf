defmodule Protobuf.Decoder.Test do
  use Protobuf.Case
  alias Protobuf.Decoder, as: D

  test "fix :undefined values to nil value" do
    defmodule UndefinedValuesProto do
      use Protobuf, """
        message Msg {
          optional int32 f1 = 1;
          required int32 f2 = 2;
        }
        """
    end

    module = UndefinedValuesProto.Msg
    assert %{:__struct__ => ^module, :f1 => nil, :f2 => 150} = D.decode(<<16, 150, 1>>, UndefinedValuesProto.Msg)
  end

  test "fix repeated values" do
    defmodule RepeatedValuesProto do
      use Protobuf, """
        message Msg {
            repeated string f1 = 1;
        }
        """
    end

    bytes = <<10, 3, 102, 111, 111, 10, 3, 98, 97, 114>>
    module = RepeatedValuesProto.Msg
    assert %{:__struct__ => ^module, :f1 => ["foo", "bar"]} = D.decode(bytes, RepeatedValuesProto.Msg)
  end

  test "fixing string values" do
    defmodule FixingStringValuesProto do
      use Protobuf, """
        message Msg {
          required string f1 = 1;

          message SubMsg {
            required string f1 = 1;
          }

          optional SubMsg f2 = 2;
        }
        """
    end

    bytes = <<10,11,?a,?b,?c,0o303,0o245,0o303,0o244,0o303,0o266,0o317,0o276>>
    module = FixingStringValuesProto.Msg
    submod = FixingStringValuesProto.Msg.SubMsg
    assert %{:__struct__ => ^module, :f1 => "abcåäöϾ", :f2 => nil} = D.decode(bytes, FixingStringValuesProto.Msg)

    bytes = <<10, 1, 97, 18, 5, 10, 3, 97, 98, 99>>
    assert %{:__struct__ => ^module, :f1 => "a", :f2 => %{:__struct__ => ^submod, :f1 => "abc"}} = D.decode(bytes, FixingStringValuesProto.Msg)
  end

  test "enums" do
    defmodule EnumsProto do
      use Protobuf, """
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
    end
    msg = EnumsProto.Msg.new(version: :'V2')
    encoded = EnumsProto.Msg.encode(msg)
    decoded = EnumsProto.Msg.decode(encoded)
    assert ^msg = decoded
  end

  test "extensions" do
    defmodule ExtensionsProto do
      use Protobuf, """
        message Regular {
          required string foo = 1;
        }

        message Extended {
          required string foo = 1;
          extensions 1000 to 1999;
        }

        extend Extended {
          optional int32 bar = 1003;
        }
      """
    end

    # for comparison, an extended schema vs an unextended schema.

    # here's the unextended one, note we lose bar:
    reg = ExtensionsProto.Regular.new(foo: "hello", bar: 12)
    assert reg.foo == "hello"
    catch_error(reg.bar) # Regular was not extended.

    reg_encoded = ExtensionsProto.Regular.encode(reg)
    reg_decoded = ExtensionsProto.Regular.decode(reg_encoded)
    assert ^reg = reg_decoded

    # here's the extended one, note we keep bar even though it's defined outside of the initial definition
    ex = ExtensionsProto.Extended.new(foo: "hello", bar: 12)
    assert ex.foo == "hello"
    assert ex.bar == 12

    ex_encoded = ExtensionsProto.Extended.encode(ex)
    ex_decoded = ExtensionsProto.Extended.decode(ex_encoded)
    assert ^ex = ex_decoded

  end

  test "complex proto decoding" do
    defmodule MumbleProto do
      use Protobuf, from: Path.expand("../proto/mumble.proto", __DIR__)
    end

    msg = MumbleProto.Authenticate.new(username: "bitwalker")
    assert %{username: "bitwalker", password: nil, tokens: []} = msg
  end
end
