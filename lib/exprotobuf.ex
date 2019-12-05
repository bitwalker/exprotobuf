defmodule Protobuf do
  alias Protobuf.Parser
  alias Protobuf.Builder
  alias Protobuf.Config
  alias Protobuf.ConfigError
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Utils

  defmacro __using__(schema) when is_binary(schema) do
    config = %Config{namespace: __CALLER__.module, schema: schema}

    config
    |> parse(__CALLER__)
    |> Builder.define(config)
  end

  defmacro __using__([schema | opts]) when is_binary(schema) do
    namespace = __CALLER__.module

    config =
      case Enum.into(opts, %{}) do
        %{only: only, inject: true} ->
          types = parse_only(only, __CALLER__)

          case types do
            [] ->
              raise ConfigError,
                error: "You must specify a type using :only when combined with inject: true"

            [_type] ->
              %Config{namespace: namespace, schema: schema, only: types, inject: true}
          end

        %{only: only} ->
          %Config{namespace: namespace, schema: schema, only: parse_only(only, __CALLER__)}

        %{inject: true} ->
          only = last_module(namespace)
          %Config{namespace: namespace, schema: schema, only: [only], inject: true}
      end

    use_google_types = get_in(opts, [:use_google_types]) || false

    %Config{config | use_google_types: use_google_types}
    |> parse(__CALLER__)
    |> Builder.define(config)
  end

  defmacro __using__(opts) when is_list(opts) do
    {namespace, opts} = Keyword.pop(opts, :namespace, __CALLER__.module)
    {doc, opts} = Keyword.pop(opts, :doc, nil)
    {use_google_types, opts} = Keyword.pop(opts, :use_google_types, false)
    opts = Enum.into(opts, %{})

    config =
      case opts do
        %{from: file, use_package_names: use_package_names, only: only, inject: true} ->
          types = parse_only(only, __CALLER__)

          case types do
            [] ->
              raise ConfigError,
                error: "You must specify a type using :only when combined with inject: true"

            [_type] ->
              %Config{
                namespace: namespace,
                only: types,
                inject: true,
                use_package_names: use_package_names,
                from_file: file,
                doc: doc
              }
          end

          only = last_module(namespace)

          %Config{
            namespace: namespace,
            only: [only],
            from_file: file,
            inject: true,
            use_package_names: use_package_names,
            doc: doc
          }

        %{from: file, use_package_names: use_package_names, inject: true} ->
          only = last_module(namespace)

          %Config{
            namespace: namespace,
            only: [only],
            from_file: file,
            inject: true,
            use_package_names: use_package_names,
            doc: doc
          }

        %{from: file, use_package_names: use_package_names} ->
          %Config{
            namespace: namespace,
            from_file: file,
            doc: doc,
            use_package_names: use_package_names,
            use_google_types: use_google_types,
          }

        %{from: file, only: only, inject: true} ->
          types = parse_only(only, __CALLER__)

          case types do
            [] ->
              raise ConfigError,
                error: "You must specify a type using :only when combined with inject: true"

            [_type] ->
              %Config{
                namespace: namespace, 
                only: types, 
                inject: true, 
                from_file: file, 
                doc: doc,
                use_google_types: use_google_types,
              }
          end

        %{from: file, only: only} ->
          %Config{
            namespace: namespace,
            only: parse_only(only, __CALLER__),
            from_file: file,
            doc: doc,
            use_google_types: use_google_types,
          }

        %{from: file, inject: true} ->
          only = last_module(namespace)
          %Config{
            namespace: namespace,  
            only: [only], 
            inject: true, 
            from_file: file, 
            doc: doc,
            use_google_types: use_google_types,
          }

        %{from: file} ->
          %Config{
            namespace: namespace, 
            from_file: file, 
            doc: doc,
            use_google_types: use_google_types,
          }
      end

    config
    |> parse(__CALLER__)
    |> Builder.define(config)
  end

  # Read the type or list of types to extract from the schema
  defp parse_only(only, caller) do
    {types, []} = Code.eval_quoted(only, [], caller)

    case types do
      types when is_list(types) -> types
      types when types == nil -> []
      _ -> [types]
    end
  end

  # Parse and fix namespaces of parsed types
  defp parse(%Config{schema: schema, inject: inject, from_file: nil} = config, caller) do
    ns = config.namespace
    mod_name =
      if inject do
        caller.module
      else
        ns
      end

    mod_name
    |> Parser.parse_string!(schema)
    |> namespace_types(ns, inject)
  end

  defp parse(%Config{inject: inject, from_file: file} = config, caller) do
    ns = config.namespace
    use_package_names = config.use_package_names
    {paths, import_dirs} = resolve_paths(config, file, caller)

    paths
    |> Parser.parse_files!(imports: import_dirs, use_packages: use_package_names)
    |> namespace_types(ns, inject)
  end

  # Apply namespace to top-level types
  defp namespace_types(parsed, ns, inject) do
    for {{type, name}, fields} <- parsed, is_atom(name) do
      parsed_type = if :gpb.is_msg_proto3(name, parsed), do: :proto3_msg, else: type

      if inject do
        ns_init = drop_last_module(ns)
        {{parsed_type, :"#{ns_init}.#{normalize_name(name)}"}, namespace_fields(type, fields, ns, true)}
      else
        {{parsed_type, :"#{ns}.#{normalize_name(name)}"}, namespace_fields(type, fields, ns, false)}
      end
    end
  end

  # Apply namespace to nested types
  defp namespace_fields(:msg, fields, ns, inject), do: Enum.map(fields, &namespace_fields(&1, ns, inject))
  defp namespace_fields(:proto3_msg, fields, ns, inject), do: Enum.map(fields, &namespace_fields(&1, ns, inject))
  defp namespace_fields(_, fields, _, _), do: fields

  defp namespace_fields(field, ns, inject) when not is_map(field) do
    case elem(field, 0) do
      :gpb_oneof ->
        field
        |> Utils.convert_from_record(OneOfField)
        |> namespace_fields(ns, inject)

      _ ->
        field
        |> Utils.convert_from_record(Field)
        |> namespace_fields(ns, inject)
    end
  end

  defp namespace_fields(%Field{type: {:map, key_type, value_type}} = field, ns, _inject) do
    key_type = namespace_map_type(key_type, ns)
    value_type = namespace_map_type(value_type, ns)
    %{field | type: {:map, key_type, value_type}}
  end

  defp namespace_fields(%Field{type: {type, name}} = field, ns, inject) do
    field_ns = if inject, do: drop_last_module(ns), else: ns
    %{field | :type => {type, :"#{field_ns}.#{normalize_name(name)}"}}
  end

  defp namespace_fields(%Field{} = field, _ns, _inject) do
    field
  end

  defp namespace_fields(%OneOfField{} = field, ns, inject) do
    fields = Enum.map(field.fields, &namespace_fields(&1, ns, inject))
    Map.put(field, :fields, fields)
  end

  defp namespace_map_type({:msg, name}, ns) do
    {:msg, :"#{ns}.#{normalize_name(name)}"}
  end

  defp namespace_map_type(type, _ns) do
    type
  end

  # Normalizes module names by ensuring they are cased correctly
  # (respects camel-case and nested modules)
  defp normalize_name(name) do
    name
    |> Atom.to_string()
    |> String.split(".", parts: :infinity)
    |> Enum.map(fn x -> String.split_at(x, 1) end)
    |> Enum.map(fn {first, remainder} -> String.upcase(first) <> remainder end)
    |> Enum.join(".")
    |> String.to_atom()
  end

  defp resolve_paths(%Config{use_google_types: google_types?}, quoted_files, caller) do
    google_proto = Path.join(Application.app_dir(:exprotobuf, "priv"), "google_protobuf.proto")

    paths =
      case Code.eval_quoted(quoted_files, [], caller) do
        {path, _} when is_binary(path) and google_types? ->
          [google_proto, path]

        {path, _} when is_binary(path) ->
          [path]

        {paths, _} when is_list(paths) and google_types? ->
          [google_proto | paths]

        {paths, _} when is_list(paths) ->
          paths
      end

    import_dirs =
      paths
      |> Enum.map(&Path.dirname/1)
      |> Enum.uniq()

    {paths, import_dirs}
  end

  # Returns the last module of a namespace
  defp last_module(namespace) do
    namespace 
    |> Module.split() 
    |> List.last() 
    |> String.to_atom()
  end

  defp drop_last_module(namespace) do
    namespace
    |> Atom.to_string()
    |> String.split(".")
    |> Enum.drop(-1)
    |> Enum.join(".")
    |> String.to_atom()
  end
end
