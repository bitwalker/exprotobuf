defmodule Protobuf.Field do
  @record Record.Extractor.extract(:field, from: Path.join([Mix.Project.deps_path, "gpb", "include", "gpb.hrl"]))
  defstruct @record

  def record, do: @record
end