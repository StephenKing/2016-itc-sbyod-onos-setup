#!/bin/bash

sudo apt-get update
sudo apt-get install -y git nginx curl
sudo curl https://install.meteor.com/ | sh
sudo git clone https://github.com/lsinfo3/2016-itc-sbyod-portal /opt/portal
sudo chmod +x /opt/portal/startup.sh
sudo meteor build /opt/portal


sudo cp /tmp/upstart-meteorjs.conf /etc/init/meteorjs.conf
sudo service meteorjs start

sudo cp /tmp/nginx-site.conf /etc/nginx/sites-available/portal
sudo ln -s /etc/nginx/sites-available/portal /etc/nginx/sites-enabled/

sudo mkdir /etc/nginx/ssl
# manually:
# /etc/nginx/ssl/cert.pem
# /etc/nginx/ssl/cert.key
