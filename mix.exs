defmodule LoggerLogentriesBackend.Mixfile do
  use Mix.Project

  def project do
    [
      app: :logger_logentries_backend,
      version: "0.0.1",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger]
    ]
  end

  defp deps do
    []
  end

  defp description do
    """
    A Logger backend to support the Logentries service
    (logentries.com) TCP input log mechanism
    """
  end

  defp package do
    [
      files: ["config", "lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Sysdia Solutions"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sysdia-solutions/logger_logentries_backend"}
    ]
  end
end
