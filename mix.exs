defmodule Protobuf.Mixfile do
  use Mix.Project

  def project do
    [app: :exprotobuf,
     version: "1.2.11",
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     consolidate_protocols: Mix.env == :prod,
     deps: deps()]
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
    [ organization: "coingaming",
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Paul Schoenfelder", "Ilja Tkachuk aka timCF"],
      licenses: ["Apache Version 2.0"],
      links: %{"GitHub": "https://github.com/coingaming/exprotobuf"} ]
  end

  defp deps do
    [
      {:gpb, "~> 3.24"},
      {:ex_doc, "~> 0.13", only: :dev},
      {:benchfella, "~> 0.3.0", only: [:dev, :test], runtime: false}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support", "bench/support"]
  defp elixirc_paths(:dev),  do: ["lib", "bench/support"]
  defp elixirc_paths(_),     do: ["lib"]

end
