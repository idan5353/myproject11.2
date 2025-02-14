#!/bin/bash
set -e
systemctl start httpd
systemctl enable httpd
echo "ApplicationStart: HTTPD started successfully" | tee -a /tmp/deploy.log
