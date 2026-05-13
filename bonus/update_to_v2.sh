#!/bin/bash
set -e

export KUBECONFIG=/home/bel-idri/.kube/config

rm -rf /tmp/bel-idri-gitlab-update
git clone http://root:glpat-IoTBonusToken1234567890@gitlab.gitlab.svc.cluster.local:8929/root/bel-idri.git /tmp/bel-idri-gitlab-update
cd /tmp/bel-idri-gitlab-update

sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' deployment.yaml

git config user.email "root@example.com"
git config user.name "root"
git add deployment.yaml
git commit -m "switch app to v2" || true
git push

kubectl -n argocd annotate application my-app argocd.argoproj.io/refresh=hard --overwrite || true
kubectl rollout status deployment/bel-idri-app -n dev --timeout=300s

curl http://app.127.0.0.1.nip.io
