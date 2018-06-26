defmodule Protobuf.Parser do

  defmodule ParserError do
    defexception [:message]
  end

  def parse_files!(files, options \\ []) do
    Enum.reduce(files, [], fn(path, defs) ->
      schema = File.read!(path)
      new_defs = parse!(schema, options)
      defs ++ new_defs
    end) |> finalize!(options)
  end

  def parse_string!(string, options \\ []) do
    parse!(string, options) |> finalize!(options)
  end

  defp finalize!(defs, options) do
    case :gpb_parse.post_process_all_files(defs, options) do
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

  defp parse(defs, options) when is_list(defs) do
    :gpb_parse.post_process_one_file("<no-file>", defs, options)
  end
  defp parse(string, options) when is_binary(string) do
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

  defp parse!(string, options) do
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
end
