#!/bin/bash
echo "Running ValidateService hook..."

# Check if the web server is running
if systemctl is-active --quiet httpd; then
  echo "Web server is running."
  exit 0
else
  echo "Web server is not running."
  exit 1
fi
