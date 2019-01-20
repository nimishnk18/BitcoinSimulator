defmodule BitcoinCompleteWeb.PageController do
  use BitcoinCompleteWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
