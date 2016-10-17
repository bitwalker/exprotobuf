defmodule Protobuf.DefineMessage do
  @moduledoc false

  alias Protobuf.Decoder
  alias Protobuf.Encoder
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Delimited

  def def_message(name, fields, [inject: inject, doc: doc]) when is_list(fields) do
    struct_fields = record_fields(fields)
    # Inject everything in 'using' module
    if inject do
      quote location: :keep do
        @root __MODULE__
        @record unquote(struct_fields)
        defstruct @record
        fields = unquote(struct_fields)

        def record, do: @record

        unquote(encode_decode(name))
        unquote(fields_methods(fields))
        unquote(oneof_fields_methods(fields))
        unquote(meta_information)
        unquote(constructors(name))

        defimpl Protobuf.Serializable do
          def serialize(object), do: unquote(name).encode(object)
        end
      end
    # Or create a nested module, with use_in functionality
    else
      quote location: :keep do
        root   = __MODULE__
        fields = unquote(struct_fields)
        use_in = @use_in[unquote(name)]

        defmodule unquote(name) do
          unquote(Protobuf.Config.doc_quote(doc))
          @root root
          @record unquote(struct_fields)
          defstruct @record

          def record, do: @record

          unquote(encode_decode(name))
          unquote(fields_methods(fields))
          unquote(oneof_fields_methods(fields))
          unquote(meta_information)

          unquote(constructors(name))

          if use_in != nil do
            Module.eval_quoted(__MODULE__, use_in, [], __ENV__)
          end

          defimpl Protobuf.Serializable do
            def serialize(object), do: unquote(name).encode(object)
          end
        end
      end
    end
  end

  defp constructors(name) do
    quote location: :keep do
      def new(), do: struct(unquote(name))
      def new(values) when is_list(values) do
        Enum.reduce(values, new, fn
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
      def decode_delimited(bytes),    do: Delimited.decode(bytes, __MODULE__)
      def encode_delimited(messages), do: Delimited.encode(messages)
    end
  end

  defp fields_methods(fields) do
    for %Field{name: name, fnum: fnum} = field <- fields do
      quote location: :keep do
        def defs(:field, unquote(fnum)), do: unquote(Macro.escape(field))
        def defs(:field, unquote(name)), do: defs(:field, unquote(fnum))
      end
    end
  end

  defp oneof_fields_methods(fields) do
    for %OneOfField{name: name, rnum: rnum} = field <- fields do
      quote location: :keep do
        def defs(:field, unquote(rnum)), do: unquote(Macro.escape(field))
        def defs(:field, unquote(name)), do: defs(:field, unquote(rnum))
      end
    end
  end

  defp meta_information do
    quote do
      def defs,                   do: @root.defs
      def defs(:field, _),        do: nil
      def defs(:field, field, _), do: defs(:field, field)
      defoverridable [defs: 0]
    end
  end

  defp record_fields(fields) do
    fields
    |> Enum.map(fn(field) ->
      case field do
        %Field{name: name, occurrence: :repeated} ->
          {name, []}
        %Field{name: name, opts: [default: default]} ->
          {name, default}
        %Field{name: name} ->
          {name, nil}
        %OneOfField{name: name} ->
          {name, nil}
        _ ->
          nil
      end
    end)
    |> Enum.reject(fn(field) -> is_nil(field) end)
  end

end
