defmodule Protobuf.Mixfile do
  use Mix.Project

  def project do
    [app: :exprotobuf,
     version: "1.2.9",
     elixir: "~> 1.2",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     consolidate_protocols: Mix.env == :prod,
     deps: deps(),
     dialyzer: [
       plt_add_deps: :transitive,
       ignore_warnings: ".dialyzer.ignore-warnings"
     ]
    ]
  end

  def application do
    [applications: [:gpb]]
  end

  defp description do
    """
    exprotobuf provides native encoding/decoding of
    protobuf messages via generated modules/structs.
    """
  end

  defp package do
    [ files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["Apache Version 2.0"],
      links: %{"GitHub": "https://github.com/bitwalker/exprotobuf"} ]
  end

  defp deps do
    [{:gpb, "~> 3.24"},
     {:ex_doc, "~> 0.13", only: :dev},
     {:dialyxir, "~> 0.5", only: :dev}]
  end
end
