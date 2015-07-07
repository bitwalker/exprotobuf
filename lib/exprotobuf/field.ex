defmodule Protobuf.Field do
  case Version.compare(System.version, "1.0.4") do
    :gt ->
      @record Record.Extractor.extract(:field, from: Path.join([Mix.Project.deps_path, "gpb", "include", "gpb.hrl"]))
    _ ->
      @record Record.Extractor.extract(:"?gpb_field", from: Path.join([Mix.Project.deps_path, "gpb", "include", "gpb.hrl"]))
  end
  defstruct @record

  def record, do: @record
end
