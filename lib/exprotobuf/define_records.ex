defmodule Protobuf.DefineRecords do
  @moduledoc false

  import Protobuf.DefineMessage, only: [def_message: 2]
  import Protobuf.DefineEnum,    only: [def_enum: 2]

  def def_records(msgs) do
    quote do
      Module.register_attribute __MODULE__, :use_in, accumulate: true
      import unquote(__MODULE__), only: [use_in: 2]

      @msgs unquote(Macro.escape msgs)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      contents = unquote(__MODULE__).generate(@msgs)
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
  def generate(msgs, _opts \\ []) do
    quotes = for {{item_type, item_name}, fields} <- msgs do
      case item_type do
        :msg  -> def_message(item_name, fields)
        :enum -> def_enum(item_name, fields)
        # ignores other
        _ -> []
      end
    end

    # Global defs helper
    quotes ++ [quote do
      def defs do
        unquote(Macro.escape(msgs, unquote: true))
      end
    end]
  end
end
