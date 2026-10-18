# Research: Platform-First AI Agent Security — Zero-Trust Patterns for Kubernetes

Talk: "Platform-First AI Agent Security: Zero-Trust Patterns for Kubernetes"
KubeCon + CloudNativeCon NA 2026, Security track, Thu Nov 12, 2026, 3:30–4:00 PM MST (30 min, solo).
Salt Palace, Level 2, 255 BC. Thesis: **agents are untrusted tenants**.

Research compiled Oct 4, 2026. Every load-bearing claim carries a source.
Alpha/experimental status is flagged honestly — this talk must not oversell.

---

## 1. kubernetes-sigs/agent-sandbox — upstream state

**What it is.** A SIG Apps subproject (announced at KubeCon NA 2025; repo created
Aug 2025) building a `Sandbox` CRD and controller: a declarative, standardized
API for isolated, stateful, singleton workloads — AI agent runtimes and RL.
It is explicitly a **sandbox orchestrator**, not an isolation primitive: it
delegates low-level isolation to "Sandbox Runtimes" (gVisor, Kata Containers)
by managing Pods configured via `RuntimeClass`.
Sources: https://github.com/kubernetes-sigs/agent-sandbox,
https://agent-sandbox.sigs.k8s.io

**APIs (v1beta1 as of v0.5.0, ~June 2026).** `Sandbox`, `SandboxClaim`,
`SandboxTemplate`, `SandboxWarmPool` graduated from `v1alpha1` to `v1beta1`
— a deliberate maturity milestone with conversion webhooks and etcd migration
utilities. Breaking changes in the graduation: `spec.replicas` replaced by
`spec.operatingMode` (`Running`/`Suspended`) for explicit suspend/resume;
`SandboxClaim` now uses `spec.warmPoolRef`; explicit `Suspended` condition in
Sandbox status.
Source: https://github.com/kubernetes-sigs/agent-sandbox/releases
(search "v0.5.0rc1": "API Graduation to v1beta1", "Sandbox Lifecycle Management")

**Install/shape.** Helm chart, Go + Python SDKs, optional Sandbox Router,
`extensions/` module with extra CRDs. 4,100+ stars, 25 releases.
Source: https://github.com/kubernetes-sigs/agent-sandbox

**Security posture (real, recent).**
- System-reserved Pod labels/annotations are protected from tenant overrides
  (prevents privilege escalation / sandbox hijacking) — #894, v0.5.0.
- Sandbox Router hardening: strict `sandbox_id` validation, optional bearer
  auth, NetworkPolicy scoping to `agent-sandbox-system`.
- Source: v0.5.0rc1 release notes, https://github.com/kubernetes-sigs/agent-sandbox/releases

**NetworkPolicy model (three layers, demo-relevant).**
1. The controller manages a standard K8s `NetworkPolicy` per `SandboxTemplate`
   (L3/L4). `spec.networkPolicyManagement: Managed` (default) vs `Unmanaged`
   (controller steps aside entirely — admin owns isolation via Cilium/Istio).
2. Cluster-wide defaults via the SIG Network **Network Policy API**
   `ClusterNetworkPolicy` (admin tier evaluated first, `Pass` delegates,
   Baseline tier for unselected pods) — the
   `examples/network-policy-api-sandbox` example shows default-deny plus FQDN
   allowlists (`domainNames`, experimental) using
   `kube-network-policies` (SIG Network reference impl, works with any CNI).
3. L7 (HTTP paths/headers, gVis
...[truncated 15640 chars]
## 2. OpenShell (NVIDIA) — deep dive

**What it is.** NVIDIA's open-source (Apache 2.0), agent-first runtime for
sandboxed AI agent execution. "The safe, private runtime for autonomous AI
agents" — sandboxed environments governed by declarative YAML policies that
prevent unauthorized file access, data exfiltration, and uncontrolled network
activity. Not an agent framework: it sits *under* the agent you already use
(Claude Code, Codex, OpenCode, Copilot CLI, Hermes, OpenClaw).
Design tagline: **"Security lives in the environment, not the model or the
application."**
Sources: https://github.com/NVIDIA/OpenShell,
https://www.eesel.ai/blog/nvidia-open-agent-safety-platform

**Status (Oct 2026).** v0.1.2 latest stable; project badge says **alpha**;
stable releases ship roughly weekly; 10.2k stars, 1.4k forks, 129
contributors. Part of NVIDIA's **Open Agent Safety Platform** (with Sentry, a
BlueField-4 DPU reference design that enforces policy in silicon; DOCA; Vera
CPU). NVIDIA reports 100+ organizations working with the platform technologies
(Anthropic, Cisco, CrowdStrike, Microsoft, Palantir, Salesforce, SAP,
Scale AI, ServiceNow — a mix of real integrations and logo placements).
Source: https://www.eesel.ai/blog/nvidia-open-agent-safety-platform,
https://github.com/NVIDIA/OpenShell/releases

**Motivating incident.** July 2026: OpenAI's internal cybersecurity evaluation
found models bypassing isolation controls, compromising research infra and
Hugging Face systems (SSRF to internet, reconstructed exposed HF credentials,
chained zero-days). OpenAI called it a "warning shot." NVIDIA's read: "a
combination of tools, time, and ambiguous instructions" — an agent in those
conditions "cannot be expected to fully govern its own behavior."
This is the talk's best 60-second opener for *why* the environment must hold
the trust boundary.
Source: https://www.eesel.ai/blog/nvidia-open-agent-safety-platform
(attribute the incident details to OpenAI's write-up / the eesel analysis;
verify before putting numbers on slides)

**Architecture: three trust levels.** Each sandbox splits into:
- **Supervisor** (outside the workload boundary): owns gateway credentials,
  admitted policy, L7 proxying, SSH, gateway relays. Never executes inside
  the agent workload.
- **Sandbox** (boundary): runs as the same non-root identity as the agent,
  installs the workload seccomp listener, applies the Landlock baseline, owns
  child processes, mediates the protected supervisor channel.
- **Agent child**: inherits the sandbox network listener; runs with **zero
  capabilities, `no_new_privs`, Landlock, and the final syscall filter**.
Neither trusted component nor agent child gets any Linux capability inside
the workload; one immutable non-root UID/GID for the whole generation.
Communication crosses a mutually authenticated gRPC channel (Unix socket,
K8s TCP Service, or VM vsock); DNS is mediated by the supervisor (general
app UDP unsupported).
Source: ~/workspace/research/agent-sandbox-primitives/openshell/architecture/sandbox.md

**Isolation layers (overlapping, not one primitive).** Landlock filesystem
policy; immutable non-root process identity; **seccomp notification broker**
that virtualizes INET sockets and sends DNS/TCP decisions to the supervisor
(no nftables, no proxy env vars the agent can unset); driver outer fence
(Docker `network_mode=none`, Podman paired containers, K8s NetworkPolicy).
"NetworkPolicy is an outer reachability fence, not a confidentiality
boundary" — each sandbox generation gets a fresh CA and distinct leaves.
Source: ~/workspace/research/agent-sandbox-primitives/openshell/architecture/sandbox.md

**Policy model (declarative YAML).** Five areas: filesystem (Landlock
read-only/read-write paths), process (unprivileged user, reduced
capabilities), network (proxy evaluates destination + port + **calling
binary** + optional L7 rules), provider access (credentials bound to
profile-authorized endpoints), runtime settings. Filesystem/process are
startup-time; **network policy hot-reloads** on successful validation.
Decision order: force traffic through proxy → identify calling binary →
reject hard-blocked destinations → match policy blocks → apply L7 rules →
allow/deny/audit/log. **Explicit deny wins over allow; no matching rule =
deny.**
Source: ~/workspace/research/agent-sandbox-primitives/openshell/architecture/security-policy.md

**Credential brokering.** The proxy can terminate TLS with the sandbox's
ephemeral CA and **inject credentials on terminated HTTP streams** when policy
allows; provider credentials are endpoint-bound, and policy changes rotate
credential bindings atomically. The agent never sees the real secret.
Source: ~/workspace/research/agent-sandbox-primitives/openshell/architecture/security-policy.md

**Compute drivers.** Docker, Podman (paired workload+supervisor containers,
workload on `network=none`), host virtualization for MicroVM-backed
sandboxes. **Kubernetes driver: EXPERIMENTAL** — Helm chart at
`oci://ghcr.io/nvidia/openshell/helm-chart`; **requires the
kubernetes-sigs/agent-sandbox CRDs + controller pre-installed**
(`kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/manifest.yaml`);
**the cluster CNI MUST enforce NetworkPolicy** for ingress and egress in
every sandbox namespace ("OpenShell creates the policies, but Kubernetes
does not verify that the CNI applies them"). Expect rough edges and breaking
changes.
Sources: https://github.com/NVIDIA/OpenShell (README "Kubernetes installation"),
~/workspace/research/agent-sandbox-primitives/openshell/deploy/helm/openshell/README.md

**Local demo path (stable).** `curl -LsSf .../install.sh | sh`, then
`openshell sandbox create -- claude` (or opencode/codex/copilot). Base image
bundles python 3.14, node 22, gh/git, and network tools.
Source: https://github.com/NVIDIA/OpenShell

**Demo implication.** OpenShell's *local* path is stage-safe and its policy
deny/audit log is extremely visual (every allow and deny is logged). Its
*Kubernetes* path is experimental — do not promise a K8s-native OpenShell
demo without rehearsing on the exact chart version.

---

## 3. Agent Substrate — state

**What it is.** A high-density, low-latency runtime for large-scale AI agent
deployments on Kubernetes. Control plane maps many **actors** (agents) onto
fewer pre-provisioned **worker** Pods, exploiting agent idleness for heavy
multiplexing; sub-second suspend/resume via snapshots. **CNCF Sandbox
application filed: https://github.com/cncf/sandbox/issues/523** (org:
https://github.com/agent-substrate/; transfer announcement expected around
KubeCon NA 2026 — community-tracked, confirm before announcing on stage).
Source: https://github.com/cncf/sandbox/issues/523

**Core components** (per the project's threat model, Jun 2026):
- **ate-api-server**: actor creation/scheduling, credential issuance.
- **atelet**: per-node daemon, snapshot/resume.
- **ateom**: per-worker-Pod sidecar; sets up "interior" sandboxes in the
  worker Pod, manages sandbox lifecycle. **Uses gVisor today; microVMs
  (Kata/Cloud Hypervisor) on the roadmap.**
- **Actor**: the compute primitive; `Run` for cold start, `Resume` for
  snapshot resume.
- **atenet-router**: Envoy with `ext_proc`; reads/validates the
  `ate-target-actor: <atespace>/<actor>` header, resumes the actor, routes
  with mTLS to `atunnel`, which authorizes the header against the actor
  assigned to that worker. Host/authority do NOT select the actor.
- **State**: PostgreSQL (control plane) + K8s CRDs (WorkerPool in etcd);
  object storage for snapshots.
Source: https://github.com/agent-substrate/substrate/blob/HEAD/docs/threat-model.md

**Security status — read carefully.** The threat model (Taufen, Kumar,
Mitrofanov, Jun 25 2026) states plainly: "Substrate is an early, fast moving
product... **it has little to no security hardening at this time**." The
document is a forward-looking threat analysis, not a description of shipped
controls. Roadmap items include **default-deny network isolation**, mTLS
everywhere, independent cryptographic actor identities, and A2A calling
policies.
Source: https://github.com/agent-substrate/substrate/blob/HEAD/docs/threat-model.md

**Egress credential injection (documented, current).** The egress gateway
terminates the actor's TLS for hostnames in its `EgressPolicy`, and when a
rule carries `replace_headers`, it resolves the named credential from a
**credential provider** (reference impl: `cmd/credential-provider/kubernetes-secrets`,
reading K8s Secrets; also Google Secret Manager) and swaps the actor's
placeholder header for the real value before the request leaves the cluster.
**The actor never holds the secret** — it sends `Authorization: placeholder`,
which the gateway discards; it cannot read, snapshot, or exfiltrate the
secret, nor choose the value that leaves. Per-atespace authorization (sample
policy: only `team-a` resolves the example credential; others get 403).
This is the single most demoable zero-trust primitive in the project.
Source: https://github.com/agent-substrate/substrate/blob/HEAD/docs/egress-credential-injection.md

**Fresh (Oct 2026, from main-branch commits).**
- OIDC discovery document for actor JWT signing keys in progress
  (follow-up: ate-idp-server).
- `podcertcontroller` integrated with **ClusterTrustBundles** — converges
  with Carlos's EKS 1.37 identity thesis (every pod a real X.509 identity).
- Resume latency work: gVisor actor ResumeActor P50 **430ms**, MicroVM
  **600ms** P50 (local checkpoint restore, no copy).
- Power-of-two-choices actor scheduling (community-tracked, early Oct 2026).
Source: https://github.com/agent-substrate/substrate/commits/main.atom

**Sandbox demo (exists, with a warning label).** `demos/sandbox`: stateful
sandbox actor (Alpine) + REPL client (`sandbox>` prompt, `ls`, `cat`,
suspend-on-exit via `kubectl ate`). **Security disclaimer in the README:
"not secured by any authorization checks... Do not deploy this configuration
in production or expose it to untrusted networks."**
`./hack/install-ate.sh --deploy-demo-sandbox`; `kubectl-ate` plugin;
needs a GCS bucket for snapshots.
Source: https://github.com/agent-substrate/substrate/blob/HEAD/demos/sandbox/README.md

**GKE.** "Agent Substrate available on GKE" (Google Cloud blog) — managed
path exists for the demo-averse.
Source: https://cloud.google.com/blog/products/containers-kubernetes/agent-substrate-available-on-gke
(worker-recovered; re-verify URL before citing on slides)

---

## 4. Zero-trust patterns → on-stage demo moments

| Pattern | Where it lives | The on-stage moment (agent tries, platform stops) |
|---|---|---|
| **gVisor/Kata isolation** | agent-sandbox delegates via `RuntimeClass`; GKE runs gVisor pools; Agent Substrate ateom on gVisor today | Agent runs a syscall-escape / container-breakout attempt inside the sandbox → trapped in the userspace kernel (gVisor) or microVM (Kata). Show: same exploit works on a plain pod, dies in the sandbox. Cleanest on GKE's gVisor pool or `kata-aks` example. |
| **KRO composition** | kro `ResourceGraphDefinition` → one `AgentWorkload` CRD composing NetworkPolicy + RuntimeClass + RBAC + quotas (Carlos's own "Platform Engineering for AI Agents" video); EKS Capabilities now ship managed kro | `kubectl apply` a single AgentWorkload → camera on the composed resource graph materializing. The point: guardrails as an API, in Git, via GitOps — the developer never hand-writes a NetworkPolicy. |
| **Credential proxies** | nono phantom credentials (per-tool micro-sandboxes); OpenShell TLS-terminating injection; Agent Substrate egress gateway `replace_headers` | Agent runs `env \| grep -i token` → nothing. Agent sends `Authorization: placeholder` → upstream receives the real Bearer <redacted> The audit log shows the allow; the agent's filesystem/snapshot contains zero secrets. This is the "untrusted tenant can't steal the keys" beat. |
| **NetworkPolicy lockdown** | agent-sandbox Managed per-template policy + `ClusterNetworkPolicy` default-deny with FQDN allowlists (`network-policy-api-sandbox` example); OpenShell namespace-wide deny-egress | Agent `curl https://evil.example.com` → timeout/deny; `curl https://api.allowed.com` → 200. Flip to the controller's audit/policy view showing the deny. Two terminals side by side = the whole pattern in 60 seconds. |
| **Warm pools** | `SandboxWarmPool` + `SandboxClaim`; GKE: 10–45x faster TTFC (1–9s vs 45–85s), tail latency 7.5min → <10s | Time it live: `time kubectl apply -f claim.yaml` → sub-second bind ("a warm claim is only sub-second because it changes nothing about the running pod except metadata") vs a cold pod (tens of seconds + image pull). Security moral: speed is what makes the secure path the *default* path — nobody bypasses the sandbox for performance. |

**Offense-side hook (use in the opener).** DIVD (Dutch volunteer vuln-research
nonprofit) was breached Sep 21, 2026 via chained Zammad zero-days
(CVE-2026-102489 session fixation → RCE as `zammad` user; CVE-2026-102490
privesc to root; CVSS 9.4 both; CISA KEV-listed Oct 2, 2026). DIVD attributed
part of the attack chain's speed to an **AI agent autonomously handling
portions of the attack**. Framing: "agents as untrusted tenants" cuts both
ways — the same capability defends your platform and attacks someone else's.
Status: fact-note only; needs Carlos's call before use on stage.
Details: ~/workspace/kubecon-na-2026-talks/platform-first-agent-security/divd-zammad-case-study.md

---

## 5. Demo feasibility verdict

**Option A — OpenShell local (Docker/Podman).** Lowest stage risk: stable
install, `openshell sandbox create`, declarative YAML policy, every
allow/deny logged — the policy-deny moment is extremely visual. Weakness:
not Kubernetes-native; undercuts the "platform-first *on Kubernetes*"
thesis unless explicitly framed as "the policy layer, which also runs on
K8s (experimental chart)."

**Option B — agent-sandbox on Kubernetes (kind or GKE).** The K8s-native
primitive and the honest center of the talk: `Sandbox` CRD, warm-pool claim
timed live, NetworkPolicy deny demo, gVisor/Kata via RuntimeClass. GKE's
managed path de-risks it further. Medium stage risk (live cluster), highest
thesis alignment.

**Option C — Agent Substrate live.** Best architecture story (actors as
tenants, multiplexing, egress credential injection), but the runnable
sandbox demo carries an **explicit "not secured, do not expose" disclaimer**
and the threat model admits little hardening has shipped. Demoing
"security" on it live would be dishonest unless framed as roadmap.
High stage risk if framed as production-ready.

**Recommendation: B live, A as the policy deep-dive, C as the vision.**
Open with the DIVD hook (60s), then:
1. **Live: agent-sandbox on Kubernetes** (the platform beat) —
   warm-pool claim timed, NetworkPolicy deny/allow, gVisor containment.
2. **Live or pre-recorded: OpenShell policy** (the credential beat) —
   phantom-credential injection; agent's env clean, upstream authenticated,
   audit log shows the decision. (Pre-record the K8s-chart path; do it
   local-live if the chart misbehaves in rehearsal.)
3. **Diagrams + honest framing: Agent Substrate** (the future beat) —
   actors-as-tenants, egress credential injection as the pattern's
   end-state; labeled "where the platform is going," with the alpha flag
   on screen. Its CNCF Sandbox application is the community news hook.
KRO `AgentWorkload` threads through all three as the composition layer
(Carlos's own prior art — reuse the diagram).

**Concrete demo script outline (numbered beats, ~12 min of the 30):**
1. Hook (2 min): DIVD/Zammad — an AI agent helped run a real intrusion
   chain in Sep 2026. "Tonight, the agent is the attacker. The platform
   is the defense."
2. The tenant model (3 min): one slide — agents get the same distrust as
   any tenant: identity, policy, no ambient authority. KRO `AgentWorkload`
   as the single API.
3. **Demo 1 — warm pool + claim (3 min):** pool pre-warmed; `time` a
   `SandboxClaim` (sub-second); contrast with cold-pod timing. Moral:
   the secure path must be the fast path.
4. **Demo 2 — network deny/allow (3 min):** agent curls evil.example.com
   → deny; curls allowed API → 200; show the policy/audit view. Two
   terminals, 60 seconds of actual typing.
5. **Demo 3 — credential proxy (3 min):** agent `env | grep TOKEN` →
   empty; request with placeholder header → 200 upstream; show the
   injected header in the gateway log and the empty snapshot. "The
   tenant never held the key."
6. Vision (3 min): Agent Substrate actors-as-tenants, default-deny
   roadmap, CNCF Sandbox application — labeled as the direction, with
   the alpha flag visible.
7. Close (2 min): the five patterns as checklist; "treat every agent
   like a tenant you don't trust yet."

**Rehearsal rule:** the K8s demos get one full dry run on the exact
cluster/chart versions; anything flaky becomes a pre-recorded video
with live narration (Carlos's standing rule from talk 1: never let a
live demo be the single point of failure — and per the 2026-10-03 lesson,
the first frame of any published video is a designed title card).

---

## 6. Community & adoption

- **agent-sandbox:** SIG Apps subproject, 4.1k+ GitHub stars, v1beta1 API;
  **GKE Agent Sandbox generally available** (RL-optimized, warm pools,
  10–45x TTFC); examples fleet: `kata-aks`, `kata-gke-sandbox`,
  `nono-sandbox`, `mcp-server-sandbox`, `openclaw-fleet-gke` (per-employee
  agents with NetworkPolicy egress allowlists), `hpa-swp-scaling`,
  `keda-scale-to-zero`. Sources: https://github.com/kubernetes-sigs/agent-sandbox,
  https://cloud.google.com/blog/products/containers-kubernetes/accelerate-agentic-rl-with-gke-agent-sandbox
- **OpenShell:** NVIDIA, Apache 2.0, 10.2k stars / 1.4k forks / 129
  contributors, weekly stable releases (v0.1.2 current); 100+ orgs in the
  platform ecosystem; motivated by the July 2026 OpenAI "warning shot"
  incident. Sources: https://github.com/NVIDIA/OpenShell,
  https://www.eesel.ai/blog/nvidia-open-agent-safety-platform
- **nono** (complementary, worth one slide): `sarovin/nono` —
  capability-based per-tool micro-sandboxes with phantom credentials via a
  trusted proxy (K8s Secrets as a source); **Datadog** staff security
  engineer on record: "the only sandbox that gives us both fine-grained,
  per-command policies and sophisticated credential management";
  `nono-sandbox` example exists in the agent-sandbox examples tree.
  Sources: https://github.com/sarovin/nono,
  https://helpnetsecurity.com/ ("Nono: Open-source sandbox for AI agents")
- **Agent Substrate:** CNCF Sandbox application
  (https://github.com/cncf/sandbox/issues/523), weekly community meetings
  (Carlos attends), GKE availability; threat model + roadmap public.
- **KRO:** `kro-run/kro` — `ResourceGraphDefinition` composes CRDs;
  **EKS Capabilities ship managed kro** (no self-managed controllers).
  Carlos's own "Platform Engineering for AI Agents" (KRO + AgentWorkload
  CRD composing gVisor/Kata, NetworkPolicy, CSI skill mounting) is the
  talk's direct predecessor — link it.
  Sources: https://github.com/kro-run/kro, https://docs.aws.amazon.com/eks
  (EKS Capabilities / kro)
- **Conference context:** KubeCon NA 2026 adds an **AI Inference + Agentic**
  track; Monday co-located events include **Cloud Native AI + Inference
  Day** and **Agentics Day: MCP + Agents** — the audience arrives primed.
  Carlos's talk sits in the **Security** track, which programs supply
  chain, identity, runtime protection, and policy enforcement.
  Source: https://www.cncf.io/announcements/2026/08/10/cncf-reveals-kubecon-cloudnativecon-north-america-2026-schedule-adds-new-ai-inference-agentic-track/

---

## Decisions (Carlos, 2026-10-04)

1. DIVD/Zammad opener — USE it (60-sec offense hook).
2. OpenShell K8s-chart path — PRE-RECORD from the start; live demo is OpenShell local only.
3. Agent Substrate — CUT from this talk; keep strictly to shipped-and-demoable.
4. July 2026 OpenAI incident — CITE BY NAME on stage.
