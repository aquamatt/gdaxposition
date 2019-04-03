defmodule GDAX.OrderTracker do
  @moduledoc """
  Handle the websocket connection to GDAX level2 feed, start up
  AssetOrderBook (AOB) processes to manage each asset's order book, and post
  events through to each AOB as required.
  """
  use GDAX.Websocket

  # Convert asset name string to atom without dash, e.g. BTC-EUR to :BTCEUR
  def asset_key(name) do
    String.to_atom(Regex.replace(~r/-/, name, ""))
  end

  def start (assets \\ ["BTC-EUR", "LTC-EUR"]) do
    assets
    |> Enum.map(&GDAX.AssetOrderBook.start_link(asset_key(&1)))
    |> IO.inspect

    start_link(assets, ["level2"])
  end

  def handle_msg(msg) do
    data = Jason.decode!(msg)
    case data["type"] do
      "snapshot" -> send asset_key(data["product_id"]), {:snapshot, data}
      "l2update" -> send asset_key(data["product_id"]), {:update, data}
      _ -> nil
    end
  end

  def handle_connect(_conn, state) do
    IO.puts "Order book tracker connected!"
    {:ok, state}
  end

  def handle_disconnect(_conn, state) do
    IO.puts "Order book tracker disconnected..."
    {:ok, state}
  end
end
