defmodule Bungod.ClipboardWatcher do
  use GenServer  

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [])
  end  

  def init(_) do
    schedule_check()
    {:ok, ""}
  end  

  def handle_info(:check_clipboard, state) do
    clipboard = Clipboard.paste # TODO: ? |> String.trim
    if clipboard != "" do
      if clipboard != state do
        # TODO: pubsub
        IO.puts "changed!"
      end
    end

    schedule_check()

    {:noreply, clipboard}
  end  

  defp schedule_check do
    Process.send_after(self(), :check_clipboard, 2000)
  end
end
