# Old Behavior

In previous versions of `exprotobuf` files that had `import "some_other.proto";` statements were automatically handled.
This behavior has been replaced by the ability to load in a list of protobuf files when calling `use Protobuf`.

## An Example

Imagine we had two protobuf files.

`basic.proto`

```protobuf
import "colors.proto";

message Basic {
  required uint32 id = 1;
  optional Color color = 2;
}
```

`colors.proto`

```protobuf
enum Color {
  WHITE = 0;
  BLACK = 1;
  GRAY = 2;
  RED = 3;
}
```

What we would like to do with these definitions is load them into elixir and do something like:

```elixir
Test.Basic.new(id: 123, color: :RED) |> Test.Basic.encode
# => <<8, 123, 16, 3>>
Test.Basic.decode(<<8, 123, 16, 3>>)
# => %Test.Basic{color: :RED, id: 123}
```

## The Old Behavior

```elixir
defmodule Test do
  use Protobuf, from: "./test/basic.proto"
end
```

`exprotobuf` would look for the `import "colors.proto";` statement, then try to find that
file, parse it and copy all of its definitions into the same namespace as the Basic message.
This required very little developer effort, but copying definitions had a few drawbacks.
For example, if there were several different files that all used `colors.proto` they would
each have a copy of that definition so there would be multiple elixir modules that all referenced the same enum.

## The New Behavior

```elixir
defmodule Test do
  use Protobuf, from: ["./test/basic.proto","./test/colors.proto"]
end
```

You can now pass a list of proto files to `exprotobuf` and it will parse all of them and resolve all of their names at the same time.
This is a little more work for the developer, but it closely mirrors the way proto files are used in other implementations of protobuf for java and python.
If there were multiple files that all used the `Color` enum, they would all share the same definition and there will be just a single elixir module that represents that enum.
