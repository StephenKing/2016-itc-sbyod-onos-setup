#!/usr/bin/env bash
set -e

echo "Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y nginx git

sudo git clone https://github.com/lsinfo3/2016-itc-sbyod-example-application /var/www/bi
sudo sed -i -e 's_/usr/share/nginx/html_/var/www/bi_' /etc/nginx/sites-available/default
sudo service nginx reload