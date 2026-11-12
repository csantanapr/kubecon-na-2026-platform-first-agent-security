# kagent 1.0 + kro 0.10 on Agent Substrate

Research for the KubeCon NA 2026 talk update (2026-11-12). Every claim below
was checked against the released source or a live run on kind; the source is
named next to it.

## Versions checked

| Project | Release | Date | Source |
| --- | --- | --- | --- |
| kagent | v1.0.1 (v1.0.0 on 2026-11-09) | 2026-11-12 | [releases](https://github.com/kagent-dev/kagent/releases/tag/v1.0.1) |
| kro | v0.10.0 | 2026-11-10 | [releases](https://github.com/kubernetes-sigs/kro/releases/tag/v0.10.0) |
| Agent Substrate (kagent's install) | v1.0.1 | 2026-11-08 | [kagent-dev/substrate](https://github.com/kagent-dev/substrate/releases/tag/v1.0.1), a fork of agent-substrate/substrate |
| kind | v0.33.0, node image Kubernetes 1.37.0 | 2026-08-26 | [releases](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0) |

The kagent docs site describes kagent 1.0 as an alpha release
([installation](https://kagent.dev/docs/kagent/introduction/installation)), and its
API is `api.kagent.dev/v1alpha3`. kro Graph is alpha behind the `GraphKind`
feature gate. Treat both as "try it now", not "run it in production today".

## The big change: kagent 1.0 runs on Agent Substrate

kagent 1.0 is a new control plane. Kubernetes stores the desired agent
configuration, PostgreSQL stores runtime state, and **Substrate Actors run the
agent processes** ([architecture README](https://github.com/kagent-dev/kagent/blob/v1.0.1/docs/architecture/README.md)).
Each Agent is compiled into an immutable revision, applied as a Substrate
ActorTemplate through ate-api, and marked Ready once its golden snapshot is
ready ([configuration and compilation](https://github.com/kagent-dev/kagent/blob/v1.0.1/docs/architecture/configuration-and-compilation.md)).
Release notes for v1.0.0 list Substrate support, AgentTemplate, Harness and the
AgentInstance lifecycle (suspend, resume, A2A gateway).

`kagent install` deploys the whole stack: Substrate in `ate-system` (gVisor
workers by default), a development PostgreSQL, the Pod Certificate controller,
and kagent ([helm README](https://github.com/kagent-dev/kagent/blob/v1.0.1/helm/README.md)).

## kagent 1.0 CRDs (`api.kagent.dev/v1alpha3`, all namespaced)

| Kind | What it owns | Security relevance |
| --- | --- | --- |
| `Agent` | Pairs one template with one Harness; reports readiness and revisions | `harnessRef` is namespace-local, so the runtime is chosen by whoever owns the Harness in that namespace |
| `AgentTemplate` | Portable behavior: model, prompt, tools (MCP, subagents), skills, plugins | No runtime or network settings: developers cannot pick their own sandbox |
| `Harness` | How agents run: runtime (kagent, Codex, Claude, BYO), image, env, WorkerPool, snapshot policy | Platform-owned; images must be digest-pinned |
| `EgressPolicy` | Extra HTTPS origins, optionally with a credential the gateway injects | Default deny; the injected credential never enters the guest ([egress policies](https://github.com/kagent-dev/kagent/blob/v1.0.1/docs/architecture/egress-policies.md)) |
| `SandboxTemplate` | Tools image and env for standalone sandboxes (command and file work) | A sandbox with no EgressPolicy has no egress at all ([sandboxes](https://github.com/kagent-dev/kagent/blob/v1.0.1/docs/architecture/sandboxes.md)) |
| `ModelConfig` | Model provider, model, API key Secret | `allowedNamespaces` decides which namespaces may reference it ([cross-namespace references](https://github.com/kagent-dev/kagent/blob/v1.0.1/docs/architecture/cross-namespace-references.md)) |
| `ModelProviderConfig` | Provider-level settings shared by models | |
| `RemoteMCPServer` | A remote MCP tool server | Also gated by `allowedNamespaces` |

Not Kubernetes objects: Sessions, standalone Sandboxes, prepared revisions,
A2A tasks and checkpoints live in PostgreSQL and are reached through gRPC, A2A
and MCP.

## Agent Substrate CRDs (`ate.dev/v1`)

Read from `charts/substrate-crds` in kagent-dev/substrate v1.0.1:

| Kind | Scope | What it owns |
| --- | --- | --- |
| `WorkerPool` | Namespaced | Worker pods that host Actors: replicas, worker image, sandbox classes (`gvisor`, `microvm`), pod template |
| `SandboxConfig` | Cluster | Sandbox runtime versions per class |
| `CSIDriverConfig` | Cluster | CSI volume integration |

Actors and ActorTemplates are not CRDs. They are managed through the ate-api
gRPC service (`kubectl ate`, or a control plane such as kagent).

## kro 0.10: Graph

kro v0.10.0 moves ResourceGraphDefinitions onto a new shared composition engine
and adds `Graph` ([Graph overview](https://kro.run/docs/concepts/graph/overview),
[upgrade notes](https://kro.run/docs/upgrading/v0.10.0/)).

- A Graph is the resources: no schema, no CRD, no instances. Use an RGD when you
  want a new API; use a Graph for bundles, decorators, fan-in and status
  contributions.
- Node kinds: `template` (owns), `ref` (reads; by name or label selector),
  `def` (computed value), `patch` (writes fields on something it does not own),
  `graph` (nesting). Modifiers: `forEach`, `includeWhen`, `readyWhen`.
- kro applies a Graph while impersonating a ServiceAccount in the Graph's
  namespace, so a Graph can never do more than that ServiceAccount's RBAC.
- Unlike an RGD, Graph nodes do not wait for dependencies' `readyWhen`.
- Other v0.10 additions: per-resource deletion policy (`DeletionPolicy` gate),
  constrained instance names, fail-closed CRD schema changes.

## Can users build kagent's capabilities with kro?

Short answer: no, and they should not try. kro composes Kubernetes objects; it
does not run agents. kagent's value is in its controllers and data plane:

| Capability | Who provides it | Can kro alone do it? |
| --- | --- | --- |
| Compile an agent into a Substrate ActorTemplate, golden snapshot, revisions | kagent controller | No. Actors are not Kubernetes objects |
| Sessions, A2A gateway, durable tasks, checkpoint and fork, auto-suspend | kagent apiserver + Substrate | No |
| Egress gateway that injects credentials without exposing them | kagent EgressPolicy + Substrate egress | No (kro can create the EgressPolicy) |
| Sandbox isolation (gVisor, microVM) | Substrate WorkerPool + SandboxConfig | No (kro can create the WorkerPool) |
| One opinionated API with safe defaults (`AgentWorkload`) | kro RGD | **Yes** |
| Onboard a team with one label (pool, Harness, quota, identity) | kro Graph | **Yes** |
| Keep developers from choosing runtime, network or model | kro schema + namespace-local Harness + RBAC | **Yes** |
| Roll status of many objects into one `ready` field | kro RGD status | **Yes** |

So the right picture is layers, not a replacement:

```
kro         Graph (tenants)  +  RGD (AgentWorkload)      platform API, defaults, onboarding
kagent 1.0  Agent, AgentTemplate, Harness, EgressPolicy   agent lifecycle, A2A, egress gateway
Substrate   WorkerPool, SandboxConfig, Actors             sandboxed execution, snapshots
runtime     gVisor | microVM (Kata / Firecracker) | AWS Nitro Sandbox on EKS
```

**kro directly on Substrate** works for the infrastructure layer: kro can stamp
WorkerPools, SandboxConfigs, ServiceAccounts and quotas per tenant. It cannot
create Actors, so on its own you still need `kubectl ate` or a control plane to
run something. **kro on kagent** is the full path: kro creates the kagent
objects, kagent turns them into Actors.

## What the live kind run showed

Verified on kind v0.33.0 / Kubernetes 1.37.0, kagent 1.0.1, kro 0.10.0
(demo in `demos/kind/kro-kagent-substrate/`):

- The tenant Graph turned one namespace label into a ServiceAccount, a gVisor
  WorkerPool, a `secure-default` Harness and a ResourceQuota. Removing the label
  prunes them.
- One `AgentWorkload` became an EgressPolicy, AgentTemplate, Agent and
  SandboxTemplate. The Agent reached `Ready=True` ("ActorTemplate golden
  snapshot is ready") without a real model key.
- In a sandbox from that template: `uname` reports `4.19.0-gvisor`;
  `curl https://api.github.com` returns 200; `curl https://example.com` fails
  with `Could not resolve host` because it is not on the allow-list.
- An AgentWorkload in a namespace without the label stays not Ready:
  `resolve Harness "team-b/secure-default": not found`.

Gotchas found while building it:

1. **Helm 4 breaks `kagent install` 1.0.1.** Helm 4 prints `Pulled:` and `Digest:`
   on stdout for OCI charts; the CLI parses `helm template` stdout and fails with
   `rendered controller deployment has no service account`. Helm 3.22 works.
2. **Standalone sandboxes need `config.sandboxes.guestImage`.** It is empty in the
   chart; set it to the digest-pinned `ghcr.io/kagent-dev/kagent/sandbox-guest`
   image or SandboxTemplates fail with "images must be pinned by sha256 digest".
3. **WorkerPools you create yourself need kagent's placement labels**
   (`kagent.dev/worker-pool-name`, `kagent.dev/worker-pool-namespace`). Without
   them ate-api logs `no worker has room for the actor` and the agent never gets
   Ready. The chart's own pool has them; a kro-created pool must add them.
4. **kro in `rbac.mode: aggregation`** needs RBAC for the CRD it generates
   (`acme.dev/agentworkloads`) as well as for the kinds it composes.
5. The kind node needs the `PodCertificateRequest`, `ClusterTrustBundle` and
   `ClusterTrustBundleProjection` feature gates (from kagent's own kind config).

## How this maps to the talk's five patterns

| Pattern | Before (illustrative) | Now (running) |
| --- | --- | --- |
| Guardrails as an API | Illustrative AgentWorkload RGD | Real RGD composing kagent 1.0 objects |
| Hard or soft isolation | RuntimeClass on a Sandbox | Substrate WorkerPool sandbox class (gVisor on kind; microVM / AWS Nitro Sandbox on EKS) |
| Default deny, explicit allow | NetworkPolicy | kagent EgressPolicy, enforced by Substrate egress, plus NetworkPolicy |
| Credential brokering | OpenShell | OpenShell, or EgressPolicy credential injection at the gateway |
| Tenant onboarding | n/a | kro Graph namespace decorator |

## OpenShell and Cedar (checked 2026-11-12)

- **CNCF:** NVIDIA contributed OpenShell to the CNCF as a Sandbox project on
  2026-11-10 at KubeCon NA. The CNCF post says OpenShell is adopting Cedar,
  another CNCF project, as its policy language, and that the repo is moving
  from NVIDIA's GitHub to the neutral `ai-openshell` org
  ([CNCF blog](https://www.cncf.io/blog/2026/11/10/welcoming-openshell-to-the-cncf-open-governance-to-secure-agentic-ai/),
  [NVIDIA blog](https://blogs.nvidia.com/blog/open-source-openshell-infrastructure/)).
  As of today the code is still at `NVIDIA/OpenShell` (latest release v0.1.8, 2026-11-10);
  `ai-openshell` already hosts the SDKs, console, `.project` metadata and
  `cedar` / `cedar-spec` forks.
- **Today's policy engine:** YAML policies, evaluated by a Rego engine
  (`regorus` in `crates/openshell-supervisor-network`).
- **Cedar status: in review, not merged.** RFC 0020
  ([PR #4564](https://github.com/NVIDIA/OpenShell/pull/4564), issue
  [#4411](https://github.com/NVIDIA/OpenShell/issues/4411), assigned by maintainer
  `drew`) proposes Cedar as an alternate sandbox policy language, chosen once per
  sandbox; a Cedar sandbox builds no OPA engine. Implementation:
  [PR #4565](https://github.com/NVIDIA/OpenShell/pull/4565) (+50k lines, e2e suite),
  restacked by `drew` as [PR #5006](https://github.com/NVIDIA/OpenShell/pull/5006)
  to ship Cedar in **development builds only** first; examples in
  [PR #4991](https://github.com/NVIDIA/OpenShell/pull/4991). The parity harness
  runs 2,909 YAML/Cedar case pairs: 2,904 agree, and in the 5 deliberate
  differences Cedar is stricter. It depends on Cedar's delimited `like` work
  ([cedar-policy/rfcs#115](https://github.com/cedar-policy/rfcs/pull/115)), pinned
  from `ai-openshell/cedar`. A Cedar maintainer (`luxas`) is working with the
  OpenShell author on that extension in the issue thread.
- The slide's Cedar excerpt is copied verbatim from
  `examples/sandbox-policy-quickstart/policy.cedar` on the PR #4991 branch.

## CNCF status of every project in the talk

| Project | CNCF status | Source |
| --- | --- | --- |
| Kubernetes, containerd, Helm | Graduated | cncf.io/projects |
| kro | Kubernetes SIG Cloud Provider subproject (`kubernetes-sigs/kro`) | [README](https://github.com/kubernetes-sigs/kro) |
| agent-sandbox | Kubernetes SIG Apps subproject (`kubernetes-sigs/agent-sandbox`) | [README](https://github.com/kubernetes-sigs/agent-sandbox) |
| Agent Substrate | Sandbox (contributed Nov 2026) | [CNCF project page](https://www.cncf.io/projects/agent-substrate/), [NVIDIA blog](https://developer.nvidia.com/blog/agent-substrate-advancing-kubernetes-for-agents-at-scale/) |
| kagent | Sandbox (accepted 2025-05-22) | [CNCF project page](https://www.cncf.io/projects/kagent/) |
| OpenShell | Sandbox (2026-11-10) | [CNCF blog](https://www.cncf.io/blog/2026/11/10/welcoming-openshell-to-the-cncf-open-governance-to-secure-agentic-ai/) |
| Cedar | Sandbox (accepted 2025-10-08) | [CNCF presentations](https://presentations.cncf.io/projects/cedar/), [AWS blog](https://aws.amazon.com/blogs/opensource/cedar-joins-cncf-as-a-sandbox-project/) |

| gVisor | Sandbox (accepted 2026-09-28, donated by Google; announced with Agent Substrate on 2026-11-05) | [gVisor blog](https://gvisor.dev/blog/2026/10/02/gvisor-cncf/), [Google Open Source blog](https://opensource.googleblog.com/2026/11/sandboxing-untrusted-ai-agents-at-scale.html) |

Not CNCF: Kata Containers (OpenInfra Foundation), AWS Nitro Sandbox, Calico
(Tigera). The deck's line is "from the platform API down to the gVisor sandbox".
