#!/bin/bash

echo "🚀 Setting up K3s for Part 2..."

sudo apt-get update -y
sudo apt-get install -y curl

curl -sfL https://get.k3s.io | sh -

sleep 30

sudo chmod 644 /etc/rancher/k3s/k3s.yaml

echo "alias k='kubectl'" >> /home/vagrant/.bashrc

sudo k3s kubectl apply -f /vagrant/apps.yaml

sleep 15

sudo k3s kubectl wait --for=condition=available --timeout=60s deployment --all

sudo k3s kubectl apply -f /vagrant/ingress.yaml
