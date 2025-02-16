#!/bin/bash
echo "Running AfterInstall hook..."
# Set permissions for the web directory
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html