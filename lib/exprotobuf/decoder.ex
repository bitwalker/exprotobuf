defmodule Protobuf.Decoder do
  use Bitwise, only_operators: true

  # Decode with record/module
  def decode(bytes, module) do
    #IO.inspect {bytes, module, module.defs}
    :gpb.decode_msg(bytes, module, module.defs)
    |> convert_from_record(module)
    |> fix_msg
  end

  def varint(bytes) do
    :gpb.decode_varint(bytes)
  end

  defp fix_msg(msg) do
    Enum.reduce(Map.keys(msg), msg, fn
      :__struct__, msg -> msg
      field, %{__struct__: module} = msg ->
        default = Map.get(struct(module), field)
        value   = Map.get(msg, field)
        if value == :undefined do
          Map.put(msg, field, default)
        else
          fix_field(value, msg, module.defs(:field, field))
        end
    end)
  end

  defp fix_field(value, msg, :field[name: field, type: type, occurrence: occurrence]) do
    case {occurrence, type} do
      {:repeated, _} ->
        value = for v <- value, do: fix_value(type, v)
        Map.put(msg, field, value)
      {_, :string}   ->
        Map.put(msg, field, fix_value(type, value))
      {_, {:msg, _}} ->
        Map.put(msg, field, fix_value(type, value))
      _ ->
        msg
    end
  end

  defp fix_value(:string, value),   do: :unicode.characters_to_binary(value)
  defp fix_value({:msg, _}, value), do: value |> convert_from_record(elem(value, 0)) |> fix_msg
  defp fix_value(_, value),         do: value

  defp convert_from_record(rec, module) do
    map = struct(module)

    Map.keys(map)
    |> Enum.with_index
    |> Enum.reduce(map, fn {key, idx}, acc ->
      value = elem(rec, idx)
      Map.put(acc, key, value)
    end)
  end
end
