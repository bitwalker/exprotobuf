defmodule Protobuf do
  import Protobuf.Parse, only: [parse!: 1]
  import Protobuf.DefineRecords, only: [def_records: 1]

  defmacro __using__(opts) do
    defs = case opts do
      << string :: binary >> -> string
      from: file ->
        {file, []} = Code.eval_quoted(file, [], __CALLER__)
        File.read!(file)
    end

    module = __CALLER__.module
    parse_and_fixns(defs, module) |> def_records
  end

  # Call parse and fix namespaces
  defp parse_and_fixns(defs, ns) do
    parse!(defs) |> fix_defs_ns(ns)
  end

  defp fix_defs_ns(defs, ns) do
    for {{type, name}, fields} <- defs do
      {{type, :"#{ns}.#{name}"}, fix_fields_ns(type, fields, ns)}
    end
  end

  defp fix_fields_ns(:msg, fields, ns) do
    Enum.map(fields, &fix_field_ns(&1, ns))
  end

  defp fix_fields_ns(_, fields, _) do
    fields
  end

  defp fix_field_ns(:field[type: {type, name}] = field, ns) do
    field.type { type, :"#{ns}.#{name}" }
  end

  defp fix_field_ns(:field[] = field, _ns) do
    field
  end
end
