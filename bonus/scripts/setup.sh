#!/bin/bash
set -euo pipefail


USER="${SUDO_USER:-abel-hid}"
CLUSTER_NAME="mycluster"

GITLAB_HOST="gitlab.localhost"
GITLAB_PORT="8081"


VALUES_FILE="/home/abel-hid/Desktop/IoT-1/bonus/confs/values.yaml"
APP_FILE="/home/abel-hid/Desktop/IoT-1/bonus/confs/app.yaml"
KUBECONFIG_FILE="/home/$USER/.kube/config"



wait_for_argocd() {
  echo "=== Waiting for Argo CD server ==="

  ARGO_DEPLOY="$(kubectl -n argocd get deploy -o name | grep -E 'argocd-server|argo-cd-argocd-server' | head -n 1 || true)"

  if [ -z "$ARGO_DEPLOY" ]; then
    echo "ERROR: Could not find Argo CD server deployment."
    kubectl get deploy -n argocd
    exit 1
  fi

  kubectl -n argocd rollout status "$ARGO_DEPLOY" --timeout=600s
}

wait_for_gitlab() {
  echo "=== Waiting for GitLab migrations job ==="

  MIGRATION_JOB=""
  for i in {1..60}; do
    MIGRATION_JOB="$(kubectl -n gitlab get jobs -o name 2>/dev/null | grep 'gitlab-migrations' | tail -n 1 || true)"

    if [ -n "$MIGRATION_JOB" ]; then
      break
    fi

    echo "Waiting for GitLab migrations job..."
    sleep 10
  done

  if [ -z "$MIGRATION_JOB" ]; then
    echo "ERROR: GitLab migrations job was not found."
    kubectl get pods -n gitlab
    kubectl get jobs -n gitlab
    exit 1
  fi

  kubectl -n gitlab wait --for=condition=complete "$MIGRATION_JOB" --timeout=1800s

}

check_gitlab_installed() {
  echo "=== Checking if GitLab is already installed ==="
  
  if kubectl get namespace gitlab >/dev/null 2>&1; then
    GITLAB_PODS=$(kubectl -n gitlab get pods --no-headers 2>/dev/null | grep -c "Running" || true)
    if [ "$GITLAB_PODS" -gt 0 ]; then
      echo "GitLab appears to be already installed with $GITLAB_PODS running pods."
      
      if kubectl -n gitlab get secret gitlab-gitlab-initial-root-password >/dev/null 2>&1; then
        GITLAB_PASSWORD="$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d)"
        echo "Retrieved existing GitLab root password."
      fi
      
      return 0
    fi
  fi
  
  return 1
}


echo "=== Installing dependencies ==="
apt-get update -y
apt-get install -y curl ca-certificates git vim

echo "=== Installing Docker ==="
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  chmod +x get-docker.sh
  sh get-docker.sh
  rm -f get-docker.sh
else
  echo "Docker already installed, skipping..."
fi

systemctl enable docker
systemctl start docker
usermod -aG docker "$USER" || true

echo "=== Installing K3d ==="
if ! command -v k3d >/dev/null 2>&1; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "K3d already installed, skipping..."
fi

echo "=== Installing kubectl ==="
if ! command -v kubectl >/dev/null 2>&1; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
else
  echo "kubectl already installed, skipping..."
fi

echo "=== Installing Helm ==="
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "Helm already installed, skipping..."
fi

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
  echo "=== Cluster $CLUSTER_NAME already exists, using existing cluster ==="
  
  mkdir -p "/home/$USER/.kube"
  k3d kubeconfig get "$CLUSTER_NAME" > "$KUBECONFIG_FILE"
  chown -R "$USER:$USER" "/home/$USER/.kube"
  chmod 600 "$KUBECONFIG_FILE"
  
  export KUBECONFIG="$KUBECONFIG_FILE"
  
  grep -q "KUBECONFIG" "/home/$USER/.bashrc" || \
    echo 'export KUBECONFIG="$HOME/.kube/config"' >> "/home/$USER/.bashrc"
  
  chown "$USER:$USER" "/home/$USER/.bashrc"
  
  echo "=== Waiting for Kubernetes nodes ==="
  kubectl wait --for=condition=Ready nodes --all --timeout=300s
else
  echo "=== Deleting old K3d cluster if exists ==="
  k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true

  echo "=== Creating K3d cluster ==="
  k3d cluster create "$CLUSTER_NAME" \
    --servers 1 \
    --agents 1 \
    --api-port 6550 \
    --k3s-arg "--disable=traefik@server:0" \
    --port "$GITLAB_PORT:80@loadbalancer" \
    --wait

  echo "=== Configuring kubeconfig for user: $USER ==="
  mkdir -p "/home/$USER/.kube"
  k3d kubeconfig get "$CLUSTER_NAME" > "$KUBECONFIG_FILE"
  chown -R "$USER:$USER" "/home/$USER/.kube"
  chmod 600 "$KUBECONFIG_FILE"

  export KUBECONFIG="$KUBECONFIG_FILE"

  grep -q "KUBECONFIG" "/home/$USER/.bashrc" || \
    echo 'export KUBECONFIG="$HOME/.kube/config"' >> "/home/$USER/.bashrc"

  chown "$USER:$USER" "/home/$USER/.bashrc"

  echo "=== Waiting for Kubernetes nodes ==="
  kubectl wait --for=condition=Ready nodes --all --timeout=300s
fi

echo "=== Adding local hosts entry for GitLab ==="
grep -q "$GITLAB_HOST" /etc/hosts || echo "127.0.0.1 $GITLAB_HOST" >> /etc/hosts

echo "=== Adding Helm repositories ==="
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

echo "=== Installing Argo CD ==="
if kubectl get namespace argocd >/dev/null 2>&1; then
  echo "Argo CD namespace already exists, checking installation..."
  ARGO_PODS=$(kubectl -n argocd get pods --no-headers 2>/dev/null | grep -c "Running" || true)
  if [ "$ARGO_PODS" -gt 0 ]; then
    echo "Argo CD appears to be already installed with $ARGO_PODS running pods."
  else
    echo "Argo CD namespace exists but no running pods, reinstalling..."
    helm upgrade --install argocd argo/argo-cd \
      -n argocd \
      --create-namespace \
      --set server.ingress.enabled=false \
      --set dex.enabled=false \
      --set notifications.enabled=false \
      --timeout 10m
  fi
else
  echo "Installing Argo CD..."
  helm upgrade --install argocd argo/argo-cd \
    -n argocd \
    --create-namespace \
    --set server.ingress.enabled=false \
    --set dex.enabled=false \
    --set notifications.enabled=false \
    --timeout 10m
fi

wait_for_argocd

if check_gitlab_installed; then
  echo "=== GitLab is already installed, skipping installation ==="
  echo "To reinstall GitLab, first delete the namespace: kubectl delete namespace gitlab"
else
  echo "=== Installing GitLab ==="
  helm upgrade --install gitlab gitlab/gitlab \
    -n gitlab \
    --create-namespace \
    -f "$VALUES_FILE" \
    --timeout 30m \
    --version 9.10.1 \
    --set gitlab.webservice.minReplicas=1 \
    --set gitlab.webservice.maxReplicas=1 \
    --set gitlab.sidekiq.minReplicas=1 \
    --set gitlab.sidekiq.maxReplicas=1 \
    --set gitlab.gitlab-shell.minReplicas=1 \
    --set gitlab.gitlab-shell.maxReplicas=1 \
    --set gitlab.kas.minReplicas=1 \
    --set gitlab.kas.maxReplicas=1 \
    --set gitlab-runner.install=false

  wait_for_gitlab
  
  echo "=== Getting GitLab root password ==="
  GITLAB_PASSWORD="$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d)"
fi

echo "=== Applying Argo CD application ==="
kubectl apply -f "$APP_FILE"

echo "=== Getting Argo CD admin password ==="
ARGO_PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

echo "=== Final GitLab test ==="
curl -I -H "Host: $GITLAB_HOST" "http://127.0.0.1:$GITLAB_PORT/users/sign_in"

echo "====================================="
echo "SETUP FINISHED"
echo "====================================="
echo ""
echo "GitLab:"
echo "URL:      http://$GITLAB_HOST:$GITLAB_PORT"
echo "Username: root"
echo "Password: $GITLAB_PASSWORD"
echo ""
echo "Argo CD:"
echo "Start it manually with:"
echo "kubectl -n argocd port-forward svc/argocd-server 9090:443"
echo ""
echo "Then open:"
echo "http://localhost:9090/applications/argocd/my-app?view=tree&resource="
echo ""
echo "Username: admin"
echo "Password: $ARGO_PASSWORD"
echo ""
if ! check_gitlab_installed 2>/dev/null; then
  echo "Next manual steps:"
  echo "1. Open GitLab."
  echo "2. Create a blank project named: $PROJECT_NAME"
  echo "3. Push your bonus folder to:"
  echo "   http://$GITLAB_HOST:$GITLAB_PORT/root/$PROJECT_NAME.git"
  echo ""
fi
echo "After push, Argo CD will sync the app."
echo "====================================="
