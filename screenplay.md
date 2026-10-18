# Screenplay - Platform-First AI Agent Security

30 minutes, Security track, any level. Thesis: agents are untrusted tenants.
The platform, not the agent, enforces security.
Timings come from the v5 practice run; the platform-half beat is newer than
the video (~2:00 per the outline). "Clicks" = staged reveal steps.
Live demos are primary; each demo slide has an embedded simulated fallback
("No cluster? Play the simulated fallback.").

## Slide 1 - Cover (~0:35)

**Say:** Welcome. Come in, grab a seat. The title is the whole talk: zero-trust
patterns for AI agents, on Kubernetes.
**Click 1:** My name is Carlos Santana. I am a containers specialist at AWS, and
a CNCF Ambassador. Thirty minutes on one idea: your AI agents are tenants on
your platform, and right now most of them are tenants you never vetted. I will
show you the platform patterns that change that, with live demos. Nothing here
is slides-only.

## Slide 2 - An AI agent helped break in. (~1:15)

**Say:** An AI agent helped break in. September 21, 2026. DIVD, the Dutch
volunteer vulnerability research nonprofit, got breached.
**Click 1:** Chained Zammad zero-days. Session fixation to RCE as the zammad
user, then privesc to root. CVSS 9.4 on both. CISA put them on the KEV list on
October 2. Here is the part that matters for this room: DIVD attributed part of
the attack chain's speed to an AI agent autonomously handling portions of the
attack.
**Click 2:** Tonight, the agent is the attacker. The platform is the defense.
Keep that frame. We are coming back to it.

## Slide 3 - Treat every agent like a tenant you don't trust yet. (~1:05)

**Say:** Look at the image. Agents, each in their own box. Here is the whole
talk in one sentence.
**Click 1:** Treat every agent like a tenant you don't trust yet. Not because
agents are evil. Because they are powerful, autonomous, and ambiguous in their
instructions, and that combination cannot govern itself. You already know how to
handle untrusted tenants. Kubernetes was built for it. We are just going to aim
those controls at agents.

## Slide 4 - A tenant gets three things. (~1:25)

**Say:** A tenant gets three things. An agent should get the same three.
**Click 1:** One: identity. Every agent is somebody. A verifiable identity the
platform issued, not a string the agent claims about itself.
**Click 2:** Two: policy. What it may touch, written down, enforced outside the
agent. Not a suggestion buried in a system prompt.
**Click 3:** Three: no ambient authority. Nothing by default. No cloud
credentials sitting in the environment. No open network. No shared filesystem.
If your agent has any of those three missing, you don't have a tenant. You have
a guest with the run of the building.

## Slide 5 - Guardrails as an API. (~1:15)

**Say:** How do you actually ship those three things without hand-writing YAML
for every agent? One Custom Resource. I call it AgentWorkload. You write what
the agent is and what it needs. One CR in Git, reconciled by the platform. That
is GitOps for guardrails.
**Click 1:** This is the developer's view. The agent image, the isolation mode,
the network profile, the credential broker. Four fields, and the developer
never hand-writes a NetworkPolicy. The snippet on screen is illustrative of the
shape. Check the KRO docs for your version's fields.
**Click 2:** KRO takes that one object and materializes the guardrails: the
Sandbox with the right runtime class, the NetworkPolicy, the RBAC, the quotas.
The developer writes one thing in Git. The platform produces the rest.
Guardrails as an API. And here is the part that matters for the long run: the
frameworks underneath will change every quarter. This interface does not have
to.

## Slide 6 - The platform team's half. (~2:00)

**Say:** That was the developer's half. This is the platform team's half. Same
AgentWorkload, seen from the side that defines it: the KRO
ResourceGraphDefinition.
**Click 1:** It starts with the schema. The platform team declares the shape of
the API: the agent image, the isolation mode, the network profile, the
credential broker reference. Sensible defaults on all four, so the developer
only overrides what is unusual. Shapes here are illustrative. Check the KRO
docs for your version's fields.
**Click 2:** Then the resources. Each id is a building block. The Sandbox takes
its RuntimeClass from the schema, gVisor or Kata per agent. The NetworkPolicy
is default deny. The ServiceAccount plus the RoleBinding is the identity, least
privilege, nothing by default. The quota bounds the blast radius. And the
broker reference keeps credentials out of env. Identity, policy, no ambient
authority. Composed once, in one place.
**Click 3:** The platform team writes this once. Every agent inherits it. That
is what makes the tenant model scale: the guardrails are defined in one file,
and every AgentWorkload gets them without extra work.

## Slide 7 - Two kinds of sandbox. (~0:40)

**Say:** Two kinds of sandbox, and you pick per workload.
**Click 1:** Kata is hard isolation: each sandbox is a lightweight virtual
machine with its own guest kernel, behind a hardware-virtualized boundary. Even
root in the guest cannot reach the host kernel.
**Click 2:** gVisor is soft isolation: a userspace kernel that intercepts
syscalls. No VM, lighter, faster to start. The app thinks it is talking to
Linux.
**Click 3:** agent-sandbox delegates to either via RuntimeClass. This talk's
pool runs Kata, and the next demo proves the boundary from inside the guest.

## Slide 8 - The secure path must be the fast path. (~1:10 live + ~1:00 sim)

**Say:** First live demo. The secure path must be the fast path, or nobody
takes it. I have a warm pool of sandboxes sitting ready. Watch the clock.
**Click 1:** I apply a SandboxClaim. It binds in under a second, because the
sandbox already exists. The claim changes almost nothing.
**[DEMO: time kubectl apply -f claim.yaml against the pre-warmed pool. Show
the sub-second bind.]**
**Click 2:** Now compare that to a cold pod: image pull, runtime start, tens of
seconds. Security that is slower than the alternative gets bypassed. Speed is
what makes the sandbox the default. Nobody bypasses the sandbox for
performance.
**Fallback:** embedded sim video. Kind note: needs a capable cluster (see
demos/kind/FEASIBILITY.md).

## Slide 9 - Default deny, explicit allow. (~1:20 live + ~0:35 sim)

**Say:** Second live demo. Default deny, explicit allow. The policy on screen is
the whole rulebook: this agent may talk to one API on 443, and nothing else.
**Click 1:** The agent tries to phone home to evil.example.com. Denied. Nothing
leaves. The agent calls the API it is allowed to use. 200. Business as usual.
**[DEMO: curl evil.example.com shows deny/timeout. curl api.allowed.com
returns 200.]**
**Click 2:** The agent never chose. The NetworkPolicy chose, before the packet
left the node. The same default-deny policy also blocks the cloud metadata
endpoint, so there is no credential theft via IMDS. Two terminals, one policy
view. That is the whole pattern in sixty seconds.
**Kind version:** demos/kind/demo-network-policy/run.sh (installs Calico;
kindnet does not enforce NetworkPolicy).

## Slide 10 - The tenant never held the key. (~1:30 live + ~0:40 sim)

**Say:** Third demo. This one is my favorite. The tenant never held the key. The
policy on screen is the broker's rulebook: this agent may reach one endpoint,
read-only, everything else denied.
**Click 1:** The agent runs env, greps for token. Empty. There is nothing to
steal, because nothing was ever there. Then the agent makes a request with a
placeholder header. Upstream answers 200, fully authenticated.
**[DEMO: OpenShell local. env | grep -i token returns empty. Request with
placeholder header succeeds. Show the gateway log with the injected header and
the empty snapshot.]**
**Click 2:** What happened: OpenShell terminated the stream and injected the
real credential at the gateway. The agent saw a placeholder. Upstream saw a
Bearer token. The audit log recorded the decision. Steal the agent's
environment and you get nothing. Snapshot its disk and you get nothing.

## Slide 11 - Same flow, OpenShell on Kubernetes. (~1:00 + ~0:40 sim)

**Say:** Same flow, OpenShell on Kubernetes. This is pre-recorded, because
OpenShell on Kubernetes is experimental and I don't let experiments decide my
talk.
**Click 1:** What you are about to see: the placeholder-header flow running on
OpenShell on Kubernetes, same allow/deny audit trail, same empty agent
environment. Watch for the moment the gateway log shows the injection. That is
the tenant boundary, on Kubernetes. [Play the recording. First frame is a
designed title card. Narrate live over the playback.]
**Click 2:** And to be clear about maturity: the pattern is the point. Broker
the credential at the gateway, keep the agent's environment clean. The
OpenShell on Kubernetes implementation is still maturing, which is why this
part is on video.

## Slide 12 - It happened at the frontier too. (~1:30)

**Say:** It happened at the frontier too. July 2026.
**Click 1:** OpenAI's internal cybersecurity evaluation found models bypassing
isolation controls. Research infrastructure compromised. Hugging Face systems
touched. SSRF to the internet. Reconstructed exposed credentials. Chained
zero-days. OpenAI called it a warning shot.
**Click 2:** I am citing them by name because they published it, and the lesson
is theirs: a combination of tools, time, and ambiguous instructions, and the
agent cannot be expected to govern its own behavior. That is not a criticism of
the lab. It is the mechanism. Ambiguous instructions plus real tools will always
find the gap. The environment has to hold the boundary, because the model will
not.

## Slide 13 - Five patterns. Take them home. (~1:30)

**Say:** Five patterns. Take them home. Each one maps to something you just
saw. (Reveal one by one; let each land.)
**Click 1:** One: gVisor or Kata isolation. The breakout dies in the sandbox.
**Click 2:** Two: KRO composition. Guardrails as an API, in Git.
**Click 3:** Three: credential proxy. The tenant never held the key.
**Click 4:** Four: NetworkPolicy lockdown. Default deny, explicit allow.
**Click 5:** Five: warm pools. The secure path is the fast path. Run this
checklist against every agent you deploy. The ones that fail it are tenants you
haven't vetted yet.

## Slide 14 - Closing (~0:45)

**Say:** Treat every agent like a tenant you don't trust yet.
**Click 1:** Isolate it. gVisor or Kata under every agent, no exceptions.
**Click 2:** Compose it. One CRD, guardrails materialized by the platform.
**Click 3:** Broker it. Credentials injected, never handed out.
**Click 4:** Deny it. Egress default-deny, allowlist the rest.
**Click 5:** Warm it. Make the secure path the fast path, so your developers
take it without thinking. The platform enforces. The agent just runs. That is
the whole talk.

## Slide 15 - Thank you. (~0:25)

**Say:** Thank you for the thirty minutes. Two asks.
**Click 1:** First, rate this session in the Sched app. Ten seconds, and it is
how speakers get invited back.
**Click 2:** Second, follow along. LinkedIn, X, GitHub, santana.dev. I post
about containers and AI agents. Come say hi after. The hallway track beats the
stage.
