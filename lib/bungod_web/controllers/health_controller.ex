defmodule BungodWeb.HealthController do
  use BungodWeb, :controller

  def index(conn, _params) do
    json(conn, %{healthy: true})
  end
end
