defmodule Clipboard do
  require Logger

  @moduledoc """
  Copy and paste from system clipboard.
  """

  @doc """
  Copy `value` to system clipboard.

  The original `value` is always returned, so `copy/1` can be used in pipelines.

  # Examples

      iex> Clipboard.copy("Hello, World!")
      "Hello, World!"

      iex> Clipboard.copy(["Hello", "World!"])
      ["Hello", "World!"]

      iex> "Hello, World!" |> Clipboard.copy() |> IO.puts()
      "Hello, World"

  """
  @spec copy(iodata) :: iodata
  def copy(value) do
    case copy(:os.type(), value) do
      :ok ->
        value

      {:error, reason} ->
        Logger.info("Copy failed: #{reason}")
        value
    end
  end

  @doc """
  Copy `value` to system clipboard but throw exception if it fails.

  Identical to `copy/1`, except raise an exception if the operation fails.
  """
  @spec copy!(iodata) :: iodata | no_return
  def copy!(value) do
    case copy(:os.type(), value) do
      :ok ->
        value

      {:error, reason} ->
        raise reason
    end
  end

  defp copy({:unix, _os_name}, value) do
    command = case System.find_executable("wl-copy") do
      nil -> {"xclip", ["-sel", "clip"]} 
      _ -> {"wl-copy", []}
    end
    execute(command, value)
  end

  @doc """
  Return the contents of system clipboard.

  # Examples

      iex> Clipboard.paste()
      "Hello, World!"

  """
  @spec paste() :: String.t()
  def paste do
    case paste(:os.type()) do
      {:error, reason} ->
        Logger.info("Paste failed: #{reason}")
        nil

      output ->
        output
    end
  end

  @doc """
  Return the contents of system clipboard but throw exception if it fails.

  Identical to `paste/1`, except raise an exception if the operation fails.
  """
  @spec paste!() :: String.t() | no_return
  def paste! do
    case paste(:os.type()) do
      {:error, reason} ->
        raise reason

      output ->
        output
    end
  end

  defp paste({:unix, _os_name}) do
    command = case System.find_executable("wl-paste") do
      nil -> {"xclip", ["-o", "-sel", "clip"]} 
      _ -> {"wl-paste", []}
    end
    execute(command)
  end

  # Ports

  defp execute({executable, args}) when is_binary(executable) and is_list(args) do
    case System.find_executable(executable) do
      nil ->
        {:error, "Cannot find #{executable}"}

      _ ->
        case System.cmd(executable, args) do
          {output, 0} ->
            output

          {error, _} ->
            {:error, error}
        end
    end
  end

  defp execute({executable, args}, value) when is_binary(executable) and is_list(args) do
    case System.find_executable(executable) do
      nil ->
        {:error, "Cannot find #{executable}"}

      path ->
        port = Port.open({:spawn_executable, path}, [:binary, args: args])

        case value do
          value when is_binary(value) ->
            send(port, {self(), {:command, value}})

          value ->
            send(port, {self(), {:command, format(value)}})
        end

        send(port, {self(), :close})
        :ok
    end
  end

  defp format(value) do
    doc = Inspect.Algebra.to_doc(value, %Inspect.Opts{limit: :infinity})
    Inspect.Algebra.format(doc, :infinity)
  end
end
