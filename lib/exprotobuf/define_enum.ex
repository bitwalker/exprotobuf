defmodule Protobuf.DefineEnum do
  @moduledoc false

  @doc """
  Defines a new module which contains two functions, atom(value) and value(atom), for
  getting either the name or value of an enumeration value.
  """
  def def_enum(name, values, [inject: inject, doc: doc]) do
    enum_atoms = Enum.map values, fn {a, _} -> a end
    enum_values = Enum.map values, fn {_, v} -> v end
    contents = for {atom, value} <- values do
      quote do
        def value(unquote(atom)), do: unquote(value)
        def atom(unquote(value)), do: unquote(atom)
      end
    end
    contents = contents ++ [
      quote do
        def values, do: unquote(enum_values)
        def atoms, do: unquote(enum_atoms)
      end
    ]
    if inject do
      quote do
        unquote(define_typespec(enum_atoms))
        unquote(contents)
        def value(_), do: nil
        def atom(_),  do: nil
      end
    else
      quote do
        defmodule unquote(name) do
          @moduledoc false
          unquote(define_typespec(enum_atoms))
          unquote(Protobuf.Config.doc_quote(doc))
          unquote(contents)
          def value(_), do: nil
          def atom(_), do: nil
        end
      end
    end
  end

  defp define_typespec(enum_atoms) do

    typespec_ast =
      {:@, [context: Elixir, import: Kernel],
       [
         {:type, [context: Elixir],
          [{:::, [], [{:t, [], Elixir}, Protobuf.Utils.define_algebraic_type(enum_atoms)]}]}
       ]}

    # typespec_ast
    # |> Macro.to_string
    # |> IO.puts
    #
    # IO.puts("")

    typespec_ast
  end

end
