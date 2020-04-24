#!/bin/bash
help() {
 echo " "
 echo " Given a functioning elixir environment, this script will do the basic"
 echo " work to get the gdax tool built."
 echo " "
 echo " Pre-requisites are: "
 echo " "
 echo "  - Elixir installation"
 echo "  - config/local_config.exs.example copied to config/local_config.exs"
 echo "    and parameters edited, keys inserted, as appropriate"
 echo " "
 echo " Simply execute this script to build gdax."
 echo " "
}

while getopts "h" opt
do
    case $opt in
        h) help
           exit 0
           ;;
       \?) echo "Invalid option: -${opt}" >&2
           help
           exit 1
           ;;
    esac
done

mix local.hex --force
mix local.rebar --force
mix deps.get --force
mix deps.compile --force
mix escript.build

echo ""
echo "GDAX tool is built. To see, e.g., your BTC position:"
echo ""
echo "$ ./gdax btc"
echo ""
