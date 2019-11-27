defmodule Commanded.Middleware.Uniqueness.MixProject do
  use Mix.Project

  def project do
    [
      app: :commanded_uniqueness_middleware,
      version: "0.5.0-pre1",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Commanded.Middleware.Uniqueness.Supervisor, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:commanded, "~> 1.0.0", runtime: false},
      {:cachex, "~> 3.2.0", optional: true},
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:faker, "~> 0.13", only: [:test, :dev]}
    ]
  end
end
