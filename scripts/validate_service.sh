#!/bin/bash
set -e
systemctl status httpd | tee -a /tmp/deploy.log
sleep 10
if ! systemctl is-active --quiet httpd; then
    exit 1
fi