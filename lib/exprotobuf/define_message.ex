defmodule Protobuf.DefineMessage do
  @moduledoc false

  alias Protobuf.Decoder
  alias Protobuf.Encoder
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Delimited
  alias Protobuf.Utils

  def def_message(name, fields, inject: inject, doc: doc, syntax: syntax) when is_list(fields) do
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

        unquote(define_typespec(name, fields))

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
        root = __MODULE__
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

          unquote(define_typespec(name, fields))

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

        unquote(define_oneof_modules(name, fields))
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

  defp define_typespec(module, field_list) when is_list(field_list) when is_atom(module) do
    case field_list do
      [%Field{name: :value, type: scalar, occurrence: occurrence}]
      when is_atom(scalar) and is_atom(occurrence) ->
        scalar_wrapper? = Utils.is_standard_scalar_wrapper(module)

        cond do
          scalar_wrapper? and occurrence == :required ->
            quote do
              @type t() :: unquote(define_scalar_typespec(scalar))
            end

          scalar_wrapper? ->
            quote do
              @type t() :: unquote(define_scalar_typespec(scalar)) | nil
            end

          :else ->
            define_trivial_typespec(field_list)
        end

      [%Field{name: :value, type: {:enum, enum_module}, occurrence: occurrence}]
      when is_atom(enum_module) ->
        enum_wrapper? = Utils.is_enum_wrapper(module, enum_module)

        cond do
          enum_wrapper? and occurrence == :required ->
            quote do
              @type t() :: unquote(enum_module).t()
            end

          enum_wrapper? ->
            quote do
              @type t() :: unquote(enum_module).t() | nil
            end

          :else ->
            define_trivial_typespec(field_list)
        end

      _ ->
        define_trivial_typespec(field_list)
    end
  end

  defp define_trivial_typespec([]), do: nil

  defp define_trivial_typespec(fields) when is_list(fields) do
    field_types = define_trivial_typespec_fields(fields, [])
    map_type = {:%{}, [], field_types}
    module_type = {:%, [], {{:__MODULE__, [], Elixir}, map_type}}

    quote generated: true do
      @type t() :: unquote(module_type)
    end
  end

  defp define_trivial_typespec_fields([], acc), do: Enum.reverse(acc)

  defp define_trivial_typespec_fields([field | rest], acc) do
    case field do
      %Protobuf.Field{name: name, occurrence: :required, type: type} ->
        ast = {name, define_field_typespec(type)}
        define_trivial_typespec_fields(rest, [ast | acc])

      %Protobuf.Field{name: name, occurrence: :optional, type: type} ->
        ast =
          {name,
           quote do
             unquote(define_field_typespec(type)) | nil
           end}

        define_trivial_typespec_fields(rest, [ast | acc])

      %Protobuf.Field{name: name, occurrence: :repeated, type: type} ->
        ast =
          {name,
           quote do
             [unquote(define_field_typespec(type))]
           end}

        define_trivial_typespec_fields(rest, [ast | acc])

      %Protobuf.OneOfField{name: name, fields: fields} ->
        ast =
          {name,
           quote do
             unquote(define_algebraic_type(fields))
           end}

        define_trivial_typespec_fields(rest, [ast | acc])
    end
  end

  defp define_algebraic_type(fields) do
    ast =
      for %Protobuf.Field{name: name, type: type} <- fields do
        {name, define_field_typespec(type)}
      end

    Protobuf.Utils.define_algebraic_type([nil | ast])
  end

  defp define_oneof_modules(namespace, fields) when is_list(fields) do
    ast =
      for %Protobuf.OneOfField{} = field <- fields do
        define_oneof_instance_module(namespace, field)
      end

    quote do
      (unquote_splicing(ast))
    end
  end

  defp define_oneof_instance_module(namespace, %Protobuf.OneOfField{name: field, fields: fields}) do
    module_subname =
      field
      |> Atom.to_string()
      |> Macro.camelize()
      |> String.to_atom()

    fields = Enum.map(fields, &define_oneof_instance_macro/1)

    quote do
      defmodule unquote(Module.concat([namespace, :OneOf, module_subname])) do
        (unquote_splicing(fields))
      end
    end
  end

  defp define_oneof_instance_macro(%Protobuf.Field{name: name}) do
    quote do
      defmacro unquote(name)(ast) do
        inner_name = unquote(name)

        quote do
          {unquote(inner_name), unquote(ast)}
        end
      end
    end
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
      :double ->
        quote do
          float()
        end

      :float ->
        quote do
          float()
        end

      :int32 ->
        quote do
          integer()
        end

      :int64 ->
        quote do
          integer()
        end

      :uint32 ->
        quote do
          non_neg_integer()
        end

      :uint64 ->
        quote do
          non_neg_integer()
        end

      :sint32 ->
        quote do
          integer()
        end

      :sint64 ->
        quote do
          integer()
        end

      :fixed32 ->
        quote do
          non_neg_integer()
        end

      :fixed64 ->
        quote do
          non_neg_integer()
        end

      :sfixed32 ->
        quote do
          integer()
        end

      :sfixed64 ->
        quote do
          integer()
        end

      :bool ->
        quote do
          boolean()
        end

      :string ->
        quote do
          String.t()
        end

      :bytes ->
        quote do
          binary()
        end
    end
  end

  defp encode_decode(_name) do
    quote do
      def decode(data), do: Decoder.decode(data, __MODULE__)
      def encode(%{} = record), do: Encoder.encode(record, defs())
      def decode_delimited(bytes), do: Delimited.decode(bytes, __MODULE__)
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
        def defs(:field, unquote(rnum - 1)), do: unquote(Macro.escape(field))
        def defs(:field, unquote(name)), do: defs(:field, unquote(rnum - 1))
      end
    end
  end

  defp meta_information do
    quote do
      def defs, do: @root.defs
      def defs(:field, _), do: nil
      def defs(:field, field, _), do: defs(:field, field)
      defoverridable defs: 0
    end
  end

  defp record_fields(fields) do
    fields
    |> Enum.map(fn field ->
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
    |> Enum.reject(&is_nil/1)
  end
end
