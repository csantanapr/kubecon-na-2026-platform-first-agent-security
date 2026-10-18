# OpenShell credential brokering - what the laptop agent needs to know
#
# OpenShell is a standalone gateway binary (https://github.com/NVIDIA/OpenShell),
# not a Kubernetes controller. The talk's live demo runs the binary locally:
#
#   env | grep -i token        # empty: the agent never held the key
#   curl -H "Authorization: placeholder" https://api/   # 200, upstream authenticated
#
# The gateway terminates the stream, injects the real credential, and writes
# the decision to the audit log. That local flow works on any machine with the
# binary and needs no cluster at all.
#
# The on-Kubernetes deployment from the talk's recorded beat is experimental,
# which is why the talk keeps it on video. If you want to try it, start from
# the OpenShell repo releases and the policy shape below.
#
# Fields per OpenShell repo examples. Deny-by-default per security-policy.md.
# No matching rule = deny.
version: 1
network_policies:
  agent-net:
    name: agent-network
    endpoints:
      - host: api.allowed.com
        port: 443
        protocol: rest
    enforcement: enforce
    access: read-only
