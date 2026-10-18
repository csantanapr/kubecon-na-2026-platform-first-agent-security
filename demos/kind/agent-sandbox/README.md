# agent-sandbox on a laptop cluster - what the laptop agent needs to know
#
# NEEDS A CAPABLE CLUSTER. Stock kind cannot run this demo: there is no Kata
# or gVisor runtime on kind nodes to delegate to, so a SandboxClaim has
# nothing to bind to.
#
# Two paths:
# 1. Custom kind node image with Kata containers installed, then install the
#    agent-sandbox controller on top. Most work, closest to the talk.
# 2. A real cluster (small EKS test cluster is fine) with Kata or gVisor
#    available as a RuntimeClass, then install the controller.
#
# Install the controller (check for a newer release first):
#   kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/manifest.yaml
#
# Then apply the claim below against a pre-warmed pool and time it:
#   time kubectl apply -f sandboxclaim.yaml
# The talk's line: under a second, because the sandbox already exists.
# Contrast with a cold pod: image pull, runtime start, tens of seconds.

# Shape per agent-sandbox v1beta1 (warmPoolRef). Check your version's API.
apiVersion: extensions.agents.x-k8s.io/v1beta1
kind: SandboxClaim
metadata:
  name: agent-7
spec:
  warmPoolRef:
    name: agent-pool
