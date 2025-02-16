#!/bin/bash
echo "Running AfterInstall hook..."

# Ensure the web directory exists
if [ ! -d "/var/www/html" ]; then
  echo "Error: /var/www/html does not exist."
  exit 1
fi

# Set permissions for the web directory
echo "Setting permissions for /var/www/html..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

echo "Permissions set successfully."
