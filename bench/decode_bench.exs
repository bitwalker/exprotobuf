defmodule Exprotobuf.DecodeBench do
  use Benchfella
  alias Exprotobuf.Bench.Proto.Request
  alias Exprotobuf.Bench.Proto.Response

  @request  %Request{}
            |> Request.encode
  @response %Response{
              name: "hello",
              tags: ["hello", "world"]
            }
            |> Response.encode

  bench "request" do
    @request
    |> Request.decode
  end

  bench "response" do
    @response
    |> Response.decode
  end

  bench "apply request" do
    :erlang.apply(Request, :decode, [@request])
  end

  bench "apply response" do
    :erlang.apply(Response, :decode, [@response])
  end

end
