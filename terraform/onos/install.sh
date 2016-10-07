#!/usr/bin/env bash
set -e

echo "Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io

sudo docker run -t -d --name onos -p 0.0.0.0:8181:8181 -p 0.0.0.0:6653:6653 onosproject/onos:1.6

echo "Installing Upstart service..."
sudo mv /tmp/upstart.conf /etc/init/onos-docker.conf
