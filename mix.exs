defmodule Monitarium.MixProject do
  use Mix.Project

  def project do
    [
      app: :monitarium,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, ">= 1.16.0", only: :test},
      {:prom_ex, "~> 1.12.0"},
      {:telemetry_test, "~> 0.1", only: :test}
    ]
  end
end
