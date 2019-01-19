defmodule Protobuf.Mixfile do
  use Mix.Project

  def project do
    [app: :exprotobuf,
     version: "1.2.16",
     elixir: "~> 1.7",
     elixirc_paths: elixirc_paths(Mix.env),
     preferred_cli_env: [
       bench: :bench,
     ],
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
    [files: ["lib", "mix.exs", "README.md", "LICENSE", "priv"],
     maintainers: ["Paul Schoenfelder"],
     licenses: ["Apache Version 2.0"],
     links: %{"GitHub": "https://github.com/bitwalker/exprotobuf"} ]
  end

  defp deps do
    [
      {:gpb, "~> 4.0"},
      {:ex_doc, "~> 0.19", only: :dev},
      {:benchfella, "~> 0.3.0", only: [:dev, :test], runtime: false}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:bench), do: ["lib", "bench/support"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(_), do: ["lib"]
end
