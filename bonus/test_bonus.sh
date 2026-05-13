#!/bin/bash
set -e

export KUBECONFIG=/home/bel-idri/.kube/config

echo "=== Namespaces ==="
kubectl get ns

echo "=== GitLab service inside Kubernetes ==="
kubectl get svc -n gitlab

echo "=== Argo CD application ==="
kubectl get application -n argocd my-app

echo "=== Dev pods ==="
kubectl get pods -n dev -o wide

echo "=== Current image ==="
kubectl get deployment bel-idri-app -n dev -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

echo "=== App response ==="
curl http://app.127.0.0.1.nip.io
