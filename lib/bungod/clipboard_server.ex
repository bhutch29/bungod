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

  def handle_info({:update_clipboard, clipboard}, state) do
    Logger.info("New clip: #{clipboard}")
    Clipboard.copy(clipboard <> "HAHAHA")
    {:noreply, %{state | content: clipboard, syncing: true}}
  end

  def handle_info(:check_clipboard, %{content: content, syncing: syncing} = state) do
    clipboard = Clipboard.paste()

    if clipboard != "" && clipboard != content && !syncing do
      Logger.debug("Clipboard contents changed, broadcasting.")
      Phoenix.PubSub.broadcast(Bungod.PubSub, "clipboard", {:update_clipboard, clipboard})
    end

    schedule_check()

    {:noreply, %{state | content: clipboard, syncing: false}}
  end

  defp schedule_check do
    Process.send_after(self(), :check_clipboard, 2000)
  end
end
