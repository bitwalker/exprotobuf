defmodule Protobuf.DefineMessage do
  @moduledoc false

  alias Protobuf.Decoder
  alias Protobuf.Encoder
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Delimited

  def def_message(name, fields, [inject: inject, doc: doc, syntax: syntax]) when is_list(fields) do
    struct_fields = record_fields(fields)
    # Inject everything in 'using' module
    if inject do
      quote location: :keep do
        @root __MODULE__
        @record unquote(struct_fields)
        defstruct @record
        fields = unquote(struct_fields)

        def record, do: @record
        def syntax, do: unquote(syntax)

        unquote(define_typespec(fields))

        unquote(encode_decode(name))
        unquote(fields_methods(fields))
        unquote(oneof_fields_methods(fields))
        unquote(meta_information())
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
          @moduledoc false
          unquote(Protobuf.Config.doc_quote(doc))
          @root root
          @record unquote(struct_fields)
          defstruct @record

          def record, do: @record
          def syntax, do: unquote(syntax)

          unquote(define_typespec(fields))

          unquote(encode_decode(name))
          unquote(fields_methods(fields))
          unquote(oneof_fields_methods(fields))
          unquote(meta_information())

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
      def new(), do: new([])
      def new(values) do
        struct(unquote(name), values)
      end
    end
  end

  defp define_typespec(field_list) do

    field_specs_ast =
      field_list
      |> Enum.map(fn

        %Protobuf.Field{
          name: field_name,
          occurrence: :required,
          type: type,
        } ->
          {field_name, define_field_typespec(type)}

        %Protobuf.Field{
          name: field_name,
          occurrence: :optional,
          type: type,
        } ->
          {field_name, quote do unquote(define_field_typespec(type)) | nil end}

        %Protobuf.Field{
          name: field_name,
          occurrence: :repeated,
          type: type,
        } ->
          {field_name, quote do [unquote(define_field_typespec(type))] end}

        %Protobuf.OneOfField{
          name: field_name,
          fields: _,
        } ->
          #
          # TODO : implement!!!
          #
          {field_name, quote do any() end}
      end)

    typespec_ast =
      {:@, [context: Elixir, import: Kernel],
       [
         {:type, [context: Elixir],
          [
            {:::, [],
             [
               {:t, [], Elixir},
               {:%, [],
                [
                  {:__MODULE__, [], Elixir},
                  {:%{}, [], field_specs_ast}
                ]}
             ]}
          ]}
       ]}

    # typespec_ast
    # |> Macro.to_string
    # |> IO.puts
    #
    # IO.puts("")

    typespec_ast
  end

  defp define_field_typespec(type) do
    case type do
      {:msg, field_module} ->
        quote do
          unquote(field_module).t()
        end
      {:enum, field_module} ->
        quote do
          unquote(field_module).t()
        end
      {:map, key_type, value_type} ->
        key_type_ast = define_field_typespec(key_type)
        value_type_ast = define_field_typespec(value_type)
        quote do
          [{unquote(key_type_ast), unquote(value_type_ast)}]
        end
      _ ->
        define_scalar_typespec(type)
    end
  end

  defp define_scalar_typespec(type) do
    case type do
      :double ->  quote do float() end
      :float -> quote do float() end
      :int32 -> quote do integer() end
      :int64 -> quote do integer() end
      :uint32 -> quote do non_neg_integer() end
      :uint64 -> quote do non_neg_integer() end
      :sint32 -> quote do integer() end
      :sint64 -> quote do integer() end
      :fixed32 -> quote do non_neg_integer() end
      :fixed64 -> quote do non_neg_integer() end
      :sfixed32 -> quote do integer() end
      :sfixed64 -> quote do integer() end
      :bool -> quote do boolean() end
      :string -> quote do String.t() end
      :bytes -> quote do binary() end
    end
  end

  defp encode_decode(_name) do
    quote do
      def decode(data),         do: Decoder.decode(data, __MODULE__)
      def encode(%{} = record), do: Encoder.encode(record, defs())
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
