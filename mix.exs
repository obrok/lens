defmodule Lens.Mixfile do
  use Mix.Project

  def project do
    [
      app: :lens,
      version: "1.0.0",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :dev},
      {:dialyze, "~> 0.2", only: :dev}
    ]
  end

  defp description do
    "A utility for working with nested data structures."
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Paweł Obrok"],
      links: %{"GitHub" => "https://github.com/obrok/lens"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url_pattern: "https://github.com/obrok/lens/blob/master/%{path}#L%{line}"
    ]
  end
end
