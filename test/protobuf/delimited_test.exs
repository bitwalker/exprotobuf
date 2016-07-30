defmodule Extprotobuf.Delimited.Test do
  use Protobuf.Case

  defmodule Wrapper do
    use Protobuf, """
    message User {
      required string name = 1;
      optional int32 id = 2;
    }
    """
  end

  @encoded_out <<0, 0, 0, 9, 10, 5, 77, 117, 106, 106, 117, 16, 1>>
  @encoded_out_multiple <<0, 0, 0, 9, 10, 5, 77, 117, 106, 106, 117, 16, 1, 0, 0, 0, 9, 10, 5, 77, 117, 106, 106, 117, 16, 1, 0, 0, 0, 9, 10, 5, 77, 117, 106, 106, 117, 16, 1>>

  test "encode creates a valid message for 1 message" do
    user = %Wrapper.User{name: "Mujju", id: 1}
    encoded_bytes = Protobuf.Delimited.encode([user])

    encoded_user = Wrapper.User.encode(user)
    size = <<byte_size(encoded_user)::size(32)>>

    assert encoded_bytes == size <> encoded_user
    assert encoded_bytes == @encoded_out
  end

  test "encode creates a valid message for multi message" do
    user = %Wrapper.User{name: "Mujju", id: 1}
    encoded_bytes = Protobuf.Delimited.encode([user, user, user])

    encoded_user = Wrapper.User.encode(user)
    size = <<byte_size(encoded_user)::size(32)>>

    assert encoded_bytes == String.duplicate(size <> encoded_user, 3)
  end

  test "decode creates a valid struct for 1 message" do
    assert Protobuf.Delimited.decode(@encoded_out, Wrapper.User) == [%Wrapper.User{name: "Mujju", id: 1}]
  end

  test "decode creates a valid struct for 3 message" do
    users = Protobuf.Delimited.decode(@encoded_out_multiple, Wrapper.User)

    assert users == Enum.map(1..3, fn(_)-> %Wrapper.User{name: "Mujju", id: 1} end)
  end

  test "decode_delimited works" do
    assert Wrapper.User.decode_delimited(@encoded_out) == [%Wrapper.User{name: "Mujju", id: 1}]
  end

  test "encode_delimited works" do
    assert Wrapper.User.encode_delimited([%Wrapper.User{name: "Mujju", id: 1}]) ==  @encoded_out
  end
end
