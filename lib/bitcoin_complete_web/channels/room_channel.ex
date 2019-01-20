defmodule BitcoinCompleteWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("update", %{"body" => _body}, socket) do
    broadcast!(socket, "chain", %{body: BitcoinCompleteWeb.HomeController.getData()})
    {:noreply, socket}
  end
end
