#!/bin/bash
echo "Running BeforeInstall hook..."

# Stop the web server if it's running
if systemctl is-active --quiet httpd; then
  echo "Stopping httpd..."
  systemctl stop httpd
else
  echo "httpd is not running."
fi

# Remove existing index.html to avoid conflicts during deployment
if [ -f "/var/www/html/index.html" ]; then
  echo "Removing existing index.html..."
  rm -f /var/www/html/index.html
else
  echo "index.html does not exist."
fi