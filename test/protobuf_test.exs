defmodule ProtobufTest do
  use Protobuf.Case

  test "can roundtrip encoding/decoding optional values in proto2" do
    defmodule RoundtripProto2 do
      use Protobuf, """
      message Msg {
        optional string f1 = 1;
        optional string f2 = 2 [default = "test"];
        optional uint32 f3 = 3;
        oneof f4 {
          string f4a = 4;
        }
      }
      """
    end

    msg1 = RoundtripProto2.Msg.new()
    encoded1 = RoundtripProto2.Msg.encode(msg1)
    assert %{f1: nil, f2: "test", f3: nil, f4: nil} = RoundtripProto2.Msg.decode(encoded1)

    msg2 = RoundtripProto2.Msg.new(f4: {:f4a, "test"})
    encoded2 = RoundtripProto2.Msg.encode(msg2)
    assert %{f4: {:f4a, "test"}} = RoundtripProto2.Msg.decode(encoded2)
  end

  test "can roundtrip encoding/decoding optional values in proto3" do
    defmodule RoundtripProto3 do
      use Protobuf, """
      syntax = "proto3";

      message Msg {
        string f1 = 1;
        uint32 f2 = 2;
        bool f3 = 3;
        oneof f4 {
          string f4a = 4;
        }
      }
      """
    end

    msg1 = RoundtripProto3.Msg.new()
    encoded1 = RoundtripProto3.Msg.encode(msg1)
    assert %{f1: "", f2: 0, f3: false, f4: nil} = RoundtripProto3.Msg.decode(encoded1)

    msg2 = RoundtripProto3.Msg.new(f4: {:f4a, "test"})
    encoded2 = RoundtripProto3.Msg.encode(msg2)
    assert %{f4: {:f4a, "test"}} = RoundtripProto3.Msg.decode(encoded2)
  end

  test "can encode when protocol is extended with new optional field" do
    defmodule BasicProto do
      use Protobuf, """
      message Msg {
        required uint32 f1 = 1;
      }
      """
    end
    old = BasicProto.Msg.new(f1: 1)

    defmodule BasicProto do
      use Protobuf, """
      message Msg {
        required uint32 f1 = 1;
        optional uint32 f2 = 2;
      }
      """
    end
    encoded = BasicProto.Msg.encode(old)
    decoded = BasicProto.Msg.decode(encoded)

    assert 1 = decoded.f1
    refute decoded.f2
  end

  test "can encode when inject is used" do
    defmodule Msg do
      use Protobuf, ["""
      message Msg {
        required uint32 f1 = 1;
      }
      """, inject: true]
    end
    msg = Msg.new(f1: 1)
    encoded = Msg.encode(msg)
    decoded = Msg.decode(encoded)

    assert 1 = decoded.f1
  end

  test "can encode when inject and only are used" do
    defmodule Msg do
      use Protobuf, ["""
      message Msg {
        required uint32 f1 = 1;
      }
      """, inject: true, only: [:Msg]]
    end
    msg = Msg.new(f1: 1)
    encoded = Msg.encode(msg)
    decoded = Msg.decode(encoded)

    assert 1 = decoded.f1
  end

  test "can encode when inject is used and module is nested" do
    defmodule Nested.Msg do
      use Protobuf, ["""
      message Msg {
        required uint32 f1 = 1;
      }
      """, inject: true]
    end
    msg = Nested.Msg.new(f1: 1)
    encoded = Nested.Msg.encode(msg)
    decoded = Nested.Msg.decode(encoded)

    assert 1 = decoded.f1
  end

  test "can encode when inject is used and definition loaded from a file" do
    defmodule Basic do
      use Protobuf, from: Path.expand("./proto/simple.proto", __DIR__), inject: true
    end
    basic = Basic.new(f1: 1)
    encoded = Basic.encode(basic)
    decoded = Basic.decode(encoded)
    assert 1 == decoded.f1
  end

  test "can decode when protocol is extended with new optional field" do
    defmodule BasicProto do
      use Protobuf, """
      message Msg {
        required uint32 f1 = 1;
      }
      """
    end
    old = BasicProto.Msg.new(f1: 1)
    encoded = BasicProto.Msg.encode(old)

    defmodule BasicProto do
      use Protobuf, """
      message Msg {
        required uint32 f1 = 1;
        optional uint32 f2 = 2;
      }
      """
    end
    decoded = BasicProto.Msg.decode(encoded)

    assert 1 = decoded.f1
    refute decoded.f2
  end

  test "define records in namespace" do
    defmodule NamespacedRecordsProto do
      use Protobuf, """
         message Msg1 {
           required uint32 f1 = 1;
         }

         message Msg2 {
           required string f1 = 1;
         }
        """
    end
    msg1 = NamespacedRecordsProto.Msg1
    msg2 = NamespacedRecordsProto.Msg2

    assert %{:__struct__ => ^msg1, :f1 => 1} = NamespacedRecordsProto.Msg1.new(f1: 1)
    assert %{:__struct__ => ^msg2, :f1 => "foo"} = NamespacedRecordsProto.Msg2.new(f1: "foo")
  end

  test "define records in namespace with injection" do
    contents = quote do
      use Protobuf, ["
       message InjectionTest {
           required uint32 f1 = 1;
       }
      ", inject: true]
    end

    {:module, mod, _, _} = Module.create(InjectionTest, contents, Macro.Env.location(__ENV__))

    assert %{:__struct__ => ^mod, :f1 => 1} = mod.new(f1: 1)
  end

  test "do not set default value for optional" do
    defmodule DefaultValueForOptionalsProto do
      use Protobuf, "message Msg { optional uint32 f1 = 1; }"
    end
    msg = DefaultValueForOptionalsProto.Msg.new()
    assert nil == msg.f1
  end

  test "set default value to [] for repeated" do
    defmodule DefaultValueForListsProto do
      use Protobuf, "message Msg { repeated uint32 f1 = 1; }"
    end
    msg = DefaultValueForListsProto.Msg.new()
    assert [] == msg.f1
  end

  test "set default value if specified explicitly" do
    defmodule DefaultValueExplicitProto do
      use Protobuf, "message Msg { optional uint32 f1 = 1 [default = 42]; }"
    end
    msg = DefaultValueExplicitProto.Msg.new()
    assert 42 == msg.f1
  end

  test "does not set default value if there is a type mismatch" do
    assert_raise Protobuf.Parser.ParserError, fn ->
      defmodule InvalidValueDefaultValueExplicitProto do
        use Protobuf, "message Msg { optional uint32 f1 = 1 [default = -1]; }"
      end
    end
  end

  test "define a record in subnamespace" do
    defmodule SubnamespacedRecordProto do
      use Protobuf, """
        message Msg {
          message SubMsg {
            required uint32 f1 = 1;
          }

          required SubMsg f1 = 1;
        }
        """
    end

    msg = SubnamespacedRecordProto.Msg.SubMsg.new(f1: 1)
    module = SubnamespacedRecordProto.Msg.SubMsg
    assert %{__struct__: ^module} = msg

    msg = SubnamespacedRecordProto.Msg.new(f1: msg)
    assert %{__struct__: ^module} = msg.f1
  end

  test "define enum information module" do
    defmodule EnumInfoModProto do
      use Protobuf, """
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
        """
    end

    assert {:file, :in_memory} == :code.is_loaded(EnumInfoModProto.Version)
    assert {:file, :in_memory} == :code.is_loaded(EnumInfoModProto.Msg.MsgType)

    assert 1 == EnumInfoModProto.Version.value(:V0_1)
    assert 1 == EnumInfoModProto.Msg.MsgType.value(:START)

    assert :V0_2  == EnumInfoModProto.Version.atom(2)
    assert :STOP == EnumInfoModProto.Msg.MsgType.atom(2)

    assert nil == EnumInfoModProto.Version.atom(-1)
    assert nil == EnumInfoModProto.Msg.MsgType.value(:OTHER)

    assert [:V0_1, :V0_2] == EnumInfoModProto.Version.atoms
    assert [:START, :STOP] == EnumInfoModProto.Msg.MsgType.atoms

    assert [1, 2] == EnumInfoModProto.Version.values
    assert [1, 2] == EnumInfoModProto.Msg.MsgType.values
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
    defmodule ProtoDefsProto do
      use Protobuf, "message Msg { optional uint32 f1 = 1; }"
    end
    defs = [{{:msg, ProtoDefsProto.Msg}, [%Protobuf.Field{name: :f1, fnum: 1, rnum: 2, type: :uint32, occurrence: :optional, opts: []}]}]
    assert defs == ProtoDefsProto.defs
    assert defs == ProtoDefsProto.Msg.defs
  end

  test "defined a method defs to get field info" do
    defmodule FieldDefsProto do
      use Protobuf, "message Msg { optional uint32 f1 = 1; }"
    end
    deff = %Protobuf.Field{name: :f1, fnum: 1, rnum: 2, type: :uint32, occurrence: :optional, opts: []}
    assert deff == FieldDefsProto.Msg.defs(:field, 1)
    assert deff == FieldDefsProto.Msg.defs(:field, :f1)
  end

  test "defined method decode" do
    defmodule DecodeMethodProto do
      use Protobuf, "message Msg { optional uint32 f1 = 1; }"
    end
    module = DecodeMethodProto.Msg
    assert %{:__struct__ => ^module} = DecodeMethodProto.Msg.decode(<<>>)
  end

  test "extensions skip" do
    defmodule SkipExtensions do
      use Protobuf, """
        message Msg {
          required uint32 f1 = 1;
          extensions 100 to 200;
        }
        """
    end
    module = SkipExtensions.Msg
    assert %{:__struct__ => ^module} = SkipExtensions.Msg.new
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
    defmodule UnconventionalMessagesProto do
      use Protobuf, """
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
        """
    end

    assert 0 == UnconventionalMessagesProto.MsgPackage.MsgResponseType.value(:NACK)
    assert 1 == UnconventionalMessagesProto.MsgPackage.MsgResponseType.value(:ACK)

    assert :NACK == UnconventionalMessagesProto.MsgPackage.MsgResponseType.atom(0)
    assert :ACK == UnconventionalMessagesProto.MsgPackage.MsgResponseType.atom(1)

    msg_header = UnconventionalMessagesProto.MsgPackage.MsgHeader

    assert %{:__struct__    => ^msg_header,
             :response_type => :ACK,
             :message_id    => 25 } = UnconventionalMessagesProto.MsgPackage.MsgHeader.new(response_type: :ACK, message_id: 25)

    msg_package = UnconventionalMessagesProto.MsgPackage
    nack_msg_header = UnconventionalMessagesProto.MsgPackage.MsgHeader.new(message_id: 1, response_type: :NACK)
    #nack_msg_package = UnconventionalMessagesProto.MsgPackage.new(header: nack_msg_header)

    assert %{:__struct__ => ^msg_package, :header => ^nack_msg_header} = UnconventionalMessagesProto.MsgPackage.new(header: nack_msg_header)
  end
end
