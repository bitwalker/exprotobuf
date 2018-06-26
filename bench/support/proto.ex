defmodule Exprotobuf.Bench.Proto do
  use Protobuf, """
    syntax="proto3";

    package Demo.Data;

    message Request {

    }

    message Response {
      string          name = 1;
      repeated string tags = 2;
    }
  """
end
