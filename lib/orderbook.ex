defmodule GDAX.OrderBook do
  @moduledoc """
  Manage orderbook for currency pairs and determine
  trades and outcomes for buying selling currency
  """

  @doc """
  Convert string to float even if it is an integer, ie 1 and 1.0 both
  return 1.0 (float)
  """
  def string_to_float(s) do
    cond do
      String.match?(s, ~r/\./) -> String.to_float(s)
      true -> String.to_float(s <> ".0")
    end
  end

  defp _process_order_book_entry([price, volume, _]) do
      [string_to_float(price), string_to_float(volume)]
  end

  defp _process_order_book_entry([price, volume]) do
      [string_to_float(price), string_to_float(volume)]
  end

  def order_entry_map(orders) do
    Enum.map(orders, &_process_order_book_entry(&1))
  end

  @doc """
  Given a snapshot message from a level2 order book websocket feed, return
  a map as:

    %{:asks [{price, volume}, ...], :bids [{price, volume}, ...]}
  """
  def load_snapshot(snapshot) do
    asks = snapshot["asks"] |> order_entry_map
    bids = snapshot["bids"] |> order_entry_map
    %{asks: asks, bids: bids}
  end

  @doc """
  When updating an order book we need to find the value to update, or the spot
  into which to insert our new value. This requires splitting the order book
  into two lists based on the price value of the target element. The book is
  a list of the form: [[price, volume], ...] and the target is price.

  ## Examples
      iex> GDAX.OrderBook.apply_book_update([[10.0, 1], [9.0, 1], [8.0, 1]], [9.0, 0.5])
      [[10.0, 1], [9.0, 0.5], [8.0, 1]]
      iex> GDAX.OrderBook.apply_book_update([[8.0, 1], [9.0, 1], [10.0, 1]], [8.0, 0.5])
      [[8.0, 0.5], [9.0, 1], [10.0, 1]]

      iex> GDAX.OrderBook.apply_book_update([[10.0, 1], [9.0, 1], [8.0, 1]], [9.5, 1.0])
      [[10.0, 1], [9.5, 1.0], [9.0, 1], [8.0, 1]]
      iex> GDAX.OrderBook.apply_book_update([[8.0, 1], [9.0, 1], [10.0, 1]], [9.5, 1.0])
      [[8.0, 1], [9.0, 1], [9.5, 1.0], [10.0, 1]]

      iex> GDAX.OrderBook.apply_book_update([[10.0, 1], [9.0, 1], [8.0, 1]], [1.0, 0.5])
      [[10.0, 1], [9.0, 1], [8.0, 1], [1.0, 0.5]]

      iex> GDAX.OrderBook.apply_book_update([[10.0, 1], [9.0, 1], [8.0, 1]], [100.0, 1.0])
      [[100.0, 1.0], [10.0, 1], [9.0, 1], [8.0, 1]]

      iex> GDAX.OrderBook.apply_book_update([[8.0, 1], [9.0, 1], [10.0, 1]], [1.0, 0.5])
      [[1.0, 0.5], [8.0, 1], [9.0, 1], [10.0, 1]]

      iex> GDAX.OrderBook.apply_book_update([[8.0, 1], [9.0, 1], [10.0, 1]], [100.0, 0.5])
      [[8.0, 1], [9.0, 1], [10.0, 1], [100.0, 0.5]]

      iex> GDAX.OrderBook.apply_book_update([[8.0, 1], [9.0, 1], [10.0, 1]], [9.0, 0.0])
      [[8.0, 1], [10.0, 1]]

  """
  def apply_book_update(book, new_entry, left \\ [])
  def apply_book_update([[p_now,_]=now, [p_next,_]=next | rest],
                        [target, volume]=new_entry,
                        left) do
    # note the Enum.reverse is done to do slow operation only once, allowing us
    # to build the 'left' in reverse order using fast [h|t] operations. The ++
    # is slow, but again we do it once.
    cond do
      # target matches element in the list...
      p_now == target and volume > 0.0 ->
        Enum.reverse(left) ++ [new_entry, next | rest]

      # ... but update has zero volume so we drop this price point from the
      # book
      p_now == target and volume == 0.0 ->
        Enum.reverse(left) ++ [next | rest]

      # target is to find itself at the start of the new list
      p_now < target and p_next < p_now ->
        [new_entry] ++ [now, next | rest]
      p_now > target and p_next > p_now ->
        [new_entry] ++ [now, next | rest]

      # target inserts between two elements in the list
      p_now < target and target < p_next ->
        Enum.reverse([now|left]) ++ [new_entry, next|rest]

      p_now > target and target > p_next ->
        Enum.reverse([now|left]) ++ [new_entry, next|rest]

      true -> apply_book_update([next|rest], new_entry, [now|left])
    end
  end

  def apply_book_update([[p_now,_]=now], [target,_]=new_entry, left) do
    cond do
      p_now == target ->
        Enum.reverse(left) ++ [new_entry]
      true ->
        Enum.reverse([now|left]) ++ [new_entry]
    end
  end

  @doc """
  Update a complete order book (as returned by load_snapshot)
  Update record is of the form:

  %{
    "changes" => [["buy", "5535.10000000", "0"]],
    "product_id" => "BTC-EUR",
    "time" => "2018-10-30T21:25:08.355Z",
    "type" => "l2update"
  }
  """
  def update_book(%{"changes" => c}, %{bids: bids, asks: asks} = book) do
    [sells, buys] = c
    |> Enum.split_with(fn [side|_] -> side == "sell" end)
    |> Tuple.to_list
    # for each of the sell and buy lists, convert strings to floats
    # and loose the sell/buy string
    |> Enum.map(fn x ->
          Enum.map(x,
                   fn [_, p, v] -> [string_to_float(p), string_to_float(v)]
          end)
       end)
    new_bids = Enum.reduce(buys, bids, fn update, bids -> apply_book_update(bids, update) end)
    new_asks = Enum.reduce(sells, asks, fn update, asks -> apply_book_update(asks, update) end)
    %{book | bids: new_bids, asks: new_asks}
  end

  # includes check to see if there's data in the book - if the connection is slow
  # or due to timing issue, on first startup this call may happen before the order
  # data has been received.
  defp _fetch_book_side(ccypair, bid_or_ask) do
    asset_key = GDAX.OrderTracker.asset_key(ccypair)
    send asset_key, {:getbook, self(), bid_or_ask}
    receive do
      book -> if length(book) == 0, do: _fetch_book_side(ccypair, bid_or_ask), else: book
    end
  end

  @doc """
  Return effective price at which given size of currency could be
  bought/sold given current order book.

  Returns {pair, size, effective price, cost} where cost is
  effective price * size.

  side is :sell or :buy
  """
  def trade(ccypair, size, side) do
    case side do
      :sell -> _fetch_book_side(ccypair, :bids) |> fill_trade(size)
      :buy -> _fetch_book_side(ccypair, :asks) |> fill_trade(size)
    end

  end

  # Initialise the trade-filling process and start
  defp fill_trade(book, size) do
    fill_trade(%{ordered: size, cost: 0.0, trades: []}, book, size)
  end

  # Trade has been filled successfully, so enrich the response data and return
  defp fill_trade(acc, _, 0.0) do
    effective_rate = acc.cost / acc.ordered

    response =
      acc
      |> Map.put(:trade_count, length(acc.trades))
      |> Map.put(:price, effective_rate)

    {:ok, response}
  end

  # Run out of orders in the order book to fill this trade against
  defp fill_trade(_, [], remaining) do
    {:error, "Could not fill trade - #{remaining} remaining"}
  end

  # The main function that will iterate over orders in the order book to fill
  # a trade of the requested size, accumulating data about the trade on the
  # way.
  defp fill_trade(accumulator, [[price, volume] | rest_of_book], size) do
    {traded, remaining} =
      cond do
        volume < size -> {volume, size - volume}
        true -> {size, 0.0}
      end

    accumulator
    |> Map.put(:cost, accumulator.cost + traded * price)
    |> Map.put(:trades, accumulator.trades ++ [{price, traded}])
    |> fill_trade(rest_of_book, remaining)
  end

  @doc """
  Return spot trade value of currency pair, for sale with given size
  """
  def sell(ccypair, size), do: trade(ccypair, size, :sell)

  @doc """
  Return spot trade value of currency pair, for buy with given size
  """
  def buy(ccypair, size), do: trade(ccypair, size, :buy)
end
