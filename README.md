# Platform-First AI Agent Security: Zero-Trust Patterns for Kubernetes

KubeCon + CloudNativeCon North America 2026 - Salt Lake City.
Thursday, November 12, 2026, 3:30–4:00 PM MST. Security track (any level),
Level 2, 255 BC. Solo speaker: Carlos Santana (AWS, CNCF Ambassador).
Schedule: https://events.linuxfoundation.org/kubecon-cloudnativecon-north-america/program/schedule/?id=1251009

Treat AI agents as untrusted tenants: gVisor/Kata isolation, KRO-composed
guardrails, credential brokering, NetworkPolicy lockdown, warm pools. Built on
CNCF projects, demoed live.

## What is in this repo

- `slides/platform-first-agent-security.html` - the stage deck. 15 slides,
  self-contained (works offline from `file://`; the four simulated demo videos
  are embedded). Open in Chrome, `f` for fullscreen, arrow keys / space to
  advance (steps reveal first, then the next slide). `s` opens the presenter
  view: speaker notes split into `click` sections, timer, next-slide preview.
- `slides/platform-first-agent-security-slim.html` - same 15 slides, smaller
  file for quick reference.
- `speaker-notes/notes-speaker.md` - the full speaker notes, one section per
  slide, split into `click` sections matching the staged reveals.
- `screenplay.md` - what to say on each slide: condensed beats, click cues,
  timings, and where each demo inserts.
- `research/` - the research behind the talk, verbatim: `research.md`,
  `divd-zammad-case-study.md` (the opening hook), `outline.md` (the timed
  30-minute outline), `LINKS.md` (key source URLs).
- `snippets/` - real YAML from the deck, each verified to parse:
  `agentworkload-cr.yaml` (the developer-facing CR), `resourcegraphdefinition.yaml`
  (the platform team's KRO definition), `networkpolicy-egress.yaml`
  (default-deny egress), `sandboxclaim.yaml` (warm-pool claim),
  `openshell-network-policy.yaml` (the broker's rulebook).
- `demos/kind/` - live-demo pack for a kind cluster. Read `FEASIBILITY.md`
  first: it says honestly what runs on stock kind and what does not.
  - `demo-network-policy` - fully kind-feasible: default deny, explicit allow
    (installs Calico; kind's default CNI does not enforce NetworkPolicy).
  - `agent-sandbox` - needs a capable cluster (Kata or gVisor runtime); stock
    kind cannot run it. Install pointers inside.
  - `openshell` - the local-binary credential-brokering flow plus the
    experimental on-cluster notes.

## Running the kind-feasible demo

```bash
kind create cluster --name agent-demo --config demos/kind/kind-config.yaml
cd demos/kind/demo-network-policy && ./run.sh
```

## Deliberately excluded

Practice videos (`*.mp4`, ~370 MB total: the v5 rehearsal cut, per-segment
clips, and the standalone simulated demos) are not in this repo. They live in
the workspace at `~/workspace/kubecon-na-2026-talks/platform-first-agent-security/practice-video/`.
The four simulated demo videos are already embedded in the stage deck itself as
the offline fallback, so nothing on stage depends on them.
