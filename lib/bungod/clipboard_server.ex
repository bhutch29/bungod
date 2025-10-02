defmodule Bungod.ClipboardServer do
  use GenServer
  require Logger

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Phoenix.PubSub.subscribe(Bungod.PubSub, "clipboard")
    schedule_check()
    {:ok, %{content: Clipboard.paste(), syncing: false}}
  end

  # Clipboard uses Port which sends :closed message that needed handling to avoid crash
  def handle_info({_port, :closed}, state) do
    {:noreply, state}
  end

  def handle_info({:update_clipboard, clipboard, from_node}, state) do
    if from_node == node() do 
      {:noreply, state}
    else

      Clipboard.copy(clipboard)
      {:noreply, %{state | content: clipboard, syncing: true}}
    end
  end

  def handle_info(:check_clipboard, %{content: content, syncing: syncing} = state) do
    clipboard = Clipboard.paste()

    if clipboard != nil && clipboard != "" && clipboard != content && !syncing do
      Logger.debug("Clipboard contents changed, broadcasting: " <> clipboard)
      Phoenix.PubSub.broadcast(Bungod.PubSub, "clipboard", {:update_clipboard, clipboard, node()})
    end

    schedule_check()

    {:noreply, %{state | content: clipboard, syncing: false}}
  end

  defp schedule_check do
    Process.send_after(self(), :check_clipboard, 500)
  end
end
