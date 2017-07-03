defmodule Protobuf.Utils do
  @moduledoc false

  alias Protobuf.OneOfField
  alias Protobuf.Field

  def convert_to_record(map, module) do
    module.record
    |> Enum.reduce([record_name(module)], fn {key, default}, acc ->
      value = Map.get(map, key, default)
      [value_transform(module, value) | acc]
    end)
    |> Enum.reverse
    |> List.to_tuple
  end

  defp record_name(OneOfField), do: :gpb_oneof
  defp record_name(Field), do: :field
  defp record_name(type) when is_atom(type), do: to_module_atom(type)
  defp record_name(type), do: type

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

  def to_module_atom(module) do
    Atom.to_string(module)
    |> String.split(".")
    |> tl
    |> Enum.join(".")
    |> String.to_atom
  end
end
