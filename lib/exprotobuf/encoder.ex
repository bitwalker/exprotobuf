defmodule Protobuf.Encoder do
  alias Protobuf.Utils
  alias Protobuf.Field
  alias Protobuf.OneOfField

  # import IEx

  def encode(%{} = msg, module) do
    # fixed_msg = msg |> fix_undefined |> Utils.convert_to_record(msg.__struct__)
    erl_module = :user
    fixed_msg = msg |> Utils.convert_to_record(msg.__struct__) |> erl_module.encode_msg
    #|> :gpb.encode_msg(fixed_defs)
    # IEx.pry
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
  defp fix_value(value)  when is_map(value),   do: value |> fix_undefined |> Utils.convert_to_record(value.__struct__)
  defp fix_value(value)  when is_tuple(value), do: value |> Tuple.to_list |> Enum.map(&fix_value/1) |> List.to_tuple
  defp fix_value(value),                       do: value
end
