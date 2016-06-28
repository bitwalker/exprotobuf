defmodule Protobuf.Map.Test do
  use Protobuf.Case

  defmodule Msgs do
    use Protobuf, from: Path.expand("../proto/map.proto", __DIR__)
  end

  @binary <<10, 16, 10, 4, 110, 97, 109, 101, 18, 8, 10, 6, 101, 108, 105, 120, 105, 114>>

  test "can encode map" do
    entity = %Msgs.Entity{
      properties: [
        {"name", %Msgs.Value{value: "elixir"}}
      ]
    }
    binary = entity |> Msgs.Entity.encode
    assert binary == @binary
  end

  test "can decode map" do
    entity = @binary |> Msgs.Entity.decode
    assert %Msgs.Entity{
      properties: [
        {"name", %Msgs.Value{value: "elixir"}}
      ]
    } = entity
  end
end

