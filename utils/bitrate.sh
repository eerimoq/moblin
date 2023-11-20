#!/usr/bin/env bash

minimum=1.0

while true ; do
    speed=$(python3 -c "import random ; print(round(random.random()* 10 + ${minimum}, 1), end='')")
    date | tr -d "\n"
    echo " - ${speed} Mbit"
    sudo tc qdisc replace dev eno1 root netem rate ${speed}Mbit
    sleep 15
done
