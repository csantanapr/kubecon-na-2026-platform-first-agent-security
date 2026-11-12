#!/usr/bin/env bash
# The live demo: kro on top of kagent, kagent on top of Agent Substrate.
# Run ./install.sh first. Press Enter between steps (DEMO_AUTO=1 to run straight through).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HERE/.work/bin:$PATH"
export KUBECONFIG="$HERE/.work/kubeconfig"
NS=team-a

step()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
show()  { printf '\033[1;33m$ %s\033[0m\n' "$*"; eval "$@"; }
pause() { [ "${DEMO_AUTO:-0}" = 1 ] || read -r -p "  [Enter] " _; }

step "1. The platform team's half: one Graph, one ResourceGraphDefinition"
show kubectl get graph -n kro-system
show kubectl get rgd
pause

step "2. A team asks for an agent tenant with one label"
show cat "$HERE/tenant/team-a.yaml"
show kubectl apply -f "$HERE/tenant/team-a.yaml"
echo "  The Graph sees the label and gives the namespace a sandboxed runtime..."
for _ in $(seq 1 30); do
  kubectl get harness secure-default -n "$NS" >/dev/null 2>&1 && break; sleep 2
done
kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 workerpool/agents -n "$NS" --timeout=180s >/dev/null
show kubectl get serviceaccount/agent-workers workerpool/agents harness/secure-default resourcequota/agent-limits -n "$NS"
pause

step "3. The developer's half: one object in Git"
show cat "$HERE/tenant/support-agent.yaml"
show kubectl apply -f "$HERE/tenant/support-agent.yaml"
echo "  kro composes the kagent objects; kagent compiles the agent into a Substrate Actor..."
kubectl wait --for=jsonpath='{.status.ready}'=true agentworkload/support-agent -n "$NS" --timeout=300s
show kubectl get agentworkload,agents.api.kagent.dev,agenttemplate,egresspolicy,sandboxtemplate -n "$NS"
show "kubectl get agents.api.kagent.dev support-agent -n $NS -o jsonpath='{range .status.conditions[*]}{.type}={.status}  {.message}{\"\n\"}{end}'"
pause

step "4. Default deny, explicit allow, enforced by Agent Substrate"
kubectl wait --for=condition=Ready sandboxtemplate/support-agent-tools -n "$NS" --timeout=300s >/dev/null
kubectl port-forward -n kagent svc/kagent-controller 8083:8083 >"$HERE/.work/port-forward.log" 2>&1 &
PF=$!
trap 'kill "$PF" 2>/dev/null || true' EXIT
sleep 3
ID=$(kagent sandbox create support-agent-tools -n "$NS" --request-id "demo-$(date +%s)" --ttl 30m -o json \
     | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' | head -1)
echo "  sandbox: $ID"
show "kagent sandbox exec $ID -n $NS -- uname -sr"
show "kagent sandbox exec $ID -n $NS -- curl -sS -o /dev/null -w 'api.github.com -> HTTP %{http_code}\n' --max-time 15 https://api.github.com/zen"
show "kagent sandbox exec $ID -n $NS -- curl -sS -o /dev/null -w 'example.com -> HTTP %{http_code}\n' --max-time 15 https://example.com || true"
pause

step "5. No label, no agent: a namespace the platform never onboarded"
show kubectl create namespace team-b --dry-run=client -o yaml \| kubectl apply -f -
sed 's/namespace: team-a/namespace: team-b/' "$HERE/tenant/support-agent.yaml" | kubectl apply -f -
sleep 10
show "kubectl get agents.api.kagent.dev support-agent -n team-b -o jsonpath='{range .status.conditions[*]}{.type}={.status}  {.message}{\"\n\"}{end}'"
pause

step "Cleaning up the demo objects (the platform stays)"
kagent sandbox delete "$ID" -n "$NS" >/dev/null 2>&1 || true
kubectl delete agentworkload support-agent -n team-b --ignore-not-found --wait=false >/dev/null
kubectl delete namespace team-b --ignore-not-found --wait=false >/dev/null
echo "Re-run any time. Tear everything down with ./clean.sh"
