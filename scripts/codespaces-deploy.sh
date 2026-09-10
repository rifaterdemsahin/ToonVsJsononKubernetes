#!/usr/bin/env bash
# Bootstraps minikube inside a GitHub Codespace / devcontainer and deploys the
# TOON vs JSON demo page to it. Runs automatically via postCreateCommand, or
# invoke manually with: bash scripts/codespaces-deploy.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Starting minikube (docker driver, running as root in Codespaces)"
minikube start --driver=docker --force

echo "==> Building the image inside minikube's docker daemon"
eval "$(minikube docker-env)"
docker build -t toon-vs-json:latest .

echo "==> Applying Kubernetes manifests"
kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl rollout status deployment/toon-vs-json --timeout=120s

echo "==> Exposing the service on localhost:8080 (Codespaces auto-forwards this port)"
pkill -f "kubectl port-forward svc/toon-vs-json" 2>/dev/null || true
nohup kubectl port-forward --address 0.0.0.0 svc/toon-vs-json 8080:80 > /tmp/toon-vs-json-portforward.log 2>&1 &
disown
sleep 2

echo "==> Done. Open the forwarded 8080 port in the Codespaces 'Ports' tab,"
echo "    or run: gh codespace ports visibility 8080:public -c \$CODESPACE_NAME"
