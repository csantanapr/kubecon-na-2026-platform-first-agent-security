#!/usr/bin/env bash
# Demo: default deny, explicit allow. Mirrors the talk's network demo.
# kind's default CNI (kindnet) does NOT enforce NetworkPolicy, so this
# script installs Calico first. Takes a few minutes on first run.
set -euo pipefail
cd "$(dirname "$0")"

kubectl apply -f namespace.yaml
kubectl apply -f api.yaml
kubectl apply -f agent.yaml
kubectl wait --for=condition=Ready pod/api-allowed -n agent-demo --timeout=180s
kubectl wait --for=condition=Ready pod/agent -n agent-demo --timeout=180s

echo "--- install Calico (kindnet does not enforce NetworkPolicy) ---"
kubectl apply -f https://docs.tigera.io/calico/latest/manifests/calico.yaml
kubectl wait --for=condition=Ready pod -l k8s-app=calico-node -n calico-system --timeout=300s
sleep 15  # let Calico program the rules

echo "--- BEFORE the policy: agent reaches the API ---"
kubectl exec -n agent-demo agent -- curl -s -m 5 http://api-allowed/

echo "--- apply the default-deny egress policy ---"
kubectl apply -f networkpolicy.yaml
sleep 10  # let the policy propagate

echo "--- AFTER: the allowed API still answers 200 ---"
kubectl exec -n agent-demo agent -- curl -s -m 5 http://api-allowed/

echo "--- AFTER: everything else is denied (expect a timeout) ---"
if kubectl exec -n agent-demo agent -- curl -s -m 8 http://example.com; then
  echo "UNEXPECTED: external egress still allowed"
else
  echo "DENIED (curl timed out): default deny is working"
fi
