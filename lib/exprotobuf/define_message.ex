defmodule Protobuf.DefineMessage do
  @moduledoc false

  alias Protobuf.Decoder
  alias Protobuf.Encoder

  defrecord :field, Record.Extractor.extract(:field, from: Path.join([Mix.Project.deps_path, "gpb", "include", "gpb.hrl"]))

  def def_message(name, fields, inject: inject) when is_list(fields) do
    struct_fields = record_fields(fields)
    # Inject everything in 'using' module
    if inject do
      quote do
        @root __MODULE__
        fields = unquote(struct_fields)

        defstruct unquote(struct_fields)

        unquote(encode_decode(name))
        unquote(fields_methods(fields))
        unquote(meta_information)
      end
    # Or create a nested module, with use_in functionality
    else
      quote do
        root   = __MODULE__
        fields = unquote(struct_fields)
        use_in = @use_in[unquote(name)]

        defmodule unquote(name) do
          @root root
          defstruct unquote(struct_fields)

          unquote(encode_decode(name))
          unquote(fields_methods(fields))
          unquote(meta_information)

          unquote(constructors(name))

          if use_in != nil do
            Module.eval_quoted(__MODULE__, use_in, [], __ENV__)
          end
        end
      end
    end
  end

  defp constructors(name) do
    quote do
      def new(), do: %unquote(name){}
      def new(values) when is_list(values) do
        Enum.reduce(values, %unquote(name){}, fn
          {key, value}, obj ->
            if Map.has_key?(obj, key) do
              Map.put(obj, key, value)
            else
              obj
            end
        end)
      end
    end
  end

  defp encode_decode(_name) do
    quote do
      def decode(data),         do: Decoder.decode(data, __MODULE__)
      def encode(%{} = record), do: Encoder.encode(record, defs)
    end
  end

  defp fields_methods(fields) do
    for :field[name: name, fnum: fnum] = field <- fields do
      quote do
        def defs(:field, unquote(fnum)), do: unquote(Macro.escape(field))
        def defs(:field, unquote(name)), do: defs(:field, unquote(fnum))
      end
    end
  end

  defp meta_information do
    quote do
      def defs(_ \\ nil),         do: @root.defs
      def defs(:field, _),        do: nil
      def defs(:field, field, _), do: defs(:field, field)
    end
  end

  defp record_fields(fields) do
    for :field[name: name, occurrence: occurrence] <- fields do
      {name, case occurrence do
        :repeated -> []
        _ -> nil
      end}
    end
  end

end
