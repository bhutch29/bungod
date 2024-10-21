defmodule Bungod.ClusterWatcher do
  use GenServer
  require Logger

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    :net_kernel.monitor_nodes(true)
    {:ok, ""}
  end

  def handle_info({:nodeup, name}, state) do
    Logger.info("Node up: #{name}")
    {:noreply, state}
  end

  def handle_info({:nodedown, name}, state) do
    Logger.info("Node down: #{name}")
    {:noreply, state}
  end

end
