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
    "Google.Protobuf.BytesValue" => true,
  }
  |> Map.keys
  |> MapSet.new

  def standard_scalar_wrappers, do: @standard_scalar_wrappers

  def define_algebraic_type([ast_item]) do
    ast_item
  end
  def define_algebraic_type(ast_pair = [_, _]) do
    {
      :|,
      [],
      ast_pair
    }
  end
  def define_algebraic_type([ast_item | rest_ast_list]) do
    {
      :|,
      [],
      [
        ast_item,
        define_algebraic_type(rest_ast_list)
      ]
    }
  end

  def convert_to_record(map, module) do
    module.record
    |> Enum.reduce([record_name(module)], fn {key, default}, acc ->
      value = Map.get(map, key, default)
      [value_transform(module, value) | acc]
    end)
    |> Enum.reverse
    |> List.to_tuple
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
      meta = %Protobuf.Field{name: name}, acc = %{} ->
        Map.put(acc, name, meta)
      %Protobuf.OneOfField{name: name, fields: fields}, acc = %{} ->
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
    |> Enum.with_index
    |> Enum.reduce(map, fn {{key, _default}, idx}, acc ->
        # rec has the extra element when defines the record type
        value = elem(rec, idx + 1)
        Map.put(acc, key, value)
    end)
  end
end
