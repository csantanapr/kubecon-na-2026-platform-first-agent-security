# What runs where - read this before the laptop agent starts

The talk's four demos have very different needs. This is the honest map.

## Runs on stock kind (with one extra install)

**NetworkPolicy deny/allow** (`demo-network-policy/`): fully feasible. kind's
default CNI (kindnet) does not enforce NetworkPolicy, so the demo's `run.sh`
installs Calico first, then shows the deny/allow behavior. This is the one
demo the laptop agent can run end to end today.

## Needs a capable cluster, not stock kind

**agent-sandbox warm pool + SandboxClaim** (`agent-sandbox/`): needs the
agent-sandbox controller installed AND a runtime that can actually isolate:
Kata (microVMs) or gVisor. Stock kind nodes run plain runc inside Docker;
there is no Kata or gVisor runtime to delegate to. Options for the laptop
agent: build a custom kind node image with Kata containers installed, or run
this demo on a real cluster (a small EC2/EKS test cluster works). The
manifests here are the shapes from the talk; the install pointer is in
`agent-sandbox/README.md`.

## Experimental, on or off cluster

**OpenShell credential brokering** (`openshell/`): OpenShell is a standalone
gateway binary (NVIDIA/OpenShell on GitHub), not a Kubernetes controller. The
talk's live demo runs the OpenShell binary locally on the laptop: the agent's
`env` is empty, the placeholder-header request returns 200, the gateway log
shows the injection. That local flow works on any machine with the binary.
The on-Kubernetes deployment shown in the talk's recorded beat is
experimental, which is why the talk keeps it on video. See `openshell/README.md`.

## The recorded fallbacks

Every demo slide in the deck has an embedded simulated fallback video
("No cluster? Play the simulated fallback."). Those videos are baked into
`slides/platform-first-agent-security.html` itself, so the talk survives a
dead cluster. The standalone mp4 files are excluded from this repo (see the
top-level README).
