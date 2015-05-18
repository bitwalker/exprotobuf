defmodule Protobuf.Encoder.Test do
  use Protobuf.Case
  alias Protobuf.Encoder, as: E

  setup_all do
    {:ok, mod: def_proto_module "
      message Msg {
        required int32 f1 = 1;
        optional int32 f2 = 2;
      }

      message WithSubMsg {
        required Msg f1 = 1;
      }

      message WithRepeatedSubMsg {
        repeated Msg f1 = 1;
      }

      message extraMsg {
        enum msgType {
          NACK = 0;
          ACK = 1;
        }

        required msgType type = 1;
        repeated Msg message = 2;
      }

      message WithEnum {
        enum Version {
          V1 = 1;
          V2 = 2;
        }

        required Version version = 1;
      }
    "}
  end

  test "fixing nil values to :undefined", var do
    mod = var[:mod]
    msg = mod.Msg.new(f1: 150)
    assert <<8, 150, 1>> == E.encode(msg, mod.Msg.defs)
    assert <<10, 3, 8, 150, 1>> == E.encode(mod.WithSubMsg.new(f1: msg), mod.Msg.defs)
  end

  test "fixing a nil value in repeated submsg", var do
    mod = var[:mod]
    msg = mod.WithRepeatedSubMsg.new(f1: [mod.Msg.new(f1: 1)])
    assert <<10, 2, 8, 1>> == E.encode(msg, mod.WithRepeatedSubMsg.defs)
  end

  test "fixing lowercase message and enum references", var do
    mod = var[:mod]
    msg = mod.ExtraMsg.new(type: :ACK, message: [mod.Msg.new(f1: 1)])
    assert <<8, 1, 18, 2, 8, 1>> == E.encode(msg, mod.ExtraMsg.defs)
  end

  test "encodes enums", var do
    mod = var[:mod]
    msg = mod.WithEnum.new(version: :'V1')
    assert <<8, 1>> == E.encode(msg, mod.WithEnum.defs)
  end
end
