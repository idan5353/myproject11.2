#!/bin/bash
echo "Running BeforeInstall hook..."

# Stop the web server if it's running
if systemctl is-active --quiet httpd; then
  echo "Stopping httpd..."
  systemctl stop httpd
else
  echo "httpd is not running."
fi
