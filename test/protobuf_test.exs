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

  test "define records in namespace with injection" do
    mod = def_proto_module ["
       message Msg1 {
         required uint32 f1 = 1;
       }
    ", only: :Msg1, inject: true]

    assert %{:__struct__ => ^mod, :f1 => 1} = mod.new(f1: 1)
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

    assert {:file, :in_memory} == :code.is_loaded(mod.Version)
    assert {:file, :in_memory} == :code.is_loaded(mod.Msg.MsgType)

    assert 1 == mod.Version.value(:V0_1)
    assert 1 == mod.Msg.MsgType.value(:START)

    assert :V0_2  == mod.Version.atom(2)
    assert :STOP == mod.Msg.MsgType.atom(2)

    assert nil == mod.Version.atom(-1)
    assert nil == mod.Msg.MsgType.value(:OTHER)

    assert [:V0_1, :V0_2] == mod.Version.atoms
    assert [:START, :STOP] == mod.Msg.MsgType.atoms

    assert [1, 2] == mod.Version.values
    assert [1, 2] == mod.Msg.MsgType.values
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

  test "normalize unconventional (lowercase) styles of named messages and enums" do
    mod = def_proto_module "
        message msgPackage {
          enum msgResponseType {
            NACK = 0;
            ACK = 1;
          }

          message msgHeader {
            required uint32 message_id = 0;
            required msgResponseType response_type = 1;
          }

          required msgHeader header = 1;
        }
      "

    assert 0 == mod.MsgPackage.MsgResponseType.value(:NACK)
    assert 1 == mod.MsgPackage.MsgResponseType.value(:ACK)

    assert :NACK == mod.MsgPackage.MsgResponseType.atom(0)
    assert :ACK == mod.MsgPackage.MsgResponseType.atom(1)

    msg_header = mod.MsgPackage.MsgHeader

    assert %{:__struct__    => ^msg_header,
             :response_type => :ACK,
             :message_id    => 25 } = mod.MsgPackage.MsgHeader.new(response_type: :ACK, message_id: 25)

    msg_package = mod.MsgPackage
    nack_msg_header = mod.MsgPackage.MsgHeader.new(message_id: 1, response_type: :NACK)
    nack_msg_package = mod.MsgPackage.new(header: msg_header)

    assert %{:__struct__ => ^msg_package, :header => nack_msg_header} = mod.MsgPackage.new(header: nack_msg_header)
  end
end
