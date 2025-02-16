#!/bin/bash
echo "Running ApplicationStart hook..."
# Start the web server
echo "Starting httpd..."
systemctl start httpd

# Verify that the web server started successfully
if systemctl is-active --quiet httpd; then
  echo "httpd started successfully."
else
  echo "Error: Failed to start httpd."
  exit 1
fi