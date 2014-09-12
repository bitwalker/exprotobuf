defmodule Protobuf.Mixfile do
  use Mix.Project

  def project do
    [app: :exprotobuf,
     version: "0.8.3",
     elixir: "~> 1.0.0",
     description: description,
     package: package,
     deps: deps]
  end

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
      links: %{"GitHub": "https://github.com/bitwalker/exprotobuf"} ]
  end

  defp deps do
    [{ :gpb, github: "tomas-abrahamsson/gpb" }]
  end
end
