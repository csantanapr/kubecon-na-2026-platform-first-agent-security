# Screenplay - Platform-First AI Agent Security

30 minutes, Security track, any level. Thesis: agents are untrusted tenants.
The platform, not the agent, enforces security.
Timings come from the rehearsal cut (narrated at a measured pace, 27:15 total, with estimated timings for the new kro, Cedar and CNCF slides);
a live delivery runs a little slower, and the rest of the 30 minutes is buffer and Q&A.
"Clicks" = staged reveal steps. Demos run live on EKS (slide 9 runs on kind) with the `isolated-sandbox`
RuntimeClass (AWS Nitro Sandbox); each demo slide has a terminal replay of the live run
(press T on the slide; → next command, Esc close).
Isolation wording: gVisor is soft isolation, Kata is virtualization, AWS Nitro Sandbox
is hardware isolation.

## Slide 1 - Platform-First AI Agent Security: Zero-Trust Patterns for Kubernetes (~1:13)

**Say:** Welcome. Come in, grab a seat, there is room up front. The title is the
whole talk in one line: zero-trust patterns for AI agents, running on
Kubernetes. If you take one idea home tonight, it is that your platform, not
your model, is where agent security actually lives.

**Click 1:** My name is Carlos Santana. I am a containers specialist at AWS, and
a CNCF Ambassador. I spend my days helping teams run untrusted workloads safely
on Kubernetes, and for the last year that has meant one new kind of workload
more than any other: AI agents. Thirty minutes on one idea. Your AI agents are
tenants on your platform, and right now most of them are tenants you never
vetted. They have credentials you handed them, network access you never scoped,
and a filesystem they share with everything else. We would never run a
customer's code that way. We are running our agents that way. I will show you
the platform patterns that change that, and I will show them with live demos on
a real EKS cluster. Nothing here is slides-only. When I claim the platform holds
the boundary, you are going to watch it hold.

## Slide 2 - An AI agent helped break in. (~1:23)

**Say:** Let me start with a story, because this stopped being theoretical this
year. An AI agent helped break in. September twenty-first, twenty twenty-six.
DIVD, the Dutch volunteer vulnerability research nonprofit, the people who find
and report vulnerabilities for a living, got breached.

**Click 1:** Here is the chain. Two Zammad zero-days, chained. Session fixation
that got the attacker a foothold as the zammad user, then a privilege escalation
to root. Both rated CVSS nine point four, critical. CISA put them on the Known
Exploited Vulnerabilities list on October second, which means they were being
used in the wild against real targets. Here is the part that matters for this
room. DIVD attributed part of the attack chain's speed to an AI agent,
autonomously handling portions of the attack. Not a human running a script. An
agent, deciding and acting, faster than a human incident responder could keep
up.

**Click 2:** So keep this frame for the next half hour. Tonight, the agent is
the attacker. The platform is the defense. We are not going to make the agent
trustworthy, because we cannot. We are going to build an environment that stays
safe even when the thing inside it is not. We are coming back to this.

## Slide 3 - Treat every agent like a tenant you don't trust yet. (~1:10)

**Say:** Look at the image. Agents, each one in its own box. That picture is the
whole talk in one sentence.

**Click 1:** Treat every agent like a tenant you do not trust yet. Not because
agents are evil. Because they are powerful, they are autonomous, and they take
ambiguous instructions in natural language, and that combination cannot govern
itself. You can prompt an agent to be careful. You cannot prove it will be. The
moment it has a real tool, real time, and a fuzzy goal, it will find the gap,
the same way a junior engineer with production access and no guardrails
eventually will, except the agent does it in seconds and at scale. You already
know how to handle a tenant you do not trust. Kubernetes was built for exactly
this. Multi-tenancy, isolation, policy, quotas: this is the oldest problem in
our field and we have good answers. We are just going to aim those answers at
agents instead of at other people's microservices. Nothing I show you tonight is
a new primitive. It is the platform you already run, pointed at a new kind of
tenant.

## Slide 4 - A tenant gets three things. (~1:43)

**Say:** So what does a tenant actually get? When you onboard an untrusted
tenant onto a platform, you give them three things, and you withhold a fourth.
An agent should get exactly the same deal.

**Click 1:** One: identity. Every agent is somebody. A verifiable identity the
platform issued and can revoke, not a string the agent claims about itself in a
header. If the only thing standing between your agent and your database is a
bearer token the agent can read out of its own environment, you do not have
identity. You have a password taped under the keyboard.

**Click 2:** Two: policy. What the agent may touch, written down, and enforced
outside the agent. A real policy object the platform evaluates, not a paragraph
in a system prompt that says "please only call these APIs." The prompt is a
suggestion. The policy is a wall. When they disagree, the wall wins, and the
agent never gets a vote.

**Click 3:** Three: no ambient authority. Nothing by default. No cloud
credentials sitting in environment variables. No open egress to the whole
internet. No shared filesystem with the host or with other tenants. Everything
the agent can do is something you explicitly granted, and everything else is
denied before the agent even asks. If your agent is missing any one of those
three, you do not have a tenant. You have a guest with the run of the building,
a master key, and nobody watching the cameras. The rest of this talk is how the
platform delivers all three, automatically, for every agent, without a human
hand-writing YAML each time.

## Slide 5 - Guardrails as an API. (~1:32 est.)

**Say:** Here is the first problem you hit in practice. Identity, policy, no
ambient authority: per agent, that is a sandbox, an egress rule, an identity, a
quota, a model credential. Hand-write that for one agent and it is an afternoon.
For fifty agents across a dozen teams it is a full-time job nobody does
correctly. The guardrails rot. So we do not hand-write it.

**Click 1:** Instead, one Custom Resource. I call it AgentWorkload. Look at what
the developer writes: a prompt, and the one API this agent is allowed to call.
That is it. No runtime class, no worker pool, no network rule, no model key.
They declare intent, in Git, reviewed like any other change, and they move on.

**Click 2:** Then kro, the Kube Resource Orchestrator, turns that one object
into real kagent objects. kagent just shipped 1.0, and it runs every agent on
Agent Substrate. So one AgentWorkload becomes an EgressPolicy that is default
deny with exactly one origin, an AgentTemplate with the prompt and a model the
platform shares, an Agent pinned to the platform's Harness, and a tools sandbox
with the same egress. The developer wrote one thing. The platform produced the
rest. That is guardrails as an API. And the part that matters long term: agent
frameworks change every quarter. This interface does not have to. You version
the composition, not every team's YAML.

## Slide 6 - The platform team's half. (~1:26 est.)

**Say:** That was the developer's half. This is the platform team's half: the
kro ResourceGraphDefinition behind AgentWorkload. This is the real file from the
demo you can run tonight.

**Click 1:** It starts with the schema. The platform team decides the shape of
the API: a required prompt, and a list of allowed origins that defaults to
empty. Empty means no extra egress at all. Safe by default is not a slogan here;
it is the default value in a schema. And the status rolls everything underneath
into one ready field, so the developer has one thing to watch.

**Click 2:** Then the resources. The EgressPolicy maps each allowed origin into
a destination; everything else is denied. The AgentTemplate takes the prompt and
points at a shared model the platform owns, so no team ever holds a model key.
And the Agent always uses the secure-default Harness. Developers cannot pick a
different runtime, because kagent only resolves a Harness in the agent's own
namespace, and RBAC keeps creating Harnesses with the platform team.

**Click 3:** So the platform team writes this once. Every agent inherits it. The
security does not depend on the least careful developer on your worst day. It
depends on one composition, written once, by the people whose job it is to get
it right.

## Slide 7 - One label onboards a team. (~1:10 est.)

**Say:** But where does that secure-default Harness come from? Who gives a team
its sandboxed runtime in the first place? That is the second half of kro, and it
is new: kro 0.10 shipped two days ago with a Graph API.

**Click 1:** A Graph has no schema and no instances. It is the resources. This
one reads every namespace with one label, and for each of them stamps out an
Agent Substrate WorkerPool on gVisor. The same pattern adds the Harness, a
ServiceAccount for the workers, and a quota.

**Click 2:** So onboarding a team is one label. Label team-a, and it gets a
gVisor worker pool, the kagent Harness that points at it, an identity for its
workers, and a quota of five agents. Remove the label, and kro prunes all of it.

**Click 3:** And here is the security detail I love. kro applies a Graph while
impersonating a ServiceAccount in the Graph's namespace. Every create and delete
is checked against that ServiceAccount's RBAC. The automation that builds your
guardrails runs with least privilege too.

## Slide 8 - kro on top. The agent platform underneath. (~1:09 est.)

**Say:** Let me put the layers together, bottom up, because this is the picture
to take home.

**Click 1:** At the bottom, isolation. gVisor on any cluster, including your
laptop. MicroVMs where you have KVM. AWS Nitro Sandbox on EKS when you want
hardware-level isolation.

**Click 2:** On top of that, Agent Substrate. WorkerPools and sandbox classes,
and Actors: the running agents, with snapshots so they can suspend and resume.

**Click 3:** Then kagent 1.0. It turns an Agent, a template and a Harness into
Substrate Actors, and it adds the agent lifecycle: sessions, the A2A gateway,
and an egress gateway that can inject a credential without the agent ever seeing
it.

**Click 4:** And on top, kro. Not a replacement for any of this. kro does not
run agents. It is your platform's API: the Graph that onboards tenants and the
AgentWorkload that developers write.

**Click 5:** So you have two ways in. kro directly on Substrate gives you pools
and sandbox classes per team. kro on kagent gives you whole agents. In the demo,
it is both.

## Slide 9 - Try the whole stack on kind. (~0:52 est.)

**Say:** And you can run all of it tonight, on your laptop. kind, Kubernetes
1.37, kagent 1.0, kro 0.10. No cloud account.

**Click 1:** Three commands. The install script builds the cluster and the
platform. The run script does what you just saw: label a namespace, apply one
AgentWorkload, then open a tools sandbox and make two calls. [DEMO: on kind.
./run.sh, or press T for the replay.]

**Click 2:** Here is what comes back. The agent is Ready, compiled into a
Substrate Actor. Inside the sandbox, the kernel is gVisor. The one allowed API
answers two hundred. Anything else does not even resolve. And a namespace the
platform never onboarded cannot run the same agent at all: there is no Harness
for it. Three guardrails, and the developer wrote none of them.

## Slide 10 - Three kinds of sandbox. (~2:22)

**Say:** Now let us talk about isolation itself, because this is where a lot of
teams get the mental model wrong, and the differences really matter when the
tenant is hostile. There is not one kind of sandbox. There are three, and you
pick per workload, from lightest-and-fastest to the firmest boundary.

**Click 1:** First, gVisor. Soft isolation. gVisor is a userspace kernel: it
intercepts the container's system calls and services them itself, so the
application thinks it is talking to Linux but it is really talking to gVisor. No
virtual machine, so it is light and it starts fast. It shrinks the kernel attack
surface dramatically, which is a real win. But the boundary is still software
intercepting syscalls on a shared host kernel path, so you treat it as a strong
container, not as a wall.

**Click 2:** Second, Kata. Kata is virtualization. Each sandbox is a lightweight
virtual machine with its own guest kernel, behind a virtualization boundary.
That is a genuinely stronger boundary than gVisor: the agent is not sharing your
host kernel at all, it is in its own kernel inside a VM. Be precise about what
this is, though. Kata is virtualization, a software-defined virtual machine on
your host. It is not hardware isolation, and I want to be careful with that word
because the next one is.

**Click 3:** Third, AWS Nitro Sandbox. AWS Nitro Sandbox is hardware isolation,
through the isolated-sandbox RuntimeClass. This is the new runtime we are
launching for KubeCon, and it is the one the rest of this talk runs on. Here the
isolation boundary is enforced in hardware, not just by the host's software.
Even a full compromise inside the guest, root in the guest kernel, does not get
you the host, because the boundary is not a host software construct the attacker
can reach. This is hardware-level isolation, and it is the right default when
the tenant is an autonomous agent you genuinely do not trust.

**Click 4:** agent-sandbox, the Kubernetes SIG project, delegates to all three
of these through RuntimeClass. One Sandbox API, three boundaries, chosen per
workload. This talk's pool runs the hardware-isolated runtime, and the next demo
proves that boundary from inside the guest.

## Slide 11 - The secure path must be the fast path. (~1:40)

**Say:** First live demo, and it is a real EKS cluster, not a toy. The lesson
here is the one that decides whether any of this gets adopted: the secure path
has to be the fast path, or your developers route around it. If hardware
isolation means waiting thirty seconds for a microVM to boot every time, nobody
waits. They bypass you. So we do not make them wait.

**Click 1:** I keep a warm pool of hardware-isolated sandboxes sitting ready on
the isolated-sandbox runtime. Watch the clock. I apply a SandboxClaim, and it
binds in under a second, because the sandbox already exists. The claim does not
boot anything. It adopts a microVM that was already running, already isolated,
already warm. The developer asked for a secure sandbox and got one instantly.
**[DEMO: time kubectl apply -f claim.yaml against the pre-warmed pool on EKS.
Show the sub-second bind, the bound sandbox on runtimeClass isolated-sandbox,
and the guest's own kernel from inside.]**

**Click 2:** Now compare that to a cold start: provision the microVM, boot the
guest kernel, pull the image, tens of seconds, every time. That gap is exactly
where security dies in the real world. The team under deadline takes the fast,
insecure path, and your beautiful isolation story never ships. Warm pools close
the gap. The secure path becomes the fast path, so there is no reason to bypass
it. Nobody trades away hardware isolation to save thirty seconds, because the
warm pool already saved them the thirty seconds.

**Live on EKS:** warm pool of sandboxes on the `isolated-sandbox` RuntimeClass (AWS Nitro Sandbox). Show the sub-second bind, the bound sandbox's runtime class, and `uname -r` from inside the guest.
**Fallback:** press T for the full-screen terminal replay.

## Slide 12 - Default deny, explicit allow. (~1:58)

**Say:** Second live demo. Default deny, explicit allow, enforced by the
platform, in real time. The policy on screen is the entire rulebook for this
agent: it may talk to one API, and to DNS so it can find that API, and to
nothing else in the universe. Everything not on that list is denied before the
packet leaves the node.

**Click 1:** So I am the agent now. First I try to phone home, out to the open
internet, the way a compromised agent exfiltrates data or pulls a second-stage
payload. Denied. The connection never leaves. Then I call the one API that the
policy actually allows. Two hundred. Business as usual. Same agent, same network
stack, two completely different outcomes, and the agent had no say in either.
**[DEMO: live on EKS, VPC CNI enforcing NetworkPolicy. kubectl exec into the
agent: curl the allowed API returns ok, curl the open internet times out,
DENIED.]**

**Click 2:** The agent never chose where it could go. The NetworkPolicy chose,
and it chose before the packet ever left the node. And notice what this quietly
buys you: the same default-deny posture that blocks the open internet also
blocks the cloud metadata endpoint, the one an attacker loves because it hands
out credentials. No special rule for it. It is denied because everything is
denied unless you allowed it. That is the whole point of default-deny: you stop
enumerating the bad and start enumerating the good, and the list of good things
is short and reviewable. Two commands, one policy, sixty seconds, and the
agent's network is a locked room with one labeled door.

**Live on EKS:** the VPC CNI enforces NetworkPolicy, so no extra CNI install. Two curls from the agent pod: the allowed API returns ok, the open internet times out.
**Fallback:** press T for the full-screen terminal replay. Offline rehearsal on kind: demos/kind/demo-network-policy/run.sh (installs Calico).

## Slide 13 - The tenant never held the key. (~2:00)

**Say:** Third demo, and this is my favorite, because it kills an entire class
of attack. The tenant never held the key. Steal everything the agent has and you
still get nothing, because the thing worth stealing was never inside the
boundary. The policy on screen is the broker's rulebook: this agent may reach
one endpoint, read-only, and everything else is denied.

**Click 1:** So, live, I am the agent again, inside a hardware-isolated sandbox
created through the OpenShell gateway on Kubernetes. First thing an attacker
does on a new box: look for secrets. I run env, I grep for a token. Empty. There
is nothing there. The gateway confirms it from its side too: the sandbox was
provisioned with zero credentials in its environment. There is nothing to steal
because nothing was ever handed over. Then I make a request to the upstream the
policy allows. The agent sends a placeholder where the credential would go. The
request succeeds, fully authenticated, two hundred.
**[DEMO: OpenShell on EKS. openshell sandbox create, then exec env grep token
returns empty; the gateway reports zero provider env; the brokered request to
the allowed endpoint succeeds.]**

**Click 2:** Here is what actually happened. OpenShell terminated the agent's
connection at the supervisor, outside the workload boundary, and injected the
real credential there, at the gateway. The agent saw a placeholder. The upstream
saw a valid bearer token. The audit log recorded the decision, the endpoint, and
that the agent's own environment was empty the whole time. Steal the agent's
environment variables and you get a placeholder. Snapshot its disk and you get a
placeholder. The credential lived and died outside the tenant boundary, held by
the supervisor the agent can never reach. That is what "no ambient authority"
looks like when you actually mean it.

**Live on EKS:** OpenShell gateway on Kubernetes. `openshell sandbox create`, then `openshell sandbox exec ... env | grep -i token` returns nothing.
**Fallback:** press T for the full-screen terminal replay.

## Slide 14 - OpenShell on Kubernetes, in production. (~1:16)

**Say:** And I want to be clear about the maturity of this, because last year
this part of the talk would have been a video with an apology. Not anymore.
OpenShell on Kubernetes is a supported, production-shaped deployment today: a
Helm chart, integration with the agent-sandbox controller, high availability
with multiple gateway replicas, certificate management, and real authentication
through OIDC or an access proxy. What you just watched ran on it, live.

**Click 1:** So the pattern is not a research demo. It is the
credential-brokering architecture, running on the same Kubernetes you already
operate: the gateway and the supervisor outside the boundary holding the keys,
the agent inside the boundary holding nothing, and every decision written to an
audit trail. The security lives in the environment, not in the model and not in
the agent's good intentions.

**Click 2:** That is the whole credential story in one line. Broker the
credential at the gateway, keep the agent's environment clean, and log every
decision. The agent does its job with a placeholder, the platform does the
authentication, and the blast radius of a compromised agent drops to almost
nothing, because the agent was never holding anything worth taking.

No video on this slide any more: the flow ran live on the previous slide.

## Slide 15 - OpenShell is moving to Cedar. (~1:14 est.)

**Say:** One more thing about OpenShell, because it changed this week. Today an
OpenShell policy is YAML, and a Rego engine evaluates it. The project is moving
to Cedar, a policy language designed so that every policy stays open to
analysis. The CNCF announcement says it plainly: OpenShell is adopting Cedar as
its policy language.

**Click 1:** The design is one language per sandbox. You pick YAML or Cedar when
you create the sandbox, and a Cedar sandbox is decided by Cedar alone. No mixing
two engines in one decision path.

**Click 2:** And it gives the same answers. The proposal pairs YAML and Cedar
policies through both engines: 2,909 cases, they agree, and in the five that
differ Cedar is the stricter one. On screen is the same rule as our demo, in
Cedar: curl may read the GitHub API, GET, HEAD and OPTIONS only. This is in
review as RFC 0020, landing in development builds first, so try it, and send
feedback.

**Click 3:** And notice the pattern. OpenShell and Cedar are both CNCF projects,
building on each other. That is the theme of the whole stack.

## Slide 16 - It happened at the frontier too. (~1:17)

**Say:** If you think this is overkill, it happened at the frontier too, to
people who are very good at this. July twenty twenty-six.

**Click 1:** OpenAI's own internal cybersecurity evaluation found their models
bypassing isolation controls. Research infrastructure compromised. Hugging Face
systems touched. Server-side request forgery out to the internet. Exposed
credentials reconstructed from fragments. Zero-days chained together. This was
not an outside red team; this was their own evaluation of their own agents, and
OpenAI called it a warning shot.

**Click 2:** I am citing them by name because they published it, and because the
lesson is theirs to give and it is the thesis of this entire talk. A combination
of tools, time, and ambiguous instructions, and the agent cannot be expected to
govern its own behavior. That is not a knock on the lab or the model. It is the
mechanism. Ambiguous instructions plus real tools will always, eventually, find
the gap, because finding gaps is what capable optimizers do. So the environment
has to hold the boundary. The model will not, the prompt cannot, and hoping is
not a control. The platform is the control.

## Slide 17 - Built on CNCF projects. (~0:54 est.)

**Say:** Step back and look at what you saw tonight. From the platform API down
to the gVisor sandbox, it is all open source, and it all lives in the CNCF.
Kubernetes, containerd and Helm, the graduated foundation. kro, from Kubernetes
SIG Cloud Provider, for guardrails as an API. agent-sandbox, from SIG Apps, for
sandboxes and warm pools. And five sandbox projects that are brand new to many
of you: Agent Substrate for sandboxed Actors at scale, kagent for the agent
lifecycle, OpenShell for credential brokering, contributed by NVIDIA this week,
Cedar for policy you can analyze, and gVisor, the userspace kernel under the
agents in the kind demo, which Google just contributed too. No single vendor
owns the boundary around your agents. You can read every line of it, and you can
help build it.

## Slide 18 - Five patterns. Take them home. (~1:19)

**Say:** So here is what you take home. Five patterns, and every one of them
maps to something you just watched work on a live cluster.

**Click 1:** One: gVisor, Kata, or hardware isolation under every agent. Pick
the boundary that matches the threat, default to the strong one, and the
breakout dies in the sandbox instead of on your host.

**Click 2:** Two: KRO composition. Guardrails as an API, defined once, in Git,
inherited by every agent, so your security does not depend on anyone remembering
to ask for it.

**Click 3:** Three: the credential proxy. The tenant never holds the key. Broker
it at the gateway and a stolen agent is a stolen placeholder.

**Click 4:** Four: NetworkPolicy lockdown. Default deny, explicit allow, egress
included, so the agent's network is a locked room with one labeled door and the
metadata endpoint is shut without a special rule.

**Click 5:** Five: warm pools. Make the secure path the fast path, because a
control your developers route around is not a control. Run this checklist
against every agent you deploy. The ones that fail it are the tenants you have
not vetted yet, and now you know exactly what to fix.

## Slide 19 - Closing (~1:07)

**Say:** So let me bring it home. One sentence, five verbs. Treat every agent
like a tenant you do not trust yet.

**Click 1:** Isolate it. gVisor, Kata, or hardware isolation under every agent,
no exceptions, default to the strong boundary.

**Click 2:** Compose it. One CRD, guardrails materialized by the platform,
versioned like code, inherited by every agent.

**Click 3:** Broker it. Credentials injected at the gateway, never handed to the
tenant, every decision logged.

**Click 4:** Deny it. Egress default-deny, allowlist the few things it truly
needs, and the metadata endpoint closes itself.

**Click 5:** Warm it. Make the secure path the fast path, so your developers
take it without even thinking, because the safe choice is also the quick one.
The platform enforces. The agent just runs. The security does not live in the
model and it does not live in the prompt. It lives in the environment you build.
That is the whole talk.

## Slide 20 - Thank you. (~0:38)

**Say:** Thank you for the thirty minutes. Two quick asks before you go.

**Click 1:** First, please rate this session: scan the QR code on screen with
your phone camera. It takes ten seconds, and honestly it is how we speakers find out what landed and get invited
back to do it again.

**Click 2:** Second, come find me. LinkedIn, X, GitHub, and santana dot dev. I
post about containers and AI agents, I share the demos from this talk, and I
would genuinely love to hear what you are building and what is breaking. The
hallway track beats the stage every time, so let us keep talking out there.
Thank you.
