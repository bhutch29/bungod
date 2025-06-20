defmodule Bungod.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = [
      tailscale: [ strategy: Cluster.Strategy.Tailscale ]
    ]
    children = [
      Bungod.ClusterWatcher,
      {Cluster.Supervisor, [topologies, [name: Bungod.ClusterSupervisor]]},
      BungodWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:bungod, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Bungod.PubSub},
      # Start a worker by calling: Bungod.Worker.start_link(arg)
      # {Bungod.Worker, arg},
      Bungod.ClipboardServer,
      # Start to serve requests, typically the last entry
      BungodWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bungod.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BungodWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
