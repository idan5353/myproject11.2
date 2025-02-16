#!/bin/bash
set -e  # Exit on error
yum update -y
yum install -y httpd
sudo rm -rf /var/www/html/*
sudo mkdir -p /var/www/html
echo "BeforeInstall: Installed httpd successfully" | tee -a /tmp/deploy.log
