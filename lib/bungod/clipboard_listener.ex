defmodule Bungod.ClipboardListener do
  use GenServer
  require Logger

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Phoenix.PubSub.subscribe(Bungod.PubSub, "clipboard")
    {:ok, ""}
  end

  def handle_info({:new, clipboard}, state) do
    Logger.info("New clip: #{clipboard}")
    {:noreply, state}
  end

end
