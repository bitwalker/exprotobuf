defexception Protobuf.ConfigError, error: nil do
  def message(Protobuf.ConfigError[error: error]) do
    inspect(error)
  end
end

defmodule Protobuf.Config do
  @moduledoc """
  Defines a struct used for configuring the parser behavior.

  defstruct namespace: nil, # The root module which will define the namespace of generated modules
            schema: "",     # The schema as a string, either provided direct, or read from file
            only: [],       # The list of types to load, if empty, all are loaded
            inject: false   # Flag which determines whether the types loaded are injected in the 'using' module.
                            # `inject: true` requires only with a single type defined, since no more than one struct
                            # can be defined per-module. 
  """
  defstruct namespace: nil,
            schema: "",
            only: [],
            inject: false
end