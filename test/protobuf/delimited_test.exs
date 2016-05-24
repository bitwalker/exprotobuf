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

  test "encode creates a valid message for 1 message" do
    user = %Wrapper.User{name: "Mujju", id: 1}
    encoded_bytes = Protobuf.Delimited.encode([user])

    encoded_user = Wrapper.User.encode(user)
    size = << byte_size(encoded_user) :: size(32) >>

    assert encoded_bytes == size <> encoded_user
    assert encoded_bytes == @encoded_out
  end

  test "encode creates a valid message for multi message" do
    user = %Wrapper.User{name: "Mujju", id: 1}
    encoded_bytes = Protobuf.Delimited.encode([user, user, user])

    encoded_user = Wrapper.User.encode(user)
    size = << byte_size(encoded_user) :: size(32) >>

    assert encoded_bytes == String.duplicate(size <> encoded_user, 3)
  end


end

