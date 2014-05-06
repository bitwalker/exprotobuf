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
end
