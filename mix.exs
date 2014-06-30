defmodule Protobuf.Mixfile do
  use Mix.Project

  def project do
    [app: :exprotobuf,
     version: "0.6.1",
     elixir: "~> 0.14.2",
     description: description,
     package: package,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: []]
  end

  defp description do
    """
    exprotobuf provides native encoding/decoding of 
    protobuf messages via generated modules/structs.
    """
  end

  defp package do
    [ files: ["lib", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Paul Schoenfelder", "azukiaapp"],
      licenses: ["Apache Version 2.0"],
      links: [ {"GitHub", "https://github.com/bitwalker/exprotobuf"} ] ]
  end

  # Dependencies can be hex.pm packages:
  #
  # {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  # {:foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{ :gpb, github: "tomas-abrahamsson/gpb" }]
  end
end
