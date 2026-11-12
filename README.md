# Platform-First AI Agent Security: Zero-Trust Patterns for Kubernetes

KubeCon + CloudNativeCon North America 2026 - Salt Lake City.
Thursday, November 12, 2026, 3:30–4:00 PM MST. Security track (any level),
Level 2, 255 BC. Solo speaker: Carlos Santana (AWS, CNCF Ambassador).
Schedule: https://events.linuxfoundation.org/kubecon-cloudnativecon-north-america/program/schedule/?id=1251009

Treat AI agents as untrusted tenants: gVisor, Kata, or hardware isolation,
KRO-composed guardrails, credential brokering, NetworkPolicy lockdown, warm
pools. Built on CNCF projects, demoed live.

**Slides:** [csantanapr.github.io/kubecon-na-2026-platform-first-agent-security](https://csantanapr.github.io/kubecon-na-2026-platform-first-agent-security/)

## What is in this repo

- `slides/platform-first-agent-security-slim.html` - the deck, and the file the
  slides site serves. 20 slides, self-contained (works offline from `file://`).
  Open in Chrome, `f` for fullscreen, arrow keys / space to advance (steps
  reveal first, then the next slide). `s` opens the presenter view: speaker
  notes split into `click` sections, timer, next-slide preview. On the four
  demo slides, press `T` for a full-screen terminal replay of the live run
  (arrow keys run each command, `Esc` closes).
- `speaker-notes/notes-speaker.md` - the full speaker notes (~30 minutes), one
  section per slide, split into `click` sections matching the staged reveals.
- `screenplay.md` - what to say on each slide, click by click, with timings
  from a rehearsal run and where each demo inserts.
- `research/` - the research behind the talk, verbatim: `research.md`,
  `divd-zammad-case-study.md` (the opening hook), `outline.md` (the timed
  30-minute outline), `LINKS.md` (key source URLs),
  `kagent-1.0-kro-0.10.md` (kagent 1.0 and kro 0.10 CRDs, what kro can and
  cannot replace, and what the kind run showed).
- `snippets/` - real YAML from the deck, each verified to parse:
  `agentworkload-cr.yaml` (the developer-facing CR), `resourcegraphdefinition.yaml`
  (the platform team's kro definition on top of kagent), `tenant-graph.yaml`
  (the kro 0.10 Graph that onboards a team on Agent Substrate), `networkpolicy-egress.yaml`
  (default-deny egress), `sandboxclaim.yaml` (warm-pool claim),
  `openshell-network-policy.yaml` (the broker's rulebook).
- `demos/kind/` - live-demo pack for a kind cluster. Read `FEASIBILITY.md`
  first: it says honestly what runs on stock kind and what does not.
  - `kro-kagent-substrate` - the whole stack on kind (Kubernetes 1.37): kro
    0.10 Graph + RGD on kagent 1.0 on Agent Substrate (gVisor). `./install.sh`
    then `./run.sh`; see its README.
  - `demo-network-policy` - fully kind-feasible: default deny, explicit allow
    (installs Calico; kind's default CNI does not enforce NetworkPolicy).
  - `agent-sandbox` - needs a capable cluster (Kata or gVisor runtime); stock
    kind cannot run it. Install pointers inside.
  - `openshell` - the local-binary credential-brokering flow plus the
    experimental on-cluster notes.

## Running the kind demos

```bash
# kro on kagent on Agent Substrate
cd demos/kind/kro-kagent-substrate && ./install.sh && ./run.sh

# NetworkPolicy only
kind create cluster --name agent-demo --config demos/kind/kind-config.yaml
cd demos/kind/demo-network-policy && ./run.sh
```

## Deliberately excluded

Practice videos (`*.mp4`, ~370 MB total: the v5 rehearsal cut, per-segment
clips, and the standalone simulated demos) are not in this repo. They live in
the workspace at `~/workspace/kubecon-na-2026-talks/platform-first-agent-security/practice-video/`.
Nothing on stage depends on them: each demo slide carries a terminal replay of
the live EKS run as its offline fallback.
