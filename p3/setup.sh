#!/bin/bash

echo "=== Installing K3d ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | USE_SUDO=false K3D_INSTALL_DIR=$HOME/.local/bin bash

echo "=== Adding to PATH ==="
export PATH=$PATH:$HOME/.local/bin

echo "=== Installing kubectl for macOS ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
mkdir -p ~/.local/bin
mv kubectl ~/.local/bin/

echo "=== Installing Argo CD CLI for macOS ==="
curl -sSL -o ~/.local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
chmod +x ~/.local/bin/argocd

echo "=== Creating K3d cluster ==="
k3d cluster delete mycluster 2>/dev/null
k3d cluster create mycluster \
  --servers 1 \
  --agents 1 \
  -p "8443:443@loadbalancer"

echo "=== Waiting for cluster ==="
sleep 10


echo "=== Verifying cluster ==="
kubectl get nodes

echo "=== Creating namespaces ==="
kubectl create namespace argocd
kubectl create namespace dev

echo "=== Installing Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Waiting for Argo CD to be ready ==="
sleep 60
kubectl wait --for=condition=ready pod --all -n argocd --timeout=180s 2>/dev/null || echo "Pods starting, continue anyway..."

echo "=== Getting Argo CD password ==="
echo "Argo CD Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "=== Port forwarding Argo CD ==="
kubectl port-forward -n argocd svc/argocd-server 8443:443 &
