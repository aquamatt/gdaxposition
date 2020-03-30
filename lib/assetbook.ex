defmodule GDAX.AssetOrderBook do
  @moduledoc """
  Implement a state holder for the exchange order book for an asset.
  Supports updating the order book and pricing amounts of assets.
  """
  def start_link(name) do
    {:ok, pid} = start_link()
    Process.register(pid, name)
    {:ok, pid, name}
  end

  def start_link do
    Task.start_link(fn -> run(%{asks: [], bids: []}) end)
  end

  @doc """
  Extract the order book from a snapshot message
  """
  def extract_book(snapshot) do
    IO.puts("Snapshot "<>snapshot["product_id"]<>" "<>inspect(self()))
    GDAX.OrderBook.load_snapshot(snapshot)
  end

  @doc """
  Update the order book as per update message
  """
  def update_book(updates, book) do
    GDAX.OrderBook.update_book(updates, book)
  end

  def get_book(order_book, caller) do
    send caller, order_book
    order_book
  end

  @doc """
  Side is :bids or :asks
  """
  def get_book(order_book, caller, side) do
    send caller, order_book[side]
    order_book
  end

  @doc """
  Notify update handler if it is registered and listening
  """
  def notify(order_book) do
    case Process.whereis(:mainthread) do
      nil -> nil
      pid -> send pid, "."
    end
    order_book
  end

  def run(order_book) do
    receive do
      {:snapshot, snapshot} -> snapshot |> extract_book |> run
      {:update, updates} -> updates |> update_book(order_book) |> notify |> run
      {:getbook, caller} -> order_book |> get_book(caller) |> run
      {:getbook, caller, side} -> order_book |> get_book(caller, side) |> run
    end
  end
end
