defmodule Protobuf.Encoder do
  def encode(%{} = msg, defs) do
    msg
    |> fix_undefined
    |> convert_to_record
    |> :gpb.encode_msg(defs)
  end

  defp fix_undefined(%{} = msg) do
    Enum.reduce(Map.keys(msg), msg, fn
      field, msg ->
        original = Map.get(msg, field)
        fixed    = fix_value(original)
        if original != fixed do
          Map.put(msg, field, fixed)
        else
          msg
        end
    end)
  end

  defp fix_value(nil),                         do: :undefined
  defp fix_value(values) when is_list(values), do: Enum.map(values, &fix_value/1)
  defp fix_value(value)  when is_map(value),   do: value |> fix_undefined |> convert_to_record
  defp fix_value(value),                       do: value

  defp convert_to_record(map) do
    map
    |> Map.to_list
    |> Enum.reduce([], fn {_key, value}, acc -> [value | acc] end)
    |> Enum.reverse
    |> list_to_tuple
  end
end
