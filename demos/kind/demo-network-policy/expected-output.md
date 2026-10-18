# NetworkPolicy demo expected output
#
# Before the policy:
#   curl http://api-allowed/  ->  ok
#
# After the policy:
#   curl http://api-allowed/  ->  ok        (explicit allow)
#   curl http://example.com    ->  timeout   (default deny; no rule matches)
#
# The line for the room: "Default deny, explicit allow. The agent doesn't
# choose where it goes. The platform decides, per destination, before the
# packet leaves."
#
# If the external curl still succeeds after the policy, Calico is not
# enforcing yet: wait longer, or check `kubectl get pods -n calico-system`.
