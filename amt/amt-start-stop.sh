#!/bin/bash

# Switches on all nodes by default
# Command
#  $0 powerdown
# switches all off.

ACTION=${1:-powerup}
export AMT_PASSWORD=Password1+

for i in $(seq 1 9); do
  IP=10.20.0.24$i
  echo "Sending command $ACTION to $IP"
  echo y | amttool $IP $ACTION
  echo =====================================
  echo "Hit Enter to continue"
  read 
done
