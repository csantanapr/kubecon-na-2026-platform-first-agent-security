#!/usr/bin/env bash
# Build the whole stack on a local kind cluster:
#   kind (Kubernetes 1.37) -> Agent Substrate + kagent 1.0 (kagent install) -> kro 0.10 (Graph on)
#   -> the platform team's kro Graph and ResourceGraphDefinition.
#
# Needs: docker, kind v0.33+, kubectl, curl. Helm 3 and the kagent CLI are
# downloaded into .work/bin if missing. About 8 GB of free memory.
# Optional: export OPENAI_API_KEY to chat with the agent. Without it, every
# resource still deploys and the sandbox egress demo still runs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/.work"
mkdir -p "$WORK/bin"
export PATH="$WORK/bin:$PATH"
export KUBECONFIG="$WORK/kubeconfig"   # never touches your ~/.kube/config

CLUSTER=kro-agents
# kind v0.33.0 default node image: Kubernetes 1.37.0.
# Learn more: https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0
NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
KAGENT_VERSION=1.0.1
KRO_VERSION=0.10.0
HELM3_VERSION=v3.22.1

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

for tool in docker kind kubectl curl; do
  command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done

# The kagent 1.0.1 installer parses `helm template` output. Helm 4 prints
# "Pulled:" lines on stdout for OCI charts, which breaks that parse, so this
# demo uses Helm 3.
if ! helm version --short 2>/dev/null | grep -q '^v3\.'; then
  step "Downloading Helm $HELM3_VERSION into .work/bin"
  tgz="$WORK/helm.tgz"
  curl -fsSL -o "$tgz" "https://get.helm.sh/helm-$HELM3_VERSION-linux-amd64.tar.gz"
  echo "$(curl -fsSL "https://get.helm.sh/helm-$HELM3_VERSION-linux-amd64.tar.gz.sha256sum" | awk '{print $1}')  $tgz" | sha256sum -c -
  tar -xzf "$tgz" -C "$WORK" linux-amd64/helm && mv "$WORK/linux-amd64/helm" "$WORK/bin/helm"
  rm -rf "$tgz" "$WORK/linux-amd64"
fi

if ! kagent version 2>/dev/null | grep -q "\"kagent_version\":\"$KAGENT_VERSION\""; then
  step "Downloading the kagent $KAGENT_VERSION CLI into .work/bin"
  os=$(uname -s | tr '[:upper:]' '[:lower:]'); arch=$(uname -m); [ "$arch" = x86_64 ] && arch=amd64; [ "$arch" = aarch64 ] && arch=arm64
  base="https://github.com/kagent-dev/kagent/releases/download/v$KAGENT_VERSION/kagent-$os-$arch"
  curl -fsSL -o "$WORK/bin/kagent" "$base"
  echo "$(curl -fsSL "$base.sha256" | awk '{print $1}')  $WORK/bin/kagent" | sha256sum -c -
  chmod +x "$WORK/bin/kagent"
fi

step "Creating kind cluster $CLUSTER (Kubernetes 1.37)"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind export kubeconfig --name "$CLUSTER" --kubeconfig "$KUBECONFIG"
else
  kind create cluster --config "$HERE/kind-config.yaml" --image "$NODE_IMAGE" --kubeconfig "$KUBECONFIG" --wait 180s
fi
kubectl get nodes

step "Installing Agent Substrate + kagent $KAGENT_VERSION (kagent install)"
# kagent install deploys Substrate (gVisor workers), PostgreSQL, the Pod
# Certificate controller and kagent itself.
export OPENAI_API_KEY="${OPENAI_API_KEY:-sk-placeholder-set-a-real-key-to-chat}"
kagent --config "$HERE/kagent/kagent-cli-config.yaml" install --provider OpenAI --timeout 20m

step "Installing kro $KRO_VERSION with the Graph API turned on"
# rbac.mode=aggregation: kro starts with almost no access; platform/00-kro-rbac.yaml
# grants exactly the kinds it composes.
helm upgrade --install kro oci://registry.k8s.io/kro/charts/kro --version "$KRO_VERSION" \
  --namespace kro-system --create-namespace \
  --set rbac.mode=aggregation \
  --set config.featureGates.GraphKind=true \
  --wait --timeout 5m

step "Applying the platform team's kro Graph and ResourceGraphDefinition"
kubectl apply -f "$HERE/platform/00-kro-rbac.yaml"
kubectl apply -f "$HERE/platform/10-tenant-graph.yaml"
kubectl apply -f "$HERE/platform/20-agentworkload-rgd.yaml"
kubectl wait --for=condition=Ready graph/agent-tenants -n kro-system --timeout=180s
kubectl wait --for=condition=Ready rgd/agentworkload --timeout=180s
kubectl get graph -n kro-system
kubectl get rgd

step "Done. Next: ./run.sh"
echo "Use this cluster from your shell with: export KUBECONFIG=$KUBECONFIG"
