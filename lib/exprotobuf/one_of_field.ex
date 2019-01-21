defmodule Protobuf.OneOfField do
  gpb_path = Path.join([Mix.Project.deps_path(), "gpb"])
  headers_path = Path.join([gpb_path, "include", "gpb.hrl"])

  @record Record.Extractor.extract(:gpb_oneof, from: headers_path)

  defstruct @record

  def record, do: @record
end
