defmodule Protobuf.NestedOneof.Test do
  use Protobuf.Case

  defmodule Msgs do
    use Protobuf, from: Path.expand("../proto/nested_one_of.proto", __DIR__)
  end

  test "can encode nested one_of proto" do
    bar = Msgs.Bar.new msg: "msg"
    c = Msgs.Container.new hello: "hello", msg: {:bar, bar}
    enc_c = c |> Msgs.Container.encode

    assert is_binary(enc_c)
  end

  test "can decode nested one_of proto" do
    encoded = <<10, 5, 104, 101, 108, 108, 111, 26, 5, 10, 3, 109, 115, 103>>;
    decoded = encoded |> Msgs.Container.decode

    assert %Msgs.Container{} = decoded
  end

  test "can encode deeply nested one_of proto" do
    sfm = Msgs.SingleFooMetadata.new baz_id: "baz_id"
    fm = Msgs.FooMetadata.new type: {:single_metadata, sfm}
    foo = Msgs.Foo.new foo_id: "foo_id", created_at: 0, metadata: fm
    c = Msgs.Container.new msg: {:foo, foo}
    enc_c = c |> Msgs.Container.encode

    assert is_binary(enc_c)
  end

  test "can decode deeply nested one_of proto" do
    encoded = <<18, 22, 10, 6, 102, 111, 111, 95, 105, 100, 16, 0, 26, 10, 18,
      8, 10, 6, 98, 97, 122, 95, 105, 100>>
    decoded = encoded |> Msgs.Container.decode

    assert %Msgs.Container{} = decoded
  end

end
