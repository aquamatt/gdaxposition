defmodule GDAX.Trades do
  @moduledoc """
  Documentation for GDAX.
  """

  @doc """
  Start by converting all keys to atoms and then
  convert received structure values to appropriate data types.
  """
  def retype(fill) do
    fill
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.update(:created_at, nil, &DateTime.from_iso8601(&1))
    |> Map.update(:fee, nil, &String.to_float(&1))
    |> Map.update(:price, nil, &String.to_float(&1))
    |> Map.update(:size, nil, &String.to_float(&1))
    |> Map.update(:usd_volume, nil, &String.to_float(&1))
  end

  defp side(%{side: "buy"}), do: -1
  defp side(%{side: "sell"}), do: 1

  def enrich(fill) do
    fill
    |> Map.put(:delta_eur, side(fill) * fill.size * fill.price - fill.fee)
    |> Map.put(:delta_ccy, fill.size * (-1 * side(fill)))
  end

  def get_fills(pair) do
    {:ok, fills} = ExGdax.list_fills(%{product_id: pair})

    fills
    |> Enum.map(&retype(&1))
    |> Enum.map(&enrich(&1))
  end

  def compute_balance(fills) do
    Enum.reduce(
      fills,
      {0.0, 0.0},
      fn fill, {ccy, eur} ->
        {ccy+fill.delta_ccy, eur+fill.delta_eur}
      end
    )
  end

  @doc """
  Return a spot EUR valuation for this ccy holding
  """
  def valuation(_, 0.0), do: {:ok, 0.0}
  def valuation(ccy, holding) do
    case GDAX.OrderBook.sell(ccy, holding) do
      {:ok, %{cost: value}} -> {:ok, value}
      {:error, msg} -> {:error, msg}
    end
  end

  # compute spot valuation of this currency holding
  # @TODO: COMPUTE FEES!!
  defp spot_value({delta_ccy, delta_eur}, ccy) do
    {:ok, value} = valuation(ccy, delta_ccy)
    {ccy,
     %{holding: delta_ccy,
       delta_eur: delta_eur,
       ccy_spot_value: value,
       spot_value: delta_eur + value
     }
    }
  end

  @doc """
  Iterate over all currencies in `currencies`, get the fills and
  show balances and spot valuations for each.
  """
  def get_balances(ccys), do: get_balances([], ccys)
  def get_balances(results, []), do: results

  def get_balances(results, [ccy | rest]) do
    ccy
    |> get_fills
    |> compute_balance
    |> spot_value(ccy)
    |> (fn x -> results ++ [x] end).()
    |> get_balances(rest)
  end

  @doc """
    Compute cost of the currently held position as sum of asset
    costs and fees. Can be used to compute effective rate.
  """
  def get_position_cost(fills, holding), do: get_position_cost(fills, 0.0, holding)
  def get_position_cost(_, cost, 0.0), do: cost
  def get_position_cost([fill | rest], cost, holding) do
    side_multiplier = side(fill)
    # Rounding required because floating point errors at the insignificant
    # end can cause the stop condition above  to fail. Could, I guess,
    # implement a guard in the header above instead of matching on 0.0
    get_position_cost(
      rest,
      cost+(fill.delta_eur)-fill.fee,
      Float.round(holding+(side_multiplier*fill.size), 10)
    )
  end

  @doc """
    Return current holding in `ccy` and, by backing up through filled orders,
    determine effective rate for this holding, total cost and, by interrogating
    the current order book, compute current value.
  """
  def get_current_position(ccy) do
    fills = ccy |> get_fills

    {_, %{holding: holding, ccy_spot_value: value}} =
        fills |> compute_balance  |> spot_value(ccy)

    # holding is rounded to precision of 10 so that the function head
    # in get_position_cost that matches on holding of 0.0 works. If not
    # rounded here, floating point error can result in a holding of very
    # small amt (e.g. 1e-15) which breaks things.
    cost = get_position_cost(fills, Float.round(holding, 10))
    {ccy, holding, cost, value}
  end
end
