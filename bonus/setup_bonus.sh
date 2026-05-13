#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BONUS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root. Example: sudo bash bonus/scripts/setup_bonus.sh"
  exit 1
fi

echo "=== Preparing local DNS names ==="
grep -q "gitlab.gitlab.svc.cluster.local" /etc/hosts || echo "127.0.0.1 gitlab.gitlab.svc.cluster.local host.k3d.internal" >> /etc/hosts

echo "=== Installing dependencies ==="
apt-get update -y
apt-get install -y curl git ca-certificates jq

if ! command -v docker >/dev/null 2>&1; then
  echo "=== Installing Docker ==="
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
fi
systemctl enable docker
systemctl start docker

if ! command -v k3d >/dev/null 2>&1; then
  echo "=== Installing K3d ==="
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "=== Installing kubectl ==="
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

echo "=== Creating K3d cluster ==="
k3d cluster delete mycluster 2>/dev/null || true
k3d cluster create mycluster \
  --servers 1 \
  --agents 1 \
  --api-port 6550 \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --wait

echo "=== Configuring kubeconfig for user: bel-idri ==="
mkdir -p /home/bel-idri/.kube
k3d kubeconfig get mycluster > /home/bel-idri/.kube/config
chown -R bel-idri:bel-idri /home/bel-idri/.kube
chmod 600 /home/bel-idri/.kube/config
export KUBECONFIG=/home/bel-idri/.kube/config

echo "=== Creating namespaces ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$BONUS_DIR/confs/gitlab-service.yaml"

echo "=== Installing Argo CD ==="
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Waiting for Argo CD ==="
kubectl wait --for=condition=ready pod --all -n argocd --timeout=600s

echo "=== Starting local GitLab CE ==="
docker rm -f gitlab 2>/dev/null || true
rm -rf /srv/gitlab
mkdir -p /srv/gitlab/config /srv/gitlab/logs /srv/gitlab/data

docker run --detach \
  --hostname gitlab.gitlab.svc.cluster.local \
  --publish 8929:8929 \
  --publish 2222:22 \
  --name gitlab \
  --restart always \
  --shm-size 256m \
  --env GITLAB_ROOT_PASSWORD="RootPassword42!" \
  --env GITLAB_OMNIBUS_CONFIG="external_url 'http://gitlab.gitlab.svc.cluster.local:8929'; gitlab_rails['gitlab_shell_ssh_port'] = 2222;" \
  --volume /srv/gitlab/config:/etc/gitlab \
  --volume /srv/gitlab/logs:/var/log/gitlab \
  --volume /srv/gitlab/data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest

echo "=== Waiting for GitLab. This can take 5 to 10 minutes ==="
for i in $(seq 1 120); do
  if curl -fsS http://gitlab.gitlab.svc.cluster.local:8929/users/sign_in >/dev/null 2>&1; then
    echo "GitLab HTTP is ready"
    break
  fi
  echo "Waiting for GitLab... $i/120"
  sleep 5
  if [ "$i" = "120" ]; then
    echo "GitLab did not become ready in time. Check: docker logs -f gitlab"
    exit 1
  fi
done

for i in $(seq 1 60); do
  if docker exec gitlab gitlab-rails runner "puts 'rails-ready'" >/dev/null 2>&1; then
    echo "GitLab Rails is ready"
    break
  fi
  echo "Waiting for GitLab Rails... $i/60"
  sleep 10
  if [ "$i" = "60" ]; then
    echo "GitLab Rails did not become ready in time. Check: docker logs -f gitlab"
    exit 1
  fi
done

echo "=== Creating GitLab token ==="
docker exec gitlab gitlab-rails runner "user = User.find_by_username('root'); old = user.personal_access_tokens.find_by(name: 'iot-bonus-token'); old.revoke! if old && !old.revoked?; token = user.personal_access_tokens.create(scopes: ['api','read_repository','write_repository'], name: 'iot-bonus-token', expires_at: 365.days.from_now); token.set_token('glpat-IoTBonusToken1234567890'); token.save!"

echo "=== Creating public project in local GitLab ==="
curl -fsS --request POST \
  --header "PRIVATE-TOKEN: glpat-IoTBonusToken1234567890" \
  --data "name=bel-idri" \
  --data "path=bel-idri" \
  --data "visibility=public" \
  "http://gitlab.gitlab.svc.cluster.local:8929/api/v4/projects" >/dev/null

echo "=== Pushing Kubernetes manifests to local GitLab ==="
rm -rf /tmp/bel-idri-gitlab
mkdir -p /tmp/bel-idri-gitlab
cp "$BONUS_DIR/confs/dev-app.yaml" /tmp/bel-idri-gitlab/deployment.yaml
cd /tmp/bel-idri-gitlab
git init
git config user.email "root@example.com"
git config user.name "root"
git add deployment.yaml
git commit -m "deploy v1"
git branch -M main
git remote add origin "http://root:glpat-IoTBonusToken1234567890@gitlab.gitlab.svc.cluster.local:8929/root/bel-idri.git"
git push -u origin main --force

echo "=== Creating Argo CD Application from local GitLab ==="
kubectl apply -f "$BONUS_DIR/confs/application.yaml"

echo "=== Waiting for application deployment ==="
sleep 20
kubectl rollout status deployment/bel-idri-app -n dev --timeout=300s

echo "=== Argo CD admin password ==="
echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "=== DONE ==="
echo "GitLab URL:  http://gitlab.gitlab.svc.cluster.local:8929"
echo "GitLab user: root"
echo "GitLab pass: RootPassword42!"
echo "GitLab repo: http://gitlab.gitlab.svc.cluster.local:8929/root/bel-idri"
echo "App URL:     http://app.127.0.0.1.nip.io"
echo "Test app:    curl http://app.127.0.0.1.nip.io"
echo "Argo UI:     kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "Then open:   https://localhost:8080"
