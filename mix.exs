defmodule Commanded.Middleware.Uniqueness.MixProject do
  use Mix.Project

  @version "0.6.1"

  def project do
    [
      app: :commanded_uniqueness_middleware,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package(),
      aliases: aliases(),
      name: "Commanded Uniqueness Middleware",
      source_url: "https://github.com/vheathen/commanded-uniqueness-middleware"
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
      {:commanded, ">= 1.0.0 and < 1.2.0", runtime: false},
      {:cachex, ">= 3.2.0 and < 3.4.0", optional: true},
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:faker, "~> 0.13", only: [:test, :dev]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"],
      "test.watch": ["test.watch --no-start"]
    ]
  end

  defp description do
    """
    Use CommandedUniquenessMiddleware to ensure short-term value uniqueness,
    usually during Commanded command dispatch.
    """
  end

  defp docs do
    [
      main: "getting-started",
      canonical: "http://hexdocs.pm/commanded_uniqueness_middleware",
      source_ref: "v#{@version}",
      extra_section: "GUIDES",
      extras: [
        "guides/Getting Started.md"
      ],
      groups_for_extras: [
        Introduction: [
          "guides/Getting Started.md"
        ]
      ]
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        ".formatter.exs",
        "README*",
        "LICENSE*",
        "test"
      ],
      maintainers: ["Vladimir Drobyshevskiy"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/vheathen/commanded-uniqueness-middleware",
        "Docs" => "http://hexdocs.pm/commanded_uniqueness_middleware"
      }
    ]
  end
end
