defmodule Protobuf.ConfigError do
  defexception [:message]
end

defmodule Protobuf.Config do
  @moduledoc """
  Defines a struct used for configuring the parser behavior.

  ## Options

  * `namespace`: The root module which will define the namespace of generated modules
  * `schema`: The schema as a string or a path to a file
  * `only`: The list of types to load. If empty, all are loaded.
  * `inject`: Flag which when set, determines whether the types loaded are injected into
    the current module. If set, then the source proto must only define a single type.
  * `use_google_types`: Determines whether or not to include `Google.Protobuf` scalar wrappers,
    which can be found in `<exprotobuf>/priv/google_protobuf.proto` for more details.

  """
  defstruct namespace: nil,
            schema: "",
            only: [],
            inject: false,
            from_file: nil,
            use_package_names: false,
            use_google_types: false,
            doc: nil

  def doc_quote(false) do
    quote do: @moduledoc(unquote(false))
  end

  def doc_quote(_), do: nil
end
