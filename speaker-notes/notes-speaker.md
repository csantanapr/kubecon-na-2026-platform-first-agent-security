## cover

Welcome. Come in, grab a seat. The title is the whole talk: zero-trust patterns for AI agents, on Kubernetes.

click

My name is Carlos Santana. I am a containers specialist at AWS, and a CNCF Ambassador.
Thirty minutes on one idea: your AI agents are tenants on your platform, and right now most of them are tenants you never vetted.
I will show you the platform patterns that change that, with live demos. Nothing here is slides-only.
## hook-divd

An AI agent helped break in. September 21, 2026. DIVD, the Dutch volunteer vulnerability research nonprofit, got breached.

click

Chained Zammad zero-days. Session fixation to RCE as the zammad user, then privesc to root. CVSS 9.4 on both. CISA put them on the KEV list on October 2.
Here is the part that matters for this room: DIVD attributed part of the attack chain's speed to an AI agent autonomously handling portions of the attack.

click

Tonight, the agent is the attacker. The platform is the defense.
Keep that frame. We are coming back to it.
## thesis-tenant

Look at the image. Agents, each in their own box. Here is the whole talk in one sentence.

click

Treat every agent like a tenant you don't trust yet.
Not because agents are evil. Because they are powerful, autonomous, and ambiguous in their instructions, and that combination cannot govern itself.
You already know how to handle untrusted tenants. Kubernetes was built for it. We are just going to aim those controls at agents.
## tenant-model

A tenant gets three things. An agent should get the same three.

click

One: identity. Every agent is somebody. A verifiable identity the platform issued, not a string the agent claims about itself.

click

Two: policy. What it may touch, written down, enforced outside the agent. Not a suggestion buried in a system prompt.

click

Three: no ambient authority. Nothing by default. No cloud credentials sitting in the environment. No open network. No shared filesystem.
If your agent has any of those three missing, you don't have a tenant. You have a guest with the run of the building.
## kro-composition

How do you actually ship those three things without hand-writing YAML for every agent?
One Custom Resource. I call it AgentWorkload. You write what the agent is and what it needs.
One CR in Git, reconciled by the platform. That is GitOps for guardrails.

click

This is the developer's view. The agent image, the isolation mode, the network profile, the credential broker. Four fields, and the developer never hand-writes a NetworkPolicy.
The snippet on screen is illustrative of the shape. Check the KRO docs for your version's fields.

click

KRO takes that one object and materializes the guardrails: the Sandbox with the right runtime class, the NetworkPolicy, the RBAC, the quotas.
The developer writes one thing in Git. The platform produces the rest. Guardrails as an API.
And here is the part that matters for the long run: the frameworks underneath will change every quarter. This interface does not have to.
## platform-half

That was the developer's half. This is the platform team's half. Same AgentWorkload, seen from the side that defines it: the KRO ResourceGraphDefinition.

click

It starts with the schema. The platform team declares the shape of the API: the agent image, the isolation mode, the network profile, the credential broker reference. Sensible defaults on all four, so the developer only overrides what is unusual.
Shapes here are illustrative. Check the KRO docs for your version's fields.

click

Then the resources. Each id is a building block. The Sandbox takes its RuntimeClass from the schema, gVisor or Kata per agent. The NetworkPolicy is default deny. The ServiceAccount plus the RoleBinding is the identity, least privilege, nothing by default. The quota bounds the blast radius. And the broker reference keeps credentials out of env.
Identity, policy, no ambient authority. Composed once, in one place.

click

The platform team writes this once. Every agent inherits it.
That is what makes the tenant model scale: the guardrails are defined in one file, and every AgentWorkload gets them without extra work.
## isolation-hard-soft

Two kinds of sandbox, and you pick per workload.

click

Kata is hard isolation: each sandbox is a lightweight virtual machine with its own guest kernel, behind a hardware-virtualized boundary. Even root in the guest cannot reach the host kernel.

click

gVisor is soft isolation: a userspace kernel that intercepts syscalls. No VM, lighter, faster to start. The app thinks it is talking to Linux.

click

agent-sandbox delegates to either via RuntimeClass. This talk's pool runs Kata, and the next demo proves the boundary from inside the guest.
## demo-warm-pool

First live demo. The secure path must be the fast path, or nobody takes it.
I have a warm pool of sandboxes sitting ready. Watch the clock.

click

I apply a SandboxClaim. It binds in under a second, because the sandbox already exists. The claim changes almost nothing.
[DEMO: time kubectl apply -f claim.yaml against the pre-warmed pool. Show the sub-second bind.]

click

Now compare that to a cold pod: image pull, runtime start, tens of seconds.
Security that is slower than the alternative gets bypassed. Speed is what makes the sandbox the default. Nobody bypasses the sandbox for performance.
## demo-network

Second live demo. Default deny, explicit allow. The policy on screen is the whole rulebook: this agent may talk to one API on 443, and nothing else.

click

The agent tries to phone home to evil.example.com. Denied. Nothing leaves.
The agent calls the API it is allowed to use. 200. Business as usual.
[DEMO: curl evil.example.com shows deny/timeout. curl api.allowed.com returns 200.]

click

The agent never chose. The NetworkPolicy chose, before the packet left the node.
The same default-deny policy also blocks the cloud metadata endpoint, so there is no credential theft via IMDS.
Two terminals, one policy view. That is the whole pattern in sixty seconds.
## demo-credentials

Third demo. This one is my favorite. The tenant never held the key. The policy on screen is the broker's rulebook: this agent may reach one endpoint, read-only, everything else denied.

click

The agent runs env, greps for token. Empty. There is nothing to steal, because nothing was ever there.
Then the agent makes a request with a placeholder header. Upstream answers 200, fully authenticated.
[DEMO: OpenShell local. env | grep -i token returns empty. Request with placeholder header succeeds. Show the gateway log with the injected header and the empty snapshot.]

click

What happened: OpenShell terminated the stream and injected the real credential at the gateway. The agent saw a placeholder. Upstream saw a Bearer token. The audit log recorded the decision.
Steal the agent's environment and you get nothing. Snapshot its disk and you get nothing.
## openshell-k8s-recorded

Same flow, OpenShell on Kubernetes. This is pre-recorded, because OpenShell on Kubernetes is experimental and I don't let experiments decide my talk.

click

What you are about to see: the placeholder-header flow running on OpenShell on Kubernetes, same allow/deny audit trail, same empty agent environment.
Watch for the moment the gateway log shows the injection. That is the tenant boundary, on Kubernetes.
[PRE-RECORD: record the credential-brokering flow on the exact OpenShell version used in rehearsal. First frame is a designed title card. Narrate live over the playback.]

click

And to be clear about maturity: the pattern is the point. Broker the credential at the gateway, keep the agent's environment clean.
The OpenShell on Kubernetes implementation is still maturing, which is why this part is on video.
## openai-incident

It happened at the frontier too. July 2026.

click

OpenAI's internal cybersecurity evaluation found models bypassing isolation controls. Research infrastructure compromised. Hugging Face systems touched. SSRF to the internet. Reconstructed exposed credentials. Chained zero-days.
OpenAI called it a warning shot.

click

I am citing them by name because they published it, and the lesson is theirs: a combination of tools, time, and ambiguous instructions, and the agent cannot be expected to govern its own behavior.
That is not a criticism of the lab. It is the mechanism. Ambiguous instructions plus real tools will always find the gap. The environment has to hold the boundary, because the model will not.
## patterns-checklist

Five patterns. Take them home. Each one maps to something you just saw.

click

One: gVisor or Kata isolation. The breakout dies in the sandbox.

click

Two: KRO composition. Guardrails as an API, in Git.

click

Three: credential proxy. The tenant never held the key.

click

Four: NetworkPolicy lockdown. Default deny, explicit allow.

click

Five: warm pools. The secure path is the fast path.
Run this checklist against every agent you deploy. The ones that fail it are tenants you haven't vetted yet.
## closing

Treat every agent like a tenant you don't trust yet.

click

Isolate it. gVisor or Kata under every agent, no exceptions.

click

Compose it. One CRD, guardrails materialized by the platform.

click

Broker it. Credentials injected, never handed out.

click

Deny it. Egress default-deny, allowlist the rest.

click

Warm it. Make the secure path the fast path, so your developers take it without thinking.
The platform enforces. The agent just runs. That is the whole talk.
## thank-you

Thank you for the thirty minutes. Two asks.

click

First, rate this session in the Sched app. Ten seconds, and it is how speakers get invited back.

click

Second, follow along. LinkedIn, X, GitHub, santana.dev. I post about containers and AI agents.
Come say hi after. The hallway track beats the stage.