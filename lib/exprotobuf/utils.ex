defmodule Protobuf.Utils do
  @moduledoc false
  alias Protobuf.OneOfField
  alias Protobuf.Field

  @standard_scalar_wrappers %{
    "Google.Protobuf.DoubleValue" => true,
    "Google.Protobuf.FloatValue" => true,
    "Google.Protobuf.Int64Value" => true,
    "Google.Protobuf.UInt64Value" => true,
    "Google.Protobuf.Int32Value" => true,
    "Google.Protobuf.UInt32Value" => true,
    "Google.Protobuf.BoolValue" => true,
    "Google.Protobuf.StringValue" => true,
    "Google.Protobuf.BytesValue" => true
  }

  defmacro is_scalar(v) do
    quote do
      (is_atom(unquote(v)) and unquote(v) != nil) or is_number(unquote(v)) or
        is_binary(unquote(v))
    end
  end

  def is_standard_scalar_wrapper(module) when is_atom(module) do
    mod =
      module
      |> Module.split()
      |> Enum.take(-3)
      |> Enum.join(".")

    Map.has_key?(@standard_scalar_wrappers, mod)
  end

  def is_enum_wrapper(module, enum_module) when is_atom(module) and is_atom(enum_module) do
    Atom.to_string(module) == "#{enum_module}Value"
  end

  def define_algebraic_type([item]), do: item

  def define_algebraic_type([lhs, rhs]) do
    quote do
      unquote(lhs) | unquote(rhs)
    end
  end

  def define_algebraic_type([lhs | rest]) do
    quote do
      unquote(lhs) | unquote(define_algebraic_type(rest))
    end
  end

  def convert_to_record(map, module) do
    module.record
    |> Enum.reduce([record_name(module)], fn {key, default}, acc ->
      value = Map.get(map, key, default)
      [value_transform(module, value) | acc]
    end)
    |> Enum.reverse()
    |> List.to_tuple()
  end

  def msg_defs(defs) when is_list(defs) do
    defs
    |> Enum.reduce(%{}, fn
      {{:msg, module}, meta}, acc = %{} ->
        Map.put(acc, module, do_msg_defs(meta))

      {{type, _}, _}, acc = %{} when type in [:enum, :extensions, :service, :group] ->
        acc
    end)
  end

  defp do_msg_defs(defs) when is_list(defs) do
    defs
    |> Enum.reduce(%{}, fn
      meta = %Field{name: name}, acc = %{} ->
        Map.put(acc, name, meta)

      %OneOfField{name: name, fields: fields}, acc = %{} ->
        Map.put(acc, name, do_msg_defs(fields))
    end)
  end

  defp record_name(OneOfField), do: :gpb_oneof
  defp record_name(Field), do: :field
  defp record_name(type), do: type

  defp value_transform(_module, nil), do: :undefined

  defp value_transform(OneOfField, value) when is_list(value) do
    Enum.map(value, &convert_to_record(&1, Field))
  end

  defp value_transform(_module, value), do: value

  def convert_from_record(rec, module) do
    map = struct(module)

    module.record
    |> Enum.with_index()
    |> Enum.reduce(map, fn {{key, _default}, idx}, acc ->
      # rec has the extra element when defines the record type
      value = elem(rec, idx + 1)
      Map.put(acc, key, value)
    end)
  end
end
