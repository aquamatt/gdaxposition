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
    {_, holding, cost, value} = GDAX.Trades.get_current_position(ccy)
    pl = value + cost
    IO.write(:stdio, [ccy, " Holding: ", fmt(holding),
                      "\n\t Cost: ", fmt(cost), " EUR",
                      "\n\t Value: ", fmt(value,2), " EUR",
                      "\n\t P/L (% gain): ", fmt(pl, 2), " EUR (", fmt(-100*(pl/cost), 2), "%)"])
    IO.puts ""
  end

  defp default_ccys([]), do: ["BTC"]
  defp default_ccys(args), do: args

  defp write_header(args) do
    IO.write :stdio, "\n\n----------------- GDAX Portfolio Position Report -----------------\n\n"
    IO.write :stdio, "All time portfolio summary ---------------------------------------\n\n"
    args
  end

  def main(args) do
    {_, ccys, _} = args |> default_ccys |> parse_args

    currencies = ccys |> Enum.map(&String.upcase(&1 <> "-EUR"))

    # fire up the order book tracker
    GDAX.OrderTracker.start currencies

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
    currencies |> Enum.reduce(0, fn ccy, _ -> show_position(ccy); 0 end)

    IO.write :stdio, [IO.ANSI.underline,
                      "\nNotes\n\n",
                      IO.ANSI.no_underline]
    IO.write :stdio, """
      Open position valuation does NOT include fees charged if disposed of
      through market orders.
      """

  end

  defp parse_args(args) do
    OptionParser.parse(args, switches: [valuation: :boolean])
  end
end
