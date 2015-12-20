defmodule Protobuf.Chilicat.Test do
  use Protobuf.Case

  defmodule Msgs do
    use Protobuf, from: Path.expand("../proto/chilicat.proto", __DIR__)
  end

  test "can encode" do
    value = Msgs.SGVariant.new(type: :VT_STRING, stringValue: "hello")
    pair = Msgs.SGVariantPair.new(key: :my_key, value: value)
    map = Msgs.SGVariantMap.new(entrySet: [ pair  ])
    
    header = Msgs.SGPacket.SGHeader.new(version: "myVersion",  options: map)

    # encoding fails if map nested in header.
    header
    |> Msgs.SGPacket.SGHeader.encode
    |> Msgs.SGPacket.SGHeader.decode
    
  end
end
