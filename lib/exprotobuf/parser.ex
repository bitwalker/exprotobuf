defmodule Protobuf.Parser do

  defmodule ParserError do
    defexception [:message]
  end

  def parse(msgs),                            do: parse(msgs, [])
  def parse(defs, options) when is_list(defs) do
    {:ok, defs} = :gpb_parse.post_process_one_file(defs, options)
    :gpb_parse.post_process_all_files(defs, options)
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
end
