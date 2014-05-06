defmodule Protobuf.Test.GpbCompileHelperTest do
  use Protobuf.Case

  test "auxiliar compile test function" do
    Gpb.compile_tmp_proto ~S[
        message Msg1 {
          required uint32 field1 = 1;
        }

        message Msg2 {
          optional uint32 field1 = 1;
        }

        message Msg3 {
          enum Type {
            TYPE1 = 1;
            TYPE2 = 2;
            TYPE3 = 3;
          }

          message Msg4 {
            required uint32 field1 = 1;
          }

          required Type field1 = 1;
          optional Msg2 field2 = 2;
          optional Msg4 field3 = 3;
        }
      ], fn mod ->

      msgs = [
        [{:Msg1, 10}, <<8, 10>>],
        [{:Msg2, :undefined}, <<>>],
        [{:Msg3, :TYPE1, :undefined, :undefined}, <<8, 1>>],
        [{:Msg3, :TYPE2, {:Msg2, 10}, :undefined}, <<8, 2, 18, 2, 8, 10>>],
        [{:Msg3, :TYPE3, {:Msg2, 10}, {:'Msg3.Msg4', 1}}, <<8, 3, 18, 2, 8, 10, 26, 2, 8, 1>>],
      ]

      Enum.each(msgs, fn [msg, encoded] ->
        msg_name = elem(msg, 0)
        assert encoded == mod.encode_msg(msg)
        assert msg == mod.decode_msg(mod.encode_msg(msg), msg_name)
      end)
    end
  end
end
