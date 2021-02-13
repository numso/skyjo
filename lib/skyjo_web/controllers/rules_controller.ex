defmodule SkyjoWeb.RulesController do
  use SkyjoWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
