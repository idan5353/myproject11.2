#!/bin/bash
set -e
chmod -R 755 /var/www/html
echo "AfterInstall: Set permissions successfully" | tee -a /tmp/deploy.log
