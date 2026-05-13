defmodule Aether.MixProject do
  use Mix.Project

  def project do
    [
      app: :aether,
      version: "0.1.0",
      elixir: ">= 1.20.0-rc.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end
end
