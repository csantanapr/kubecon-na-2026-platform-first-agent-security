# kro on kagent on Agent Substrate (kind)

Run the whole agent platform on your laptop: a kro **Graph** onboards a team
with one namespace label, a kro **ResourceGraphDefinition** gives developers a
one-object `AgentWorkload` API, kagent 1.0 compiles each agent into an Agent
Substrate Actor, and every agent and tools sandbox runs under gVisor with
default-deny egress.

| Layer | What runs | Version |
| --- | --- | --- |
| kro | Graph `agent-tenants`, RGD `agentworkload` | v0.10.0 (`GraphKind` on) |
| kagent | Agent, AgentTemplate, Harness, EgressPolicy, SandboxTemplate, ModelConfig | v1.0.1 |
| Agent Substrate | WorkerPool, SandboxConfig, Actors (gVisor) | v1.0.1 (installed by `kagent install`) |
| Kubernetes | kind single node | v1.37.0 (kind v0.33.0) |

## Run it

```bash
./install.sh   # ~10 minutes: kind, Substrate + kagent, kro, the platform files
./run.sh       # the demo, step by step (Enter between steps; DEMO_AUTO=1 to run straight through)
./clean.sh     # delete the kind cluster
```

Needs Docker, kind v0.33+, kubectl, curl, and about 8 GB of free memory.
`install.sh` downloads Helm 3 and the kagent CLI into `.work/bin` and writes
its kubeconfig to `.work/kubeconfig`, so your `~/.kube/config` is untouched.
To use the cluster from your shell: `export KUBECONFIG=$PWD/.work/kubeconfig`.

Set `OPENAI_API_KEY` before `install.sh` if you want to chat with the agent
(`kagent dashboard`). Without it, every object still deploys, the agent still
reaches Ready, and the sandbox egress demo still runs.

## What the demo shows

1. **One label onboards a team.** `tenant/team-a.yaml` labels a namespace
   `agents.acme.dev/tenant=true`. The Graph creates a ServiceAccount, a gVisor
   WorkerPool, a `secure-default` Harness and a ResourceQuota in it. Remove the
   label and kro prunes them.
2. **One object per agent.** `tenant/support-agent.yaml` is the whole developer
   input: a prompt and one allowed origin. kro creates the EgressPolicy,
   AgentTemplate, Agent and a tools SandboxTemplate.
3. **Default deny, explicit allow.** Inside a sandbox from that template,
   `uname` reports a gVisor kernel, `https://api.github.com` answers 200, and
   `https://example.com` does not resolve.
4. **No label, no agent.** The same AgentWorkload in an un-onboarded namespace
   never gets Ready: there is no Harness for it.

## Files

| File | Owner | Purpose |
| --- | --- | --- |
| `platform/00-kro-rbac.yaml` | platform team | What kro may touch (`rbac.mode: aggregation`) and the Graph's own ServiceAccount |
| `platform/10-tenant-graph.yaml` | platform team | kro Graph: tenant decorator on top of Agent Substrate and kagent |
| `platform/20-agentworkload-rgd.yaml` | platform team | kro RGD: the `AgentWorkload` API on top of kagent |
| `tenant/team-a.yaml` | team | Ask for a tenant |
| `tenant/support-agent.yaml` | developer | One agent |
| `kagent/` | platform team | kagent install settings |

## Good to know

- **Use Helm 3 with `kagent install` 1.0.1.** Helm 4 prints `Pulled:` lines on
  stdout for OCI charts and the installer fails with
  `rendered controller deployment has no service account`.
- **Standalone sandboxes need a guest image.** `kagent/kagent-values.yaml` sets
  `config.sandboxes.guestImage` to the digest-pinned release image.
- **Your own WorkerPools need kagent's placement labels**
  (`kagent.dev/worker-pool-name`, `kagent.dev/worker-pool-namespace`), or agents
  wait forever with `no worker has room for the actor` in the ate-api logs.
- **Lock down who can create Harnesses.** Agents can only use a Harness in their
  own namespace, so keeping Harness create rights with the platform team keeps
  the runtime choice with the platform team. Grant developers access to
  `agentworkloads.acme.dev`, not to raw kagent kinds, if you want the
  AgentWorkload API to be the only door.
- **Isolation beyond gVisor.** Change the WorkerPool's sandbox class to
  `microvm` on nodes with KVM, or run on EKS with AWS Nitro Sandbox for
  hardware-level isolation. The AgentWorkload API does not change.
- Graph and kagent 1.0's `v1alpha3` API are alpha; expect changes between releases.

Learn more: [kro Graph](https://kro.run/docs/concepts/graph/overview),
[kro RGD](https://kro.run/docs/concepts/rgd/overview),
[kagent architecture](https://github.com/kagent-dev/kagent/tree/v1.0.1/docs/architecture),
[Agent Substrate](https://github.com/kagent-dev/substrate).
Research notes: [`research/kagent-1.0-kro-0.10.md`](../../../research/kagent-1.0-kro-0.10.md).
