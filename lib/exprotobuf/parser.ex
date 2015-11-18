defmodule Protobuf.Parser do

  defmodule ParserError do
    defexception [:message]
  end

  def parse(msgs),                             do: parse(msgs, [])
  def parse(defs, options) when is_list(defs) do
    {:ok, defs} = :gpb_parse.post_process_one_file(defs, options)
    imports = [] # TODO remove this feature entirely if we are going to replace it with imorting multiple files
    case read_and_parse_imports(imports, [], defs, options) do
      {:ok, {defs, _}} ->
        :gpb_parse.post_process_all_files(defs, options)
      {:error, _} = err ->
        err
    end
  end
  def parse(string, options) do
    case :gpb_scan.string('#{string}') do
      {:ok, tokens, _} ->
        lines = String.split(string, "\n", parts: :infinity) |> Enum.count
        case :gpb_parse.parse(tokens ++ [{:'$end', lines + 1}]) do
          {:ok, defs} -> parse(defs, options)
          error ->
            error
        end
      error ->
        error
    end
  end

  def parse!(string, options \\ []) do
    case parse(string, options) do
      {:ok, defs}     -> defs
      {:error, error} ->
        msg = case error do
          [ref_to_undefined_msg_or_enum: {{root_path, field}, type}] ->
            type_ref    = Enum.map(type, &Atom.to_string/1) |> Enum.join
            invalid_ref = Enum.reverse([field|root_path]) |> Enum.map(&Atom.to_string/1) |> Enum.join
            "Reference to undefined message or enum #{type_ref} at #{invalid_ref}"
          _ when is_binary(error) ->
            error
          _ ->
            Macro.to_string(error)
        end
        raise ParserError, message: msg
    end
  end

  defp read_and_parse_imports([import_path | rest], already_imported, defs, opts) do
    case :lists.member(import_path, already_imported) do
      true  -> read_and_parse_imports(rest, already_imported, defs, opts)
      false ->
        case do_import(import_path, already_imported, defs, opts) do
          {:ok, {defs, imported}} -> read_and_parse_imports(rest, imported, defs, opts)
          {:error, _} = err       -> err
        end
    end
  end
  defp read_and_parse_imports([], imported, defs, _), do: {:ok, {defs, imported}}

  defp do_import(import_path, already_imported, defs, opts) do
    case parse_file_and_imports(import_path, already_imported, opts) do
      {:ok, {imported_defs, imports}} ->
        defs = defs ++ imported_defs
        already_imported = :lists.usort(already_imported ++ imports)
        {:ok, {defs, already_imported}}
      {:error, _} = err ->
        err
    end
  end

  defp parse_file_and_imports(import_path, already_imported, opts) do
    case locate_import(import_path, opts) do
      {:ok, contents} ->
        already_imported = [import_path|already_imported]
        case :gpb_scan.string('#{contents}') do
          {:ok, tokens, _} ->
            lines = String.split(contents, "\n", parts: :infinity) |> Enum.count
            case :gpb_parse.parse(tokens++[{:'$end', lines + 1}]) do
              {:ok, parse_tree} ->
                case :gpb_parse.post_process_one_file(parse_tree, opts) do
                  {:ok, defs} ->
                    imports = :gpb_parse.fetch_imports(defs)
                    read_and_parse_imports(imports, already_imported, defs, opts)
                  {:error, _} = err ->
                    err
                end
              {:error, _} = err ->
                err
            end
          {:error, _} = err ->
            err
        end
      {:error, _} = err ->
        err
    end
  end

  defp locate_import(import_path, opts) do
    case Keyword.get(opts, :imports, nil) do
      nil -> File.read(import_path)
      import_directories ->
        # Try reading the path provided first, then search import directories
        case File.read(import_path) do
          {:ok, _} = res -> res
          {:error, _} ->
            try_locate_import(import_directories, import_path, opts)
        end
    end
  end
  defp try_locate_import([dir|rest], import_path, opts) do
    case File.read(Path.join(dir, import_path)) do
      {:ok, _} = res -> res
      {:error, _} -> try_locate_import(rest, import_path, opts)
    end
  end
  defp try_locate_import([], import_path, opts) do
    case Keyword.get(opts, :imports, nil) do
      nil ->
        {:error, "Could not locate import `#{import_path}`. File does not exist."}
      dirs ->
        pretty = Enum.join(dirs, "\n\t")
        {:error, "Could not locate import `#{import_path}` at that location and in any of the following paths:\n\t#{pretty}"}
    end
  end
end
