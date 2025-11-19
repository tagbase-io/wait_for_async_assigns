defmodule WaitForAsyncAssigns.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/tagbase-io/wait_for_async_assigns"

  def project do
    [
      app: :wait_for_async_assigns,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "WaitForAsyncAssigns",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:credo, "~> 1.6", optional: true, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Prevents "DBConnection.ConnectionError: client exited" errors in Phoenix LiveView tests
    by ensuring all async operations complete before test cleanup.
    """
  end

  defp package do
    [
      name: "wait_for_async_assigns",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      maintainers: ["Mario Uher"]
    ]
  end

  defp docs do
    [
      main: "WaitForAsyncAssigns",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
