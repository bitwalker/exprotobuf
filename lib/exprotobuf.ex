defmodule Protobuf do
  alias Protobuf.Parser
  alias Protobuf.Builder
  alias Protobuf.Config
  alias Protobuf.ConfigError
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Utils

  defmacro __using__(opts) do
    namespace = __CALLER__.module
    config = case opts do
      << schema :: binary >> ->
        %Config{namespace: namespace, schema: schema}
      [<< schema :: binary >>, only: only] ->
        %Config{namespace: namespace, schema: schema, only: parse_only(only, __CALLER__)}
      [<< schema :: binary >>, inject: true] ->
        only = namespace |> Module.split |> Enum.join(".") |> String.to_atom
        %Config{namespace: namespace, schema: schema, only: [only], inject: true}
      [<< schema :: binary >>, only: only, inject: true] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, schema: schema, only: types, inject: true}
        end
      from: file ->
        %Config{namespace: namespace, schema: nil, from_file: file}
      [from: file, only: only] ->
        %Config{namespace: namespace, schema: nil, only: parse_only(only, __CALLER__), from_file: file}
      [from: file, inject: true] ->
        %Config{namespace: namespace, schema: nil, inject: true, from_file: file}
      [from: file, only: only, inject: true] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, only: types, inject: true, from_file: file}
        end
    end

    config |> parse(__CALLER__) |> Builder.define(config)
  end

  # Read the type or list of types to extract from the schema
  defp parse_only(only, caller) do
    {types, []} = Code.eval_quoted(only, [], caller)
    case types do
      types when is_list(types) -> types
      types when types == nil   -> []
      _                         -> [types]
    end
  end

  # Parse and fix namespaces of parsed types
  defp parse(%Config{namespace: ns, schema: schema, inject: inject, from_file: nil}, _) do
    Parser.parse_string!(schema, use_packages: true) |> namespace_types(ns, inject)
  end
  defp parse(%Config{namespace: ns, inject: inject, from_file: file}, caller) do
    {paths, import_dirs} = resolve_paths(file, caller)
    Parser.parse_files!(paths, [imports: import_dirs, use_packages: true]) |> namespace_types(ns, inject)
  end

  # Apply namespace to top-level types
  defp namespace_types(parsed, ns, inject) do
    prefix = namespace_prefix(parsed, ns, inject)
    for {{type, name}, fields} <- parsed do
      {{type, normalize_name(prefix, name)}, namespace_fields(type, fields, prefix)}
    end
  end

  # Apply namespace to nested types
  defp namespace_fields(:msg, fields, prefix), do: Enum.map(fields, &namespace_fields(&1, prefix))
  defp namespace_fields(_, fields, _),     do: fields
  defp namespace_fields(field, prefix) when not is_map(field) do
    case elem(field, 0) do
      :gpb_oneof -> field |> Utils.convert_from_record(OneOfField) |> namespace_fields(prefix)
      _          -> field |> Utils.convert_from_record(Field) |> namespace_fields(prefix)
    end
  end
  defp namespace_fields(%Field{type: {type, name}} = field, prefix) do
    %{field | :type => {type, normalize_name(prefix, name)}}
  end
  defp namespace_fields(%Field{} = field, _prefix) do
    field
  end
  defp namespace_fields(%OneOfField{} = field, prefix) do
    field |> Map.put(:fields, Enum.map(field.fields, &namespace_fields(&1, prefix)))
  end

  defp namespace_prefix(parsed, _ns, true), do: ["Elixir" | namespace_prefix(parsed)]
  defp namespace_prefix(parsed, ns, false), do: [Atom.to_string(ns) | namespace_prefix(parsed)]
  defp namespace_prefix(_), do: []

  # Normalizes module names by ensuring they are cased correctly
  # (respects camel-case and nested modules)
  defp normalize_name(prefix, name) do
    (prefix ++ normalize_name(name))
    |> Enum.join(".")
    |> String.to_atom
  end
  defp normalize_name(name) do
    name
    |> Atom.to_string
    |> String.split(".", parts: :infinity)
    |> Enum.map(fn(x) -> String.split_at(x, 1) end)
    |> Enum.map(fn({first, remainder}) -> String.upcase(first) <> remainder end)
  end

  defp resolve_paths(quoted_files, caller) do
    paths = case Code.eval_quoted(quoted_files, [], caller) do
      {path, _} when is_binary(path) -> [path]
      {paths, _} when is_list(paths) -> paths
    end

    import_dirs = Enum.map(paths, &Path.dirname/1) |> Enum.uniq

    {paths, import_dirs}
  end
end
