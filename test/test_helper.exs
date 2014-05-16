Code.require_file "./utils/gpb_compile_helper.exs", __DIR__

ExUnit.start

defmodule Protobuf.Case do
  use ExUnit.CaseTemplate

  using _ do
    quote location: :keep do
      import unquote(__MODULE__)
      alias GpbCompileHelper, as: Gpb

      defmacrop def_proto_module(value) do
        {value, []} = Code.eval_quoted(value, [], __CALLER__)
        quote do
          {:module, mod, _, _} = defmodule mod_temp do
            use Protobuf, unquote(value)
          end; mod
        end
      end

      defp mod_temp(n \\ 1) do
        mod_candidate = :"#{__MODULE__}.Test_#{n}"
        case :code.is_loaded(mod_candidate) do
          false -> mod_candidate
          _ -> mod_temp(n + 1)
        end
      end
    end
  end
end
