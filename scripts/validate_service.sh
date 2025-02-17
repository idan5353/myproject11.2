#!/bin/bash
echo "Running ValidateService hook..."

# Check if the web server is running
if systemctl is-active --quiet httpd; then
  echo "Web server is running."
else
  echo "Web server is not running."
  exit 1
fi

# Verify that index.html is accessible
curl -s http://localhost/index.html > /dev/null
if [ $? -eq 0 ]; then
  echo "index.html is accessible."
  exit 0
else
  echo "Error: index.html is not accessible."
  exit 1
fi