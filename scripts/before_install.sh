#!/bin/bash
echo "Running BeforeInstall hook..."
# Stop the web server if it's running
systemctl stop httpd || true