---
layout: page
icon: fas fa-key
order: 2
title: Credential Brokering
permalink: /credential-brokering/
---

# Credential Brokering Series

How to keep **credentials out of the agent's hands** when it calls GitHub, Slack, Salesforce, etc,
and then how to keep the broker that holds them from becoming the new single point of failure.
The series follows the [CB4A draft](/credential-brokering-patterns-for-ai-agent-egress/) and
builds each pattern in agentgateway.

- [Part 1: Don't Give the Agent the Keys →](/credential-brokering-patterns-for-ai-agent-egress/)
  The CB4A draft, why the proxy model is the one that actually works against today's
  bearer-token APIs, and how we build it in agentgateway.
- [Part 2: Protecting the Token Vault with AWS KMS →](/credential-brokering-patterns-for-ai-agent-egress-part2/)
  A broker concentrates credentials somewhere else, so this is how we keep that concentration
  from becoming a single point of total failure with broker-gated envelope encryption on KMS.
- [Part 2.5: Where KMS Grants Stop Scaling →](/credential-brokering-mode-3-at-scale/)
  The KMS grant quota caps Mode 3 at 50 exchanges a second, so here's the variant that scales,
  and the component that makes what leaks worth less.
- [Part 3: Protecting the Token Vault with OpenBao →](/credential-brokering-patterns-for-ai-agent-egress-part3/)
  Two ways to run Mode 3 on OpenBao when you can't or won't put the key in a hyperscaler, side by
  side, and how I'd pick between them.
- **Part 4 (coming soon).** If the gateway itself gets compromised, what's the blast radius,
  and can we make that the blast radius for everything?
