defmodule Protobuf.Utils do
  @moduledoc false

  def convert_to_record(map, module) do
    # Convert module name if necessary
    record_name = case module do
      Protobuf.Field -> :field
      _              -> module
    end
    # Convert the map to it's record representation by
    # using the record schema originally extracted and
    # defined in the module provided. For each field
    # defined in the schema, get that field from the map,
    # then add it to a list of values matching the record's
    # original order. Convert that list to a tuple when done.
    module.record
    |> Enum.reduce([record_name], fn {key, default}, acc ->
      value = Map.get(map, key, default)
      [value|acc]
    end)
    |> Enum.reverse
    |> List.to_tuple
  end

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