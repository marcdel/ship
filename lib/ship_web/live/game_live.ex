defmodule ShipWeb.GameLive do
  use ShipWeb, :live_view

  alias Ship.Components.HullPoints
  alias Ship.Components.XPosition
  alias Ship.Components.YPosition

  def mount(_params, %{"player_token" => token} = _session, socket) do
    # This context function was generated by phx.gen.auth
    player = Ship.Players.get_player_by_session_token(token)

    socket =
      socket
      |> assign(player_entity: player.id)
        # Keeping a set of currently held keys will allow us to prevent duplicate keydown events
      |> assign(keys: MapSet.new())
        # We don't know where the ship will spawn, yet
      |> assign(x_coord: nil, y_coord: nil, current_hp: nil)

    # We don't want these calls to be made on both the initial static page render and again after
    # the LiveView is connected, so we wrap them in `connected?/1` to prevent duplication
    if connected?(socket) do
      ECSx.ClientEvents.add(player.id, :spawn_ship)
      :timer.send_interval(50, :load_player_info)
    end

    {:ok, socket}
  end

  def handle_info(:load_player_info, socket) do
    # This will run every 50ms to keep the client assigns updated
    x = XPosition.get(socket.assigns.player_entity)
    y = YPosition.get(socket.assigns.player_entity)
    hp = HullPoints.get(socket.assigns.player_entity)

    {:noreply, assign(socket, x_coord: x, y_coord: y, current_hp: hp)}
  end

  def handle_event("keydown", %{"key" => key}, socket) do
    if MapSet.member?(socket.assigns.keys, key) do
      # Already holding this key - do nothing
      {:noreply, socket}
    else
      # We only want to add a client event if the key is defined by the `keydown/1` helper below
      maybe_add_client_event(socket.assigns.player_entity, key, &keydown/1)
      {:noreply, assign(socket, keys: MapSet.put(socket.assigns.keys, key))}
    end
  end

  def handle_event("keyup", %{"key" => key}, socket) do
    # We don't have to worry about duplicate keyup events
    # But once again, we will only add client events for keys that actually do something
    maybe_add_client_event(socket.assigns.player_entity, key, &keyup/1)
    {:noreply, assign(socket, keys: MapSet.delete(socket.assigns.keys, key))}
  end

  defp maybe_add_client_event(player_entity, key, fun) do
    case fun.(key) do
      :noop -> :ok
      event -> ECSx.ClientEvents.add(player_entity, event)
    end
  end

  defp keydown(key) when key in ~w(w W ArrowUp), do: {:move, :north}
  defp keydown(key) when key in ~w(a A ArrowLeft), do: {:move, :west}
  defp keydown(key) when key in ~w(s S ArrowDown), do: {:move, :south}
  defp keydown(key) when key in ~w(d D ArrowRight), do: {:move, :east}
  defp keydown(_key), do: :noop

  defp keyup(key) when key in ~w(w W ArrowUp), do: {:stop_move, :north}
  defp keyup(key) when key in ~w(a A ArrowLeft), do: {:stop_move, :west}
  defp keyup(key) when key in ~w(s S ArrowDown), do: {:stop_move, :south}
  defp keyup(key) when key in ~w(d D ArrowRight), do: {:stop_move, :east}
  defp keyup(_key), do: :noop

  def render(assigns) do
    ~H"""
    <div id="game" phx-window-keydown="keydown" phx-window-keyup="keyup">
      <p>Player ID: <%= @player_entity %></p>
      <p>Player Coords: <%= inspect({@x_coord, @y_coord}) %></p>
      <p>Hull Points: <%= @current_hp %></p>
    </div>
    """
  end
end