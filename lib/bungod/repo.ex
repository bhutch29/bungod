defmodule Bungod.Repo do
  use Ecto.Repo,
    otp_app: :bungod,
    adapter: Ecto.Adapters.SQLite3
end
