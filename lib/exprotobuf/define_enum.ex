defmodule Protobuf.DefineEnum do
  @moduledoc false

  @doc """
  Defines a new module which contains two functions, atom(value) and value(atom), for
  getting either the name or value of an enumeration value.
  """
  def def_enum(name, values) do
    contents = for {atom, value} <- values do
      quote do
        def value(unquote(atom)), do: unquote(value)
        def atom(unquote(value)), do: unquote(atom)
      end
    end
    quote do
      defmodule unquote(name) do
        unquote(contents)
        def value(_), do: nil
        def atom(_), do: nil
      end
    end
  end
end
