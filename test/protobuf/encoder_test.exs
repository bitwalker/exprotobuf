defmodule Protobuf.Encoder.Test do
  use Protobuf.Case

  defmodule EncoderProto do
    use Protobuf, """
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

      service HelloService {
        rpc hello (Msg) returns (Msg);
      }
      """
  end

  defmodule ExtensionsProto do
    use Protobuf, """
    message Msg {
      extensions 200 to max;
      optional string name = 1;
    }
    extend Msg {
      optional string pseudonym = 200;
    }
    """
  end

  test "fixing nil values to :undefined" do
    msg = EncoderProto.Msg.new(f1: 150)
    assert <<8, 150, 1>> == Protobuf.Serializable.serialize(msg)
    assert <<10, 3, 8, 150, 1>> == Protobuf.Serializable.serialize(EncoderProto.WithSubMsg.new(f1: msg))
  end

  test "fixing a nil value in repeated submsg" do
    msg = EncoderProto.WithRepeatedSubMsg.new(f1: [EncoderProto.Msg.new(f1: 1)])
    assert <<10, 2, 8, 1>> == Protobuf.Serializable.serialize(msg)
  end

  test "fixing lowercase message and enum references" do
    msg = EncoderProto.ExtraMsg.new(type: :ACK, message: [EncoderProto.Msg.new(f1: 1)])
    assert <<8, 1, 18, 2, 8, 1>> == Protobuf.Serializable.serialize(msg)
  end

  test "encodes enums" do
    msg = EncoderProto.WithEnum.new(version: :'V1')
    assert <<8, 1>> == Protobuf.Serializable.serialize(msg)
  end

  test "it can create an extended message" do
    msg = ExtensionsProto.Msg.new(name: "Ron", pseudonym: "Duke Silver")
    assert msg == %ExtensionsProto.Msg{name: "Ron", pseudonym: "Duke Silver"}
  end

  test "it can encode an extended message" do
    msg = ExtensionsProto.Msg.new(name: "Ron", pseudonym: "Duke Silver")
    assert ExtensionsProto.Msg.encode(msg) == <<10, 3, 82, 111, 110, 194, 12, 11, 68, 117, 107, 101, 32, 83, 105, 108, 118, 101, 114>>
  end

  test "it can decode an extended message" do
    encoded = <<10, 3, 82, 111, 110, 194, 12, 11, 68, 117, 107, 101, 32, 83, 105, 108, 118, 101, 114>>
    assert ExtensionsProto.Msg.decode(encoded) == %ExtensionsProto.Msg{name: "Ron", pseudonym: "Duke Silver"}
  end
end
