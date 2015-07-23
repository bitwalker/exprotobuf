# Protocol Buffers for Elixir

exprotobuf works by building module/struct definitions from a [Google Protocol Buffer](https://code.google.com/p/protobuf)
schema. This allows you to work with protocol buffers natively in Elixir, with easy decoding/encoding for transport across the
wire.

[![Build Status](https://travis-ci.org/bitwalker/exprotobuf.svg?branch=master)](https://travis-
ci.org/bitwalker/exprotobuf)
[![Hex.pm Version](http://img.shields.io/hexpm/v/exprotobuf.svg?style=flat)](https://hex.pm/packages/exprotobuf)

## Features

* Load protobuf from file or string
* Respects the namespace of messages
* Allows you to specify which modules should be loaded in the definition of records
* Currently uses [gpb](https://github.com/tomas-abrahamsson/gpb) for protobuf schema parsing

TODO:

* Support importing definitions
* Clean up code/tests

## Getting Started

Add exprotobuf as a dependency to your project:

```elixir
defp deps do
  [{:exprotobuf, "~> 0.10.2"}]
end
```

Then run `mix deps.get` to fetch.

## Usage

Usage of exprotobuf boils down to a single `use` statement within one or
more modules in your project.

Let's start with the most basic of usages:

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

The above code takes the provided protobuf schema as a string, and
generates modules/structs for the types it defines. In this case, there
would be a Msg module, containing a SubMsg and Version module. The
properties defined for those values are keys in the struct belonging to
each. Enums do not generate structs, but a specialized module with two
functions: `atom(x)` and `value(x)`. These will get either the name of
the enum value, or it's associated value.

### Define from a file

```elixir
defmodule Messages do
  use Protobuf, from: Path.expand("../proto/messages.proto", __DIR__)
end
```

This is equivalent to the above, if you assume that `messages.proto`
contains the same schema as in the string of the first example.

### Inject a definition into an existing module

This is useful when you only have a single type, or if you want to pull
the module definition into the current module instead of generating a
new one.

```elixir
defmodule Msg do
  use Protobuf, from: Path.expand("../proto/messages.proto", __DIR__), inject: true

  def update(msg, key, value), do: Map.put(msg, key, value)
end
```

```elixir
iex> %Msg{}
%Msg{v: :V1}
iex> Msg.update(%Msg{}, :v, :V2)
%Msg{v: :V2}
```

As you can see, Msg is no longer created as a nested module, but is
injected right at the top level. I find this approach to be a lot
cleaner than `use_in`, but may not work in all use cases.

### Inject a specific type from a larger subset of types

When you have a large schema, but perhaps only care about a small subset
of those types, you can use `:only`:

```elixir
defmodule Messages do
  use Protobuf, from: Path.expand("../proto/messages.proto", __DIR__),
only: [:TypeA, :TypeB]
end
```

Assuming that the provided .proto file contains multiple type
definitions, the above code would extract only TypeA and TypeB as nested
modules. Keep in mind your dependencies, if you select a child type
which depends on a parent, or another top-level type, exprotobuf may
fail, or your code may fail at runtime.

You may only combine `:only` with `:inject` when `:only` is a single
type, or a list containing a single type. This is due to the restriction
of one struct per module. Theoretically you should be able to pass `:only`
with multiple types, as long all but one of the types is an enum, since
enums are just generated as modules, this does not currently work
though.

### Extend generated modules via `use_in`

If you need to add behavior to one of the generated modules, `use_in`
will help you. The tricky part is that the struct for the module you
`use_in` will not be defined yet, so you can't rely on it in your
functions. You can still work with the structs via the normal Maps API,
but you lose compile-time guarantees. I would recommend favoring
`:inject` over this when possible, as it's a much cleaner solution.

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
