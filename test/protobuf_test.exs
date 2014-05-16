defmodule ProtobufTest do
  use Protobuf.Case

  test "define records in namespace" do
    mod = def_proto_module "
       message Msg1 {
         required uint32 f1 = 1;
       }

       message Msg2 {
         required string f1 = 1;
       }
    "
    msg1 = mod.Msg1
    msg2 = mod.Msg2

    assert %{:__struct__ => ^msg1, :f1 => 1} = mod.Msg1.new(f1: 1)
    assert %{:__struct__ => ^msg2, :f1 => "foo"} = mod.Msg2.new(f1: "foo")
  end

  test "set default value for nil is optional" do
    mod = def_proto_module "message Msg { optional uint32 f1 = 1; }"
    msg = mod.Msg.new()
    assert nil == msg.f1
  end

  test "set default value for [] is repeated" do
    mod = def_proto_module "message Msg { repeated uint32 f1 = 1; }"
    msg = mod.Msg.new()
    assert [] == msg.f1
  end

  test "define a record in subnamespace" do
    mod = def_proto_module "
      message Msg {
        message SubMsg {
          required uint32 f1 = 1;
        }

        required SubMsg f1 = 1;
      }
    "

    msg = mod.Msg.SubMsg.new(f1: 1)
    module = mod.Msg.SubMsg
    assert %{__struct__: ^module} = msg

    msg = mod.Msg.new(f1: msg)
    assert %{__struct__: ^module} = msg.f1
  end

  test "define enum information module" do
    mod = def_proto_module "
      enum Version {
        V0_1 = 1;
        V0_2 = 2;
      }
      message Msg {
        enum MsgType {
          START = 1;
          STOP  = 2;
        }
        required MsgType type = 1;
        required Version version = 2;
      }
    "

    assert {:file, '#{__ENV__.file}'} == :code.is_loaded(mod.Version)
    assert {:file, '#{__ENV__.file}'} == :code.is_loaded(mod.Msg.MsgType)

    assert 1 == mod.Version.value(:V0_1)
    assert 1 == mod.Msg.MsgType.value(:START)

    assert :V0_2  == mod.Version.atom(2)
    assert :STOP == mod.Msg.MsgType.atom(2)

    assert nil == mod.Version.atom(-1)
    assert nil == mod.Msg.MsgType.value(:OTHER)
  end

  test "support define from a file" do
    defmodule ProtoFromFile do
      use Protobuf, from: Path.expand("./proto/basic.proto", __DIR__)
    end

    basic = ProtoFromFile.Basic.new(f1: 1)
    module = ProtoFromFile.Basic
    assert %{__struct__: ^module} = basic
  end

  test "define a method to get proto defs" do
    mod  = def_proto_module "message Msg { optional uint32 f1 = 1; }"
    defs = [{{:msg, mod.Msg}, [%Protobuf.Field{name: :f1, fnum: 1, rnum: 2, type: :uint32, occurrence: :optional, opts: []}]}]
    assert defs == mod.defs
    assert defs == mod.Msg.defs
  end

  test "defined a method defs to get field info" do
    mod  = def_proto_module "message Msg { optional uint32 f1 = 1; }"
    deff = %Protobuf.Field{name: :f1, fnum: 1, rnum: 2, type: :uint32, occurrence: :optional, opts: []}
    assert deff == mod.Msg.defs(:field, 1)
    assert deff == mod.Msg.defs(:field, :f1)
  end

  test "defined method decode" do
    mod = def_proto_module "message Msg { optional uint32 f1 = 1; }"
    module = mod.Msg
    assert %{:__struct__ => ^module} = mod.Msg.decode(<<>>)
  end

  test "extensions skip" do
    mod = def_proto_module "
      message Msg {
        required uint32 f1 = 1;
        extensions 100 to 200;
      }
    "
    module = mod.Msg
    assert %{:__struct__ => ^module} = mod.Msg.new
  end

  test "additional method via use_in" do
    defmodule AddViaHelper do
      use Protobuf, "message Msg {
        required uint32 f1 = 1;
      }"

      defmodule MsgHelper do
        defmacro __using__(_opts) do
          quote do
            def sub(%{:f1 => f1} = msg, value) do
              %{msg | :f1 => f1 - value}
            end
          end
        end
      end

      use_in :Msg, MsgHelper
    end

    msg = AddViaHelper.Msg.new(f1: 10)
    assert %{:f1 => 5} = AddViaHelper.Msg.sub(msg, 5)
  end
end
