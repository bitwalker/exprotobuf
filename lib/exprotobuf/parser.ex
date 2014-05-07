defmodule Protobuf.Parser do

  defexception ParserError, error: nil do
    def message(ParserError[error: error]) do
      inspect(error)
    end
  end

  def parse(msgs),                             do: parse(msgs, [])
  def parse(defs, options) when is_list(defs), do: :gpb_parse.post_process(defs, options)
  def parse(string, options) do
    case :gpb_scan.string('#{string}') do
      {:ok, tokens, _} ->
        lines = String.split(string, "\n", parts: :infinity) |> Enum.count
        case :gpb_parse.parse(tokens ++ [{:'$end', lines + 1}]) do
          {:ok, defs} ->
            parse(defs, options)
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
      {:error, error} -> raise ParserError, error: error
    end
  end
end
