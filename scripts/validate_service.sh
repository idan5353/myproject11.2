#!/bin/bash
set -e
systemctl status httpd | tee -a /tmp/deploy.log
