defmodule Protobuf.ConfigError do
  defexception [:message]
end

defmodule Protobuf.Config do
  @moduledoc """
  Defines a struct used for configuring the parser behavior.

  defstruct namespace: nil,         # The root module which will define the namespace of generated modules
            schema: "",             # The schema as a string, either provided direct, or read from file
            only: [],               # The list of types to load, if empty, all are loaded
            inject: false,          # Flag which determines whether the types loaded are injected in the 'using' module.
                                    # `inject: true` requires only with a single type defined, since no more than one struct
                                    # can be defined per-module.
            google_wrappers: false  # Include or not `Google.Protobuf` scalar wrappers to given protobuf schema
                                    # https://github.com/bitwalker/exprotobuf/blob/master/priv/google_protobuf.proto
  """
  defstruct namespace: nil,
            schema: "",
            only: [],
            inject: false,
            google_wrappers: false,
            from_file: nil,
            use_package_names: false,
            doc: nil


  def doc_quote(false) do
    quote do: @moduledoc unquote(false)
  end

  def doc_quote(_), do: nil
end
