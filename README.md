# Protocol Buffers for Elixir

exprotobuf works by building module/struct definitions from a [Google Protocol Buffer](https://code.google.com/p/protobuf)
schema. This allows you to work with protocol buffers natively in Elixir, with easy decoding/encoding for transport across the
wire.

[![wercker status](https://app.wercker.com/status/2637c2f7cae8bdc7dade2e9ca7cb0019/m/ "wercker status")](https://app.wercker.com/project/bykey/2637c2f7cae8bdc7dade2e9ca7cb0019)

## Features

* Load protobuf from file or string
* Respects the namespace of messages
* Allows you to specify which modules should be loaded in the definition of records
* Currently uses [gpb](https://github.com/tomas-abrahamsson/gpb) for protobuf schema parsing

TODO:

* Support importing definitions
* Clean up code/tests

## Examples

### Define from a string

```elixir
defmodule Messages do
  use Protobuf, """
    message Msg {
      message SubMsg {
        required uint32 value = 1;
      }

      enum Version {
        V1 = 1;
        V2 = 2;
      }

      required Version version = 2;
      optional SubMsg sub = 1;
    }
  """
end
```

```elixir
iex> msg = Messages.Msg.new(version: :'V2')
%Messages.Msg{version: :V2, sub: nil}
iex> encoded = Messages.Msg.encode(msg)
<<16, 2>>
iex> Messages.Msg.decode(encoded)
%Messages.Msg{version: :V2, sub: nil}
```

### Define from a file

```elixir
defmodule Messages do
  use Protobuf, from: Path.expand("../proto/messages.proto", __DIR__)
end
```

### Inject a definition into an existing module

```elixir
defmodule Msg do
  use Protobuf, "
    message Msg {
      enum Version {
        V1 = 1;
        V2 = 1;
      }
      required Version v = 1;
    }
  ", inject: true

  def update(msg, key, value), do: Map.put(msg, key, value)
end
```

```elixir
iex> %Msg{}
%Msg{v: :V1}
iex> Msg.update(%Msg{}, :v, :V2)
%Msg{v: :V2}
```

### Inject a specific type from a larger subset of types

By passing `only: :Msg` or `only: [:Msg,...]` where `:Msg` is the name of your desired type, you can create definitions
for a subset of types from a larger schema file. Be aware that when combined with `inject: true`, you can only specify
a single type, due to limitations around multiple structs in a single module.

### Extend generated modules via `use_in`

```elixir
defmodule Messages do
  use Protobuf, "
    message Msg {
      enum Version {
        V1 = 1;
        V2 = 1;
      }
      required Version v = 1;
    }
  "

  defmodule MsgHelpers do
    defmacro __using__(_opts) do
      quote do
        def convert_to_record(msg) do
          msg
          |> Map.to_list
          |> Enum.reduce([], fn {_key, value}, acc -> [value | acc] end)
          |> Enum.reverse
          |> list_to_tuple
        end
      end
    end
  end

  use_in "Msg", MsgHelpers
end
```

```elixir
iex> Messages.Msg.new |> Messages.Msg.convert_to_record
{Messages.Msg, :V1}
```

## Attribution/License

exprotobuf is a fork of the azukiaapp/elixir-protobuf project, both of which are released under Apache 2 License.

Check LICENSE files for more information.
