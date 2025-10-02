defmodule Bungod.ClipboardServer do
  use GenServer
  require Logger

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Phoenix.PubSub.subscribe(Bungod.PubSub, "clipboard")
    schedule_check()
    {:ok, %{content: Clipboard.paste()}}
  end

  # Clipboard uses Port which sends :closed message that needed handling to avoid crash
  def handle_info({_port, :closed}, state) do
    {:noreply, state}
  end

  def handle_info({:update_clipboard, clipboard}, state) do
    Logger.info("New clip: #{clipboard}")
    Clipboard.copy(clipboard)
    {:noreply, %{state | content: clipboard}}
  end

  def handle_info(:check_clipboard, %{content: content} = state) do
    clipboard = Clipboard.paste()

    new_state = if clipboard != nil && clipboard != "" && clipboard != content do
      Logger.debug("Clipboard contents changed locally, broadcasting.")
      Phoenix.PubSub.broadcast(Bungod.PubSub, "clipboard", {:update_clipboard, clipboard})
      %{state | content: clipboard}
    else
      state
    end

    schedule_check()
    {:noreply, new_state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_clipboard, 500)
  end
end
