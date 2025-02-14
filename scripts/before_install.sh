#!/bin/bash
set -e  # Exit on error
yum update -y
yum install -y httpd
echo "BeforeInstall: Installed httpd successfully" | tee -a /tmp/deploy.log
