defmodule Protobuf do
  alias Protobuf.Parser
  alias Protobuf.Builder
  alias Protobuf.Config
  alias Protobuf.ConfigError
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Utils

  # import IEx

  defmacro __using__(opts) do
    config = case opts do
      << schema :: binary >> ->
        %Config{namespace: __CALLER__.module, schema: schema}
      [<< schema :: binary >>, only: only] ->
        %Config{namespace: __CALLER__.module, schema: schema, only: parse_only(only, __CALLER__)}
      [<< schema :: binary >>, inject: true] ->
        only = __CALLER__.module |> Module.split |> Enum.join(".") |> String.to_atom
        %Config{namespace: __CALLER__.module, schema: schema, only: [only], inject: true}
      [<< schema :: binary >>, only: only, inject: true] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_type]  -> %Config{namespace: __CALLER__.module, schema: schema, only: types, inject: true}
        end
      _ ->
        namespace = Keyword.get(opts, :namespace, __CALLER__.module)
        doc = Keyword.get(opts, :doc, nil)
        opts = Keyword.delete(opts, :doc)
        opts = Keyword.delete(opts, :namespace)

        case opts do
          from: file ->
            %Config{namespace: namespace, from_file: file, doc: doc}
          from: file, use_package_names: use_package_names ->
            %Config{namespace: namespace, from_file: file, use_package_names: use_package_names, doc: doc}
          [from: file, only: only] ->
            %Config{namespace: namespace, only: parse_only(only, __CALLER__), from_file: file, doc: doc}
          [from: file, inject: true] ->
            %Config{namespace: namespace,  only: [namespace], inject: true, from_file: file, doc: doc}
          [from: file, only: only, inject: true] ->
            types = parse_only(only, __CALLER__)
            case types do
              []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
              [_type]  -> %Config{namespace: namespace, only: types, inject: true, from_file: file, doc: doc}
            end
        end
    end

    with {:ok, record_path} <- compile(:proto, opts[:from]),
      do: compile(:bytecode, record_path)

    # from = Path.expand(opts[:from])
    # if File.exists?(from) do
    #   pattern = ~r/(.+\/)(\w+.proto)/i
    #   [_, path, file_name] = Regex.run(pattern, from)
    #    record_path = ~w(priv gpb_records)
    #   full_record_path = Path.expand(Path.join(record_path), File.cwd!)
    #   File.mkdir_p(full_record_path)
    #   :gpb_compile.file(String.to_char_list(file_name), [{:i, String.to_char_list(path)}, {:o, String.to_char_list(full_record_path)}, :mapfields_as_maps])
    #   app_name = Mix.Project.get.project[:app] |> Atom.to_string
    #   :compile.file(String.to_char_list(Path.join(full_record_path, "user.erl")), [{:i, '_build/dev/lib/gpb/include'}, {:outdir, String.to_char_list("_build/dev/lib/#{app_name}/ebin")}])
    # end

    config |> parse(__CALLER__) |> Builder.define(config)
  end

  def compile(:proto, path) when is_binary(path) do
    with {:ok, paths} <- extract_paths(path),
         true         <- File.exists?(paths["fullpath"]) do
      compile(:proto, paths)
    else
      :error -> {:error, "Something went wrong!"}
    end
  end

  def compile(:proto, paths) when is_map(paths) do
    record_path = ~w(priv gpb_records)
    |> Path.join
    |> Path.expand(File.cwd!)
    |> String.to_char_list

    case File.mkdir_p(record_path) do
      :ok ->
        compilation = :gpb_compile.file(paths["file_name"],
          [{:i, paths["path"]},
           {:o, record_path}, :mapfields_as_maps])
        {compilation, record_path}
      _   -> :error
    end
  end

  def compile(:bytecode, record_path) do
    app_name = Mix.Project.get.project[:app] |> Atom.to_string
     File.ls!(record_path) 
     |> Enum.filter(&Regex.match?(~r/\.erl$/i, &1))
     |> Enum.map(fn (source_file) ->
        path = String.to_char_list(Path.join(record_path, source_file))
        build_path = '_build'
        if Mix.env == :dev, do: build_path = Path.join(build_path, 'dev')
       :compile.file(path,
         [{:i, Path.join(build_path, 'lib/gpb/include') |> String.to_char_list},
          {:outdir, Path.join(build_path, 'lib/exprotobuf_demo/ebin') |> String.to_char_list}])
     end)
  end

  def extract_paths(path) when byte_size(path) > 0 do
    paths = ~r/(?<fullpath>(?<path>.+\/)(?<file_name>\w+.proto))/i
    |> Regex.named_captures(Path.expand(path))
    |> Enum.reduce(%{}, fn({k, v}, acc) -> Map.merge(acc, %{k => String.to_char_list(v) }) end)
    {:ok, paths}
  end

  def extract_paths(_path), do: {:error, "The proto file path must be passed via :from option key" }

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
    Parser.parse_string!(schema) |> namespace_types(ns, inject)
  end
  defp parse(%Config{namespace: ns, inject: inject, from_file: file, use_package_names: use_package_names}, caller) do
    {paths, import_dirs} = resolve_paths(file, caller)
    Parser.parse_files!(paths, [imports: import_dirs, use_packages: use_package_names]) |> namespace_types(ns, inject)
  end

  # Apply namespace to top-level types
  defp namespace_types(parsed, ns, inject) do
    for {{type, name}, fields} <- parsed do
      if inject do
        {{type, :"#{name |> normalize_name}"}, namespace_fields(type, fields, ns)}
      else
        {{type, :"#{ns}.#{name |> normalize_name}"}, namespace_fields(type, fields, ns)}
      end
    end
  end

  # Apply namespace to nested types
  defp namespace_fields(:msg, fields, ns), do: Enum.map(fields, &namespace_fields(&1, ns))
  defp namespace_fields(_, fields, _),     do: fields
  defp namespace_fields(field, ns) when not is_map(field) do
    case elem(field, 0) do
      :gpb_oneof -> field |> Utils.convert_from_record(OneOfField) |> namespace_fields(ns)
      _          -> field |> Utils.convert_from_record(Field) |> namespace_fields(ns)
    end
  end
  defp namespace_fields(%Field{type: {:map, key_type, value_type}} = field, ns) do
    %{field | :type => {:map, key_type |> namespace_map_type(ns), value_type |> namespace_map_type(ns)}}
  end
  defp namespace_fields(%Field{type: {type, name}} = field, ns) do
    %{field | :type => {type, :"#{ns}.#{name |> normalize_name}"}}
  end
  defp namespace_fields(%Field{} = field, _ns) do
    field
  end
  defp namespace_fields(%OneOfField{} = field, ns) do
    field |> Map.put(:fields, Enum.map(field.fields, &namespace_fields(&1, ns)))
  end

  defp namespace_map_type({:msg, name}, ns) do
    {:msg, :"#{ns}.#{name |> normalize_name}"}
  end
  defp namespace_map_type(type, _ns) do
    type
  end

  # Normalizes module names by ensuring they are cased correctly
  # (respects camel-case and nested modules)
  defp normalize_name(name) do
    name
    |> Atom.to_string
    |> String.split(".", parts: :infinity)
    |> Enum.map(fn(x) -> String.split_at(x, 1) end)
    |> Enum.map(fn({first, remainder}) -> String.upcase(first) <> remainder end)
    |> Enum.join(".")
    |> String.to_atom
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
