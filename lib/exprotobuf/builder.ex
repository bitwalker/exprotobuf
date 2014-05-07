defmodule Protobuf.Builder do
  @moduledoc false

  alias Protobuf.Config

  import Protobuf.DefineEnum,    only: [def_enum: 3]
  import Protobuf.DefineMessage, only: [def_message: 3]

  def define(msgs, %Config{} = config) do
    quote do
      Module.register_attribute __MODULE__, :use_in, accumulate: true
      import unquote(__MODULE__), only: [use_in: 2]

      @config         unquote(Macro.escape Map.to_list(%{config | :schema => nil}))
      @msgs           unquote(Macro.escape msgs)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      contents = unquote(__MODULE__).generate(@msgs, @config)
      Module.eval_quoted __MODULE__, contents, [], __ENV__
    end
  end

  # Cache use instructions
  defmacro use_in(module, use_module) do
    module = :"#{__CALLER__.module}.#{module}"
    use_module = quote do: use(unquote(use_module))
    quote do
      @use_in {unquote(module), unquote(Macro.escape(use_module)) }
    end
  end

  # Generate code of records (message and enum)
  def generate(msgs, config) do
    only   = Keyword.get(config, :only, [])
    inject = Keyword.get(config, :inject, false)
    ns     = Keyword.get(config, :namespace)

    quotes = for {{item_type, item_name}, fields} <- msgs, item_type in [:msg, :enum], into: [] do
      if only != [] do
        is_child? = Enum.any?(only, fn o -> o != item_name and is_child_type?(item_name, o) end)
        if item_name in only or is_child? do
          case item_type do
            :msg when is_child?  -> def_message(item_name |> fix_ns(ns), fields, inject: false)
            :msg                 -> def_message(ns, fields, inject: inject)
            :enum when is_child? -> def_enum(item_name |> fix_ns(ns), fields, inject: false)
            :enum                -> def_enum(ns, fields, inject: inject)
            _     -> []
          end
        end
      else
        case item_type do
          :msg  -> def_message(item_name, fields, inject: false)
          :enum -> def_enum(item_name, fields, inject: false)
          _     -> []
        end
      end
    end

    # Global defs helper
    if inject do
      quotes
    else
      quotes ++ [quote do
        def defs do
          unquote(Macro.escape(msgs, unquote: true))
        end
      end]
    end
  end

  defp is_child_type?(child, type) do
    [parent|_] = child |> atom_to_binary |> String.split(".", parts: :infinity)
    atom_to_binary(type) == parent
  end

  defp fix_ns(name, ns) do
    name_parts = name |> atom_to_binary |> String.split(".", parts: :infinity)
    ns_parts   = ns   |> atom_to_binary |> String.split(".", parts: :infinity)
    module     = name_parts -- ns_parts |> Enum.join |> binary_to_atom
    :"#{ns}.#{module}"
  end
end
