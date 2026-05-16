#!/bin/bash
set -e

# =========================
# CONFIG
# =========================
TARGET_USER="${SUDO_USER:-$(whoami)}"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "====================================="
echo "FULL CLEANUP STARTED"
echo "Target user: $TARGET_USER"
echo "User home:   $USER_HOME"
echo "====================================="

# =========================
# DELETE ALL K3D CLUSTERS
# =========================
echo "=== Deleting all k3d clusters ==="

if command -v k3d >/dev/null 2>&1; then
  CLUSTERS="$(k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' || true)"

  if [ -n "$CLUSTERS" ]; then
    for cluster in $CLUSTERS; do
      echo "Deleting k3d cluster: $cluster"
      k3d cluster delete "$cluster" || true
    done
  else
    echo "No k3d clusters found"
  fi
else
  echo "k3d is not installed"
fi

# =========================
# DESTROY ALL VAGRANT VMS
# =========================
echo "=== Destroying all Vagrant VMs ==="

if command -v vagrant >/dev/null 2>&1; then
  VAGRANT_IDS="$(vagrant global-status --prune 2>/dev/null | awk 'NR>2 && $1 ~ /^[a-zA-Z0-9]+$/ {print $1}' || true)"

  if [ -n "$VAGRANT_IDS" ]; then
    for id in $VAGRANT_IDS; do
      echo "Destroying Vagrant VM: $id"
      vagrant destroy -f "$id" || true
    done
  else
    echo "No Vagrant VMs found"
  fi

  vagrant global-status --prune >/dev/null 2>&1 || true
else
  echo "Vagrant is not installed"
fi

# =========================
# REMOVE .vagrant FOLDERS FROM CURRENT PROJECT
# =========================
echo "=== Removing .vagrant folders from current directory ==="
find . -type d -name ".vagrant" -prune -exec rm -rf {} + 2>/dev/null || true

# =========================
# DELETE ALL DOCKER OBJECTS
# =========================
echo "=== Cleaning Docker completely ==="

if command -v docker >/dev/null 2>&1; then
  echo "=== Stopping all Docker containers ==="
  docker stop $(docker ps -aq) 2>/dev/null || true

  echo "=== Removing all Docker containers ==="
  docker rm -f $(docker ps -aq) 2>/dev/null || true

  echo "=== Removing all Docker images ==="
  docker rmi -f $(docker images -aq) 2>/dev/null || true

  echo "=== Removing all Docker volumes ==="
  docker volume rm -f $(docker volume ls -q) 2>/dev/null || true

  echo "=== Removing custom Docker networks ==="
  docker network rm $(docker network ls --format '{{.Name}}' | grep -v '^bridge$' | grep -v '^host$' | grep -v '^none$') 2>/dev/null || true

  echo "=== Cleaning Docker system ==="
  docker system prune -a --volumes -f || true

  echo "=== Cleaning Docker builder cache ==="
  docker builder prune -a -f || true
else
  echo "Docker is not installed"
fi

# =========================
# CLEAN KUBECONFIG
# =========================
echo "=== Removing kubeconfig ==="

if [ -n "$USER_HOME" ] && [ -d "$USER_HOME/.kube" ]; then
  rm -rf "$USER_HOME/.kube"
  echo "Removed $USER_HOME/.kube"
else
  echo "No kubeconfig folder found for $TARGET_USER"
fi

if [ -d "/root/.kube" ]; then
  rm -rf /root/.kube
  echo "Removed /root/.kube"
fi

# =========================
# CLEAN LOCAL HOSTS
# =========================
echo "=== Cleaning /etc/hosts entries ==="

if [ -f /etc/hosts ]; then
  sed -i.bak '/gitlab.localhost/d' /etc/hosts
  sed -i.bak '/argocd.localhost/d' /etc/hosts
  sed -i.bak '/gitlab.local/d' /etc/hosts
  sed -i.bak '/argocd.local/d' /etc/hosts
  echo "Cleaned /etc/hosts. Backup saved as /etc/hosts.bak"
fi

# =========================
# OPTIONAL: REMOVE TEMP FILES
# =========================
echo "=== Removing temporary files ==="
rm -f /tmp/argocd-port-forward.log
rm -f /tmp/gitlab-port-forward.log
rm -f get-docker.sh

# =========================
# FINAL STATUS
# =========================
echo "====================================="
echo "CLEANUP COMPLETED"
echo "====================================="

echo ""
echo "Docker status:"
docker ps -a 2>/dev/null || true

echo ""
echo "k3d clusters:"
k3d cluster list 2>/dev/null || true

echo ""
echo "Vagrant status:"
vagrant global-status --prune 2>/dev/null || true