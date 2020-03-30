# GDAX API Test

## Overview

This code is a toy application written as a project through which to learn and
practice Elixir. As such, it's rough and ready and shouldn't really be used for
anything much at all.

If you're still here... it is used to pull trade history from a GDAX account
via the GDAX API, determine the current open position in the currency pairs
that you have requested, compute the P&L of all closed trades, the current P&L
of open positions and the net. It presents this data for each currency pair as
well as for the portfolio.

To compute the current value requires getting a market price for a potentially
large amount of currency. To do this, we connect to the GDAX websocket market
feed, get a snapshot of the order book and subscribe to updates. The code then
walks through the bids to dispose, virtually, of the current open holding, thus
giving a valuation based on the actual market availability rather than one
based on spot mid-market price. Note that this is a gross valuation as fees are
not computed. This is in part due to that fact that one might make a market
order, which attracts fees, or be a market maker which does not.

Future tweaks will be to make the application do more than a one shot valuation
and present a live update as order book updates flow in over the websocket
feed.

## Dependencies

This project is known to work with:

 * Erlang 21.1.4 + Elixir 1.7.4
 * Erlang 22.2.8 + Elixir 1.10.2

The author works on Linux Mint and found that the easiest way to get working
installations of the appropriate versions of these packages was to use the
`asdf` packaging tool. Install asdf from instructions here: https://github.com/asdf-vm/asdf

Install erlang, elixir:

```bash
> asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
> asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
> sudo apt-get install automake autoconf libreadline-dev libncurses-dev \
                       libssl-dev libyaml-dev libxslt-dev libffi-dev libtool \
                       unixodbc-dev
> asdf install erlang 22.2.8
> asdf install elixir 1.10.2-otp-22
> asdf global erlang 22.2.8
> asdf global elixir 1.10.2-otp-22
```

## Compilation

Copy the `config/local_config.exs.example` to `config/local_config.exs` and
edit, inserting your API key, secret and passphrase in the appropriate spots.

Compile with:

```bash
> mix deps.install
> mix escript.build
```

The `gdax` binary should be created.

## Usage

Proved `gdax` with a list of crypto currencies that you have traded, or for
which you want to see the positions and stats. Trades are assumed (hard coded)
for EUR pairs, e.g. the following:

```bash
> ./gdax btc ltc
```

will show all trades for BTCEUR and LTCEUR, because that's what I was
interested in. The interested reader can change this admitedly simple and
presumptuous behaviour.

If no currencies are specified then BTC is the default.

Output is a summary of your all-time trading position - ie the net P&L of all
trades done through GDAX including current value of open positions.

Subsequently, a summary of the status of any open positions.

## Bug fixes

Strictly DIY - you're very much on your own!

