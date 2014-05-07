defmodule Protobuf do
  alias Protobuf.Parser
  alias Protobuf.Builder
  alias Protobuf.Config
  alias Protobuf.ConfigError

  defmacro __using__(opts) do
    namespace = __CALLER__.module
    config = case opts do
      << schema :: binary >> ->
        %Config{namespace: namespace, schema: schema}
      [<< schema :: binary >>, only: only] ->
        %Config{namespace: namespace, schema: schema, only: parse_only(only, __CALLER__)}
      [<< schema :: binary >>, only: only, inject: true] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_,_|_]  -> raise ConfigError, error: "You may only specify a single type with :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, schema: schema, only: types, inject: true}
        end
      from: file ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__)}
      [from: file, only: only] ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: parse_only(only, __CALLER__)}
      [from: file, only: only, inject: true] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_,_|_]  -> raise ConfigError, error: "You may only specify a single type with :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: types, inject: true}
        end
    end

    config |> parse |> Builder.define(config)
  end

  # Read the file passed to :from
  defp read_file(file, caller) do
    {file, []} = Code.eval_quoted(file, [], caller)
    File.read!(file)
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
  defp parse(%Config{namespace: ns, schema: schema, inject: inject}) do
    Parser.parse!(schema) |> namespace_types(ns, inject)
  end

  # Apply namespace to top-level types
  defp namespace_types(parsed, ns, inject) do
    for {{type, name}, fields} <- parsed do
      if inject do
        {{type, :"#{name}"}, namespace_fields(type, fields, ns)}
      else
        {{type, :"#{ns}.#{name}"}, namespace_fields(type, fields, ns)}
      end
    end
  end

  # Apply namespace to nested types
  defp namespace_fields(:msg, fields, ns), do: Enum.map(fields, &namespace_fields(&1, ns))
  defp namespace_fields(_, fields, _),     do: fields
  defp namespace_fields(:field[type: {type, name}] = field, ns) do
    field.type { type, :"#{ns}.#{name}" }
  end
  defp namespace_fields(:field[] = field, _ns) do
    field
  end
end
