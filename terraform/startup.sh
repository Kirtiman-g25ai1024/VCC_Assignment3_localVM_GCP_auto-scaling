#!/bin/bash
# startup.sh — Runs on the GCE instance at first boot

set -e

apt-get update
apt-get install -y docker.io docker-compose git

systemctl enable docker && systemctl start docker

git clone https://github.com/<your-repo>/autoscale-demo.git /opt/app

cd /opt/app && docker-compose up -d

echo 'Cloud VM ready' > /tmp/deploy_status
