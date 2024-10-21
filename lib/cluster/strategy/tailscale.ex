defmodule Cluster.Strategy.Tailscale do
  @moduledoc """
  Cluster strategy for connecting Elixir nodes over Tailscale.

      config :libcluster,
        topologies: [
          tailscale: [ strategy: Cluster.Strategy.Tailscale ]
        ]

  """
  use GenServer
  alias Cluster.Strategy.State
  require Logger

  @polling_interval 30_000

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init([%State{meta: nil} = state]) do
    init([%State{state | :meta => MapSet.new()}])
  end

  def init([%State{} = state]) do
    {:ok, load(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    handle_info(:load, state)
  end

  def handle_info(:load, %State{} = state) do
    {:noreply, load(state)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp load(%State{} = state) do
    nodes =
      state
      |> get_nodes()
      |> disconnect_nodes(state)
      |> connect_nodes(state)

    Process.send_after(self(), :load, @polling_interval)
    %{state | meta: nodes}
  end

  defp get_nodes(%State{config: _config}) do
    list_devices()
    |> Enum.filter(fn ip -> 
      # TODO: replace :4000 port here?
      url = "http://#{ip}:4000/is-bungod"
      case Req.get(url: url, retry: false, redirect: false) do
        {:ok, response} when response.status == 200 ->
          true
        {:ok, _response} ->
          false
        {:error, _error} ->
          false
      end
    end)
    |> Enum.map(&"bungod@#{&1}")
    |> Enum.map(&String.to_atom/1)
    |> MapSet.new()
  end

  defp disconnect_nodes(nodes, %State{} = state) do
    removed = MapSet.difference(state.meta, nodes)

    case Cluster.Strategy.disconnect_nodes(
           state.topology,
           state.disconnect,
           state.list_nodes,
           MapSet.to_list(removed)
         ) do
      :ok ->
        nodes

      {:error, bad_nodes} ->
        # Add back the nodes we couldn't remove
        Enum.reduce(bad_nodes, nodes, fn {n, _}, acc ->
          MapSet.put(acc, n)
        end)
    end
  end

  defp connect_nodes(nodes, %State{} = state) do
    case Cluster.Strategy.connect_nodes(
           state.topology,
           state.connect,
           state.list_nodes,
           MapSet.to_list(nodes)
         ) do
      :ok ->
        nodes

      {:error, bad_nodes} ->
        # Remove the nodes we couldn't add
        Enum.reduce(bad_nodes, nodes, fn {n, _}, acc ->
          MapSet.delete(acc, n)
        end)
    end
  end

  def list_devices() do
    json = case Jason.decode(tailscale_status!()) do
      {:ok, result} -> result
      {:error, error} -> 
        Logger.error("Could not parse tailscale status json: #{error}")
        []
    end

    Enum.map(json["Peer"], &elem(&1, 1))
    |> Enum.filter(&!Map.has_key?(&1, "Tags"))
    |> Enum.filter(&(&1["Online"]))
    |> Enum.map(&(&1["TailscaleIPs"]))
    |> Enum.map(&List.first(&1))
  end

  def tailscale_status!() do
    case System.cmd("tailscale", ["status", "--json"]) do
      {output, 0} -> output
      {output, code} ->
        if String.contains?(output, "is Tailscale running?") do
          Logger.error("Tailscale isn't running")
        else
          Logger.error("Unknown tailscale error. Code: #{code}, Message: #{output}")  
        end
        ""
    end
  end
end
