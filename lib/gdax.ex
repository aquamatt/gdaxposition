defmodule GDAX do

  defp rgb(number) when number < 0.0, do: IO.ANSI.red
  defp rgb(number) when number > 0.0, do: IO.ANSI.green
  defp rgb(number) when number == 0.0, do: IO.ANSI.blue
  defp fmt(number, precision \\ 5) do
    [rgb(number), number|>Float.round(precision)|>Float.to_string, IO.ANSI.reset]
  end

  def summarise(positions), do: summarise(positions, 0.0, 0.0)

  def summarise([], port_value, crypto_value), do: {port_value, crypto_value}

  def summarise([{ccy, position}| rest], port_value, crypto_value) do
    IO.write(:stdio,
             [ccy, ": ", fmt(position.holding), " ",
            "\n\t Net closed positions - cost of open position: ", fmt(position.delta_eur), " EUR",
            "\n\t Open position value: ", fmt(position.ccy_spot_value), " EUR",
            "\n\t Spot all-time P/L: ", fmt(position.spot_value), " EUR\n"])
    summarise(rest,
              port_value+position.spot_value,
              crypto_value+position.ccy_spot_value)
  end

  def show_position(ccy) do
    {_, holding, cost, fees, value} = GDAX.Trades.get_current_position(ccy)
    net_cost = cost+fees
    net_pl = value + net_cost
    gross_pl = value + cost
    net_percentage_gain = case net_cost do
        0.0 -> 0.0
        net_cost -> -100*(net_pl/net_cost)
    end
    gross_percentage_gain = case cost do
        0.0 -> 0.0
        cost -> -100*(gross_pl/cost)
    end

    close_fees = value*0.005
    closed_pl = value-close_fees+cost
    closed_pl_percentage_gain = case cost do
        0.0 -> 0.0
        cost -> -100*(closed_pl/cost)
    end

    # effective purchase price (ex fees)
    buy_price = -1 * (net_cost / holding)

    # effective spot rate (ex fees)
    spot_price = value / holding

    # calculate break-even price
    break_even = -1 * cost / (0.995 * holding) 
    gross_spread = break_even - buy_price

    IO.write(:stdio, [ccy, " Holding: ", fmt(holding),
                      "\n\t Effective purchase rate: ", fmt(buy_price), " EUR/unit",
                      "\n\t Effective spot rate: ", fmt(spot_price), " EUR/unit",
                      "\n\t Break-even price (including fees): ", fmt(break_even), " EUR/unit",
                      "\n\t => Gross spread: ", fmt(gross_spread), " EUR",
                      "\n\t Net Cost: ", fmt(net_cost), " EUR",
                      "\n\t Fee: ", fmt(fees), " EUR",
                      "\n\t Value: ", fmt(value,2), " EUR",
                      "\n\t Estimated close fee: ", fmt(close_fees,2), " EUR",
                      "\n\t Gross spot P/L (% gain): ", fmt(net_pl, 2), " EUR (",
                          fmt(net_percentage_gain, 2), "%)",
                      "\n\t Net spot P/L (% gain less purchase fee): ", fmt(gross_pl, 2), " EUR (",
                          fmt(gross_percentage_gain, 2), "%)",
                      "\n\t Net close-out P/L (% gain less txn fees): ", fmt(closed_pl, 2), " EUR (",
                          fmt(closed_pl_percentage_gain, 2), "%)"])
    IO.puts ""
  end

  defp default_ccys([]), do: ["BTC"]
  defp default_ccys(args), do: args

  defp write_header(args) do
    IO.write :stdio, "\n\n----------------- GDAX Portfolio Position Report -----------------\n\n"
    IO.write :stdio, "All time portfolio summary ---------------------------------------\n\n"
    args
  end

  def show_summary(currencies) do
    currencies
    |> GDAX.Trades.get_balances
    # show all time global stats for each currency pair
    |> write_header
    |> summarise
    |> (fn {p,c} -> IO.write(:stdio, ["\n",
                                      "Spot all-time portfolio P/L: ",
                                      IO.ANSI.inverse,
                                      fmt(p), " EUR",
                                      IO.ANSI.inverse_off,
                                      "\nOpen position P/L: ", fmt(c), " EUR"]) end).()

    # show the open position stats for each currency pair
    IO.write :stdio, "\n\nOpen position status ---------------------------------------------\n\n"
    currencies|> Enum.reduce(0, fn ccy, _ -> show_position(ccy); 0 end)
  end

  def main(args) do
    {_, ccys, _} = args |> default_ccys |> parse_args

    currencies = ccys |> Enum.map(&String.upcase(&1 <> "-EUR"))
                                  #
    # fire up the order book tracker
    GDAX.OrderTracker.start currencies

    IO.write :stdio, [IO.ANSI.underline,
                      "\nNotes\n\n",
                      IO.ANSI.no_underline]
    IO.write :stdio, """
      Open position valuation does NOT include fees charged if disposed of
      through market orders.

      Net cost is cost of asset excluding fees
      Fee is the fee on entering the transaction
      Value is current spot value
      Estimated close fee would be fee charged on spot value transaction
      Gross spot PL is P/L excluding all fees
      Net spot P/L is P/L with fees for entering transaction subtracted, but not exit fees
      Net close-out P/L is P/L with entry and estimated exit fees subtracted.
      """

    currencies |> show_summary

    # register process name so that we can process order book updates
    # we should really spin out to another process here
    Process.register(self(), :mainthread)
    #            track_updates(currencies)
  end

  defp track_updates(currencies) do
    # This errors because in the orderbook.ex/line 152 it waits on a message,
    # but it gets '.' which is what this is supposed to receive as notification
    # that stuff has happened. But the other thing is waiting for a specific
    # message to itself and it doesn't get it. so... should run in another
    # process. Which requires new architecture...
    receive do
      _ -> show_summary(currencies)
    end
    track_updates(currencies)
  end

  defp parse_args(args) do
    OptionParser.parse(args, switches: [valuation: :boolean])
  end
end
