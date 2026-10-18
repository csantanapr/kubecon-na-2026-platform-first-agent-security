# Outline: Platform-First AI Agent Security (30 min, timed)

Thu Nov 12, 2026, 3:30-4:00 PM MST. Security track, any level. Solo.
Thesis: agents are untrusted tenants. The platform, not the agent, enforces security.

## Decisions (Carlos, 2026-10-04)

- DIVD/Zammad opener: USE.
- OpenShell on Kubernetes: PRE-RECORD; live demo is OpenShell local only.
- Agent Substrate: CUT; shipped-and-demoable only.
- July 2026 OpenAI incident: CITE BY NAME.

## Timed beats (~29 min content; the buffer absorbs the new slide)

### 1. Cover + hook: the offense (3 min)
- Cover: title, avatar, name/title/company. No KubeCon logo (first slide rule).
- DIVD/Zammad: Sep 2026, an AI agent helped run a real intrusion chain.
  CVSS 9.4, CISA KEV-listed Oct 2. 60-90 seconds, offense side.
- "Tonight, the agent is the attacker. The platform is the defense."

### 2. The tenant model (4 min)
- One slide: agents get the same distrust as any tenant.
- Three things every tenant gets: identity, policy, no ambient authority.
- KRO `AgentWorkload` as the single API that composes the stack
  (Carlos's prior art; reuse the diagram).
- One CR in Git, reconciled by the platform: GitOps for guardrails.
- The frameworks underneath will change every quarter. This interface
  does not have to.
- The line: "Treat every agent like a tenant you don't trust yet."

### 2b. The platform team's half (2 min)
- NEW slide after KRO: the ResourceGraphDefinition behind AgentWorkload.
  The platform team's side of the abstraction.
- Schema block: agent image, isolation mode, network profile, credential
  broker reference, with defaults. Resources block: Sandbox (RuntimeClass
  from the schema), NetworkPolicy (default deny), ServiceAccount + RBAC
  (identity, least privilege), ResourceQuota (bounded blast radius).
  Credentials brokered via the broker reference, never in env.
- Takeaway: "The platform team writes this once. Every agent inherits it."
- Click reveals: schema, resources, takeaway. Notes carry the identity /
  policy / no-ambient-authority mapping.
- Timing note: this beat pushes content to ~29 min. The buffer absorbs it.
  Nothing else is cut.

### 2c. Hard vs soft isolation (2 min)
- New slide between the platform-half slide and Demo 1: Kata (microVM, own guest kernel,
  hardware-virtualized boundary) vs gVisor (userspace kernel, syscall
  interception). agent-sandbox picks per workload via RuntimeClass.
- This talk's pool runs Kata. Demo 1 proves the boundary from inside the
  guest: show root and the guest kernel version running in the microVM,
  then the warm-pool claim timing.

### 3. Demo 1, live: warm pool + claim (4 min)
- agent-sandbox on Kubernetes. Pool pre-warmed.
- `time` a SandboxClaim: sub-second. Contrast with cold-pod timing.
- Moral: the secure path must be the fast path, or nobody takes it.

### 4. Demo 2, live: network deny/allow (4 min)
- The agent curls evil.example.com: denied.
- The agent curls the allowed API: 200.
- Show the NetworkPolicy and the audit view. Two terminals, ~60s of typing.
- Name the metadata endpoint: the same default-deny policy blocks it,
  so there is no credential theft via IMDS.
- Moral: default deny, explicit allow. The agent doesn't choose.

### 5. Demo 3: credential proxy (5 min)
- OpenShell, LOCAL, live: agent runs `env | grep TOKEN`: empty.
- Request with placeholder header: 200 upstream.
- Show the injected header in the gateway log and the empty snapshot.
- "The tenant never held the key."
- Pre-recorded video beat: the same flow on OpenShell on Kubernetes
  (experimental; recording de-risks it). Designed title card first frame.

### 6. It happened at the frontier too (2 min)
- July 2026 OpenAI incident, cited by name: the "warning shot" that
  motivated OpenShell. One slide, facts only, no editorializing the lab.

### 7. The five patterns checklist (4 min)
- gVisor/Kata isolation, KRO composition, credential proxy, NetworkPolicy
  egress lockdown, warm pools. One slide, reveal one by one.
- Each maps to a demo the room just saw. Checklist they can take home.

### 8. Close + thank you (1 min + buffer)
- "Treat every agent like a tenant you don't trust yet."
- Thank you slide: info again, rate in Sched, follow links. No logo (last slide rule).

## Demo risk rule

One full dry run of the K8s demos on the exact cluster versions.
Anything flaky becomes pre-recorded video with live narration. A live demo
is never the single point of failure.

## Slide count estimate

15 slides + 3 live demos + 1 pre-recorded video beat. Same DESIGN.md
identity as talk 1 (deck-v3/DESIGN.md); security-track art direction to be
resolved at build time, same tokens.
