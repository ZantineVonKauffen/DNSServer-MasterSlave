#!/bin/bash

sudo apt -y update
DEBIAN_FRONTEND=noninteractive sudo apt -y upgrade
sudo apt -y install bind9

cp /vagrant/named.conf.options /etc/bind

sudo systemctl restart bind9