defmodule Protobuf.Builder do
  @moduledoc false

  alias Protobuf.Config

  import Protobuf.DefineEnum,    only: [def_enum: 3]
  import Protobuf.DefineMessage, only: [def_message: 3]

  def define(msgs, %Config{inject: inject} = config) do
    # When injecting, use_in is not available, so we don't need to use @before_compile
    if inject do
      quote location: :keep do
        Module.register_attribute __MODULE__, :use_in, accumulate: true
        import unquote(__MODULE__), only: [use_in: 2]

        unless is_nil(unquote(config.from_file)) do
          case unquote(config.from_file) do
            file when is_binary(file) ->
              @external_resource file

            files when is_list(files) ->
              for file <- files do
                @external_resource file
              end
          end
        end

        @config         unquote(Macro.escape Map.to_list(%{config | :schema => nil}))
        @msgs           unquote(Macro.escape msgs)
        contents = unquote(__MODULE__).generate(@msgs, @config)
        Module.eval_quoted __MODULE__, contents, [], __ENV__
      end
    else
      quote do
        Module.register_attribute __MODULE__, :use_in, accumulate: true
        import unquote(__MODULE__), only: [use_in: 2]


        unless is_nil(unquote(config.from_file)) do
          case unquote(config.from_file) do
            file when is_binary(file) ->
              @external_resource file

            files when is_list(files) ->
              for file <- files do
                @external_resource file
              end
          end
        end

        @config         unquote(Macro.escape Map.to_list(%{config | :schema => nil}))
        @msgs           unquote(Macro.escape msgs)
        @before_compile unquote(__MODULE__)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      contents = unquote(__MODULE__).generate(@msgs, @config)
      Module.eval_quoted __MODULE__, contents, [], __ENV__
    end
  end

  # Cache use instructions
  defmacro use_in(module, use_module) do
    module = :"#{__CALLER__.module}.#{module}"
    use_module = quote do: use(unquote(use_module))
    quote location: :keep do
      @use_in {unquote(module), unquote(Macro.escape(use_module)) }
    end
  end

  # Generate code of records (message and enum)
  def generate(msgs, config) do
    only   = Keyword.get(config, :only, [])
    inject = Keyword.get(config, :inject, false)
    doc    = Keyword.get(config, :doc, true)
    ns     = Keyword.get(config, :namespace)

    quotes = for {{item_type, item_name}, fields} <- msgs, item_type in [:msg, :proto3_msg, :enum], into: [] do
      if only != [] do
        is_child? = Enum.any?(only, fn o -> o != item_name and is_child_type?(item_name, o) end)
        last_mod = last_module(item_name)
        if last_mod in only or is_child? do
          case item_type do
            :msg when is_child?         -> def_message(item_name |> fix_ns(ns), fields, inject: false, doc: doc, syntax: :proto2)
            :msg                        -> def_message(ns, fields, inject: inject, doc: doc, syntax: :proto2)
            :proto3_msg when is_child?  -> def_message(item_name |> fix_ns(ns), fields, inject: false, doc: doc, syntax: :proto3)
            :proto3_msg                 -> def_message(ns, fields, inject: inject, doc: doc, syntax: :proto3)
            :enum when is_child?        -> def_enum(item_name |> fix_ns(ns), fields, inject: false, doc: doc)
            :enum                       -> def_enum(ns, fields, inject: inject, doc: doc)
            _     -> []
          end
        end
      else
        case item_type do
          :msg         -> def_message(item_name, fields, inject: false, doc: doc, syntax: :proto2)
          :proto3_msg  -> def_message(item_name, fields, inject: false, doc: doc, syntax: :proto3)
          :enum        -> def_enum(item_name, fields, inject: false, doc: doc)
          _     -> []
        end
      end
    end

    unified_msgs = msgs |> Enum.map(&unify_msg_types/1)

    # Global defs helper
    quotes ++ [quote do
      def defs do
        unquote(Macro.escape(unified_msgs, unquote: true))
      end
    end]
  end

  defp unify_msg_types({{:proto3_msg, name}, fields}), do: {{:msg, name}, fields}
  defp unify_msg_types(other),                         do: other

  defp is_child_type?(child, type) do
    [parent|_] = child |> Atom.to_string |> String.split(".", parts: :infinity)
    Atom.to_string(type) == parent
  end

  defp fix_ns(name, ns) do
    name_parts = name |> Atom.to_string |> String.split(".", parts: :infinity)
    ns_parts   = ns   |> Atom.to_string |> String.split(".", parts: :infinity)
    module     = name_parts -- ns_parts |> Enum.join |> String.to_atom
    :"#{ns}.#{module}"
  end

  defp last_module(namespace) do
    namespace |> Module.split() |> List.last() |> String.to_atom()
  end
end
