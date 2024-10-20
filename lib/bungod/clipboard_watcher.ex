defmodule Bungod.ClipboardWatcher do
  use GenServer
  require Logger

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    schedule_check()
    {:ok, ""}
  end

  def handle_info(:check_clipboard, state) do
    clipboard = Clipboard.paste()

    if clipboard != "" do
      if clipboard != state do
        Logger.debug("Clipboard contents changed, broadcasting.")
        Phoenix.PubSub.broadcast(Bungod.PubSub, "clipboard", {:new, clipboard})
      end
    end

    schedule_check()

    {:noreply, clipboard}
  end

  defp schedule_check do
    Process.send_after(self(), :check_clipboard, 2000)
  end
end
