defmodule GDAX.MixProject do
  use Mix.Project

  def project do
    [
      app: :gdax,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  def escript do
    [main_module: GDAX]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # the below is broken; until patch is accepted and Hex updated, we use
      # our Git branch
      # {:ex_gdax, "~> 0.1"},
      # {:ex_gdax, git: "https://github.com/aquamatt/ex_gdax.git", tag: "v0.1.4-p1"},
      {:ex_doc, "~> 0.19"},
      {:ex_gdax, git: "https://github.com/bnhansn/ex_gdax.git"},
      {:websockex, "~> 0.4"},
      {:jason, "~> 1.1"}
    ]
  end
end
