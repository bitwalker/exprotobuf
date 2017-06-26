defmodule Protobuf.Decoder do
  use Bitwise, only_operators: true

  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Utils

  # Decode with record/module
  def decode(bytes, module) do
    module.erl_module.decode_msg(bytes, Utils.to_module_atom(module))
    |> Utils.convert_from_record(module)
    |> convert_fields
  end

  def varint(bytes) do
    :gpb.decode_varint(bytes)
  end

  defp convert_fields(msg) do
    Enum.reduce(Map.keys(msg), msg, fn
      :__struct__, msg -> msg
      field, %{__struct__: module} = msg ->
        value = Map.get(msg, field)
        if value == :undefined do
          Map.put(msg, field, get_default(module.syntax(), field, module))
        else
          convert_field(value, msg, module.defs(:field, field))
        end
    end)
  end

  defp get_default(:proto2, field, module) do
    Map.get(struct(module), field)
  end
  defp get_default(:proto3, field, module) do
    case module.defs(:field, field) do
      %Protobuf.OneOfField{} -> nil
      x ->
        case x.type do
          :string ->
            ""
          ty ->
            case :gpb.proto3_type_default(ty, module.defs) do
              :undefined -> nil
              default -> default
            end
        end
    end
  end

  defp convert_field(value, msg, %Field{name: field, type: type, occurrence: occurrence}) do
    case {occurrence, type} do
      {:repeated, _} ->
        value =
          cond  do
            is_list(value) -> for v <- value, do: convert_value(type, v)
            is_map(value)  -> convert_value(type, value)
            true           -> value
          end
        Map.put(msg, field, value)
      {_, :string}   ->
        Map.put(msg, field, convert_value(type, value))
      {_, {:msg, _}} ->
        Map.put(msg, field, convert_value(type, value))
      _ ->
        msg
    end
  end

  defp convert_field(value, msg, %OneOfField{name: field}) do
    {key, inner_value} = value
    cond do
      is_tuple(inner_value) ->
        module = elem(inner_value, 0)
        converted_value = {key, inner_value |> Utils.convert_from_record(module) |> convert_fields}
        Map.put(msg, field, converted_value)
      is_list(inner_value) ->
        Map.put(msg, field, {key, convert_value(:string, inner_value)})
      true ->
        Map.put(msg, field, value)
    end
  end

  defp convert_value(:string, value),
    do: :unicode.characters_to_binary(value)
  defp convert_value({:msg, _}, value),
    do: value |> Utils.convert_from_record(elem(value, 0)) |> convert_fields
  defp convert_value({:map, key_type, value_type}, value) when is_map(value) do
    Enum.reduce(value, %{}, fn({key, value}, acc) ->
      key   = convert_value(key_type, key)
      value = convert_value(value_type, value)
      Map.merge(acc, %{key => value})
    end)
  end
  defp convert_value({:map, key_type, value_type}, {key, value}),
    do: {convert_value(key_type, key), convert_value(value_type, value)}
  defp convert_value(_, value),
    do: value
end
