# Case study candidate: DIVD breached via chained Zammad zero-days (Sep 2026)

Status: fact-note only, not yet drafted into talk copy. Awaiting Carlos's call on whether to use it.

- Victim: DIVD (Dutch nonprofit of volunteer vuln researchers; DIVD case DIVD-2026-00015).
- Flaws: CVE-2026-102489 (session fixation, session hijack to RCE as the `zammad` service user) and
  CVE-2026-102490 (improper privilege management, `zammad` user to root), CVSS 9.4 both.
- Attack path: chained through DIVD's own internal Zammad helpdesk on Sep 21, session to root in seconds.
- AI angle: DIVD said the speed was linked to an AI agent that autonomously handled portions of the attack
  chain. Attribute this to DIVD; not independently verified per one source.
- CISA added both to Known Exploited Vulnerabilities on Oct 2, 2026.
- Version caveat: DIVD lists 6.3.0-6.5.4 (RCE) and 1.5.0-7.1.0-alpha (privesc); Zammad narrows the first
  flaw to 6.5 and older, says 7.0+ not affected. Use Zammad's range in any public copy.
- Do NOT claim a federal Oct 5 remediation deadline; unverified.
- Talk framing: offense-side exhibit for the containment thesis ("agents as untrusted tenants" cuts both ways).

Sources: https://securityaffairs.com/200248/security/u-s-cisa-adds-zammad-gmbh-zammad-flaws-to-its-known-exploited-vulnerabilities-catalog.html
         https://www.cisa.gov/news-events/alerts/2026/10/02/cisa-adds-two-known-exploited-vulnerabilities-catalog
