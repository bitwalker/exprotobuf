defmodule Protobuf.Field do
  gpb_path = Path.join([Mix.Project.deps_path(), "gpb"])
  headers_path = Path.join([gpb_path, "include", "gpb.hrl"])

  case Version.compare(System.version(), "1.0.4") do
    :gt ->
      @record Record.Extractor.extract(:field, from: headers_path)

    _ ->
      @record Record.Extractor.extract(:"?gpb_field", from: headers_path)
  end

  defstruct @record

  def record, do: @record
end
