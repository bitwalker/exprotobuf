defmodule Protobuf.Wrappers.Test do
  use Protobuf.Case

  defmodule Proto do
    use Protobuf,
      use_package_names: true,
      from: Path.expand("../proto/wrappers.proto", __DIR__)
  end

  alias Proto.Wrappers.Msg

  setup do
    %{
      msg: %Msg{
        double_scalar:  0.0,
        float_scalar:   0.0,
        int64_scalar:   0,
        uint64_scalar:  0,
        int32_scalar:   0,
        uint32_scalar:  0,
        bool_scalar:    false,
        string_scalar:  "",
        bytes_scalar:   "",
        os_scalar:      :LINUX,

        double_value:   nil,
        float_value:    nil,
        int64_value:    nil,
        uint64_value:   nil,
        int32_value:    nil,
        uint32_value:   nil,
        bool_value:     nil,
        string_value:   nil,
        bytes_value:    nil,
        os_value:       nil,

        oneof_payload: nil
      }
    }
  end

  test "double", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | double_scalar: 1.11, double_value: 1.11}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "float", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | float_scalar: 1.0, float_value: 1.0}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "int64", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | int64_scalar: -10, int64_value: -10}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "uint64", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | uint64_scalar: 10, uint64_value: 10}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "int32", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | int32_scalar: -10, int32_value: -10}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "uint32", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | uint32_scalar: 10, uint32_value: 10}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "bool", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | bool_scalar: true, bool_value: true}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "string", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | string_scalar: "hello", string_value: "hello"}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "bytes", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | bytes_scalar: <<224, 224, 224>>, bytes_value: <<224, 224, 224>>}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "os", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | os_scalar: :LINUX, os_value: :LINUX}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "uint64_oneof_scalar", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | oneof_payload: {:uint64_oneof_scalar, 10}}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "string_oneof_scalar", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | oneof_payload: {:string_oneof_scalar, "hello"}}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "os_oneof_scalar", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | oneof_payload: {:os_oneof_scalar, :MAC}}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "uint64_oneof_value", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | oneof_payload: {:uint64_oneof_value, 10}}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "string_oneof_value", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | oneof_payload: {:string_oneof_value, "hello"}}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

  test "os_oneof_value", %{msg: msg = %Msg{}} do
    expected = %Msg{msg | oneof_payload: {:os_oneof_value, :MAC}}
    assert expected == expected |> Msg.encode |> Msg.decode
  end

end
