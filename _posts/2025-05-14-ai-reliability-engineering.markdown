---
layout: post
title: AI Reliability Engineering (AIRE) - Creating Dependable Humans
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-05-14T08:49:23-07:00
---

It's a little after 5p, and I'm about to wrap up for the day. As I'm starting to shut things down, I get a message from my boss:

> Jeff and Lisa are looking into some issues, the mortgage team is complaining about something, can you jump on?

Uh oh. 

So I jump into a slack channel where a number of my teammates are talking about an issue... one of the alerting dashboards is lighting up. Then we get another message from our boss:


![There is a massive outage for Mortgage. All residential applications are stopped. Everyone jump on the bridge I just opened ASAP.](/images/aire/quote.png)


CRAP. 

Is this related to something I did? I work on the risk screening application which is used somewhere in the graph for Mortgage. This might make myself and boss look bad. UGH! Hopefully it's something else!! Damn, and I am supposed to drive soccer carpool tonight for my daughter, while my wife is with our other child. They are both going to be upset. 

Am I about to disappoint a lot of people?

![](/images/aire/textmsg.png)

---

Site Reliability Engineering (SRE) is an extremely stressful job. We know all too well how the scenario above goes. You jump onto the bridge with about 40 other people. Everyone’s working on their own corner of the system. Hunting through logs, metrics, and trace data, trying to find the needle in the haystack. Hypothesis after hypothesis, trial and error, access issues, and red herrings. Frustration and anxiety couldn't be higher. 

After about four hours, and a lot of dead ends, the team finally isolates the root cause: a routine certificate rotation failed to propagate to a few critical services. 

Brutal. 

It wasn't you this time, you dodged that one, but your family is pretty upset. 

How did this happen? Your team has invested so much in automation, you have very detailed run books, and a very strong SRE team. But it still took hours to triage, troubleshoot and diagnose the issue. The more complex our systems become, the more teams delivering software, the more difficult it becomes for humans to keep up with the volume of signals and constant change that happens. 







## AI Reliability Engineering

**AI Reliability Engineering (AIRE)** is the discipline of enhancing software reliability by [embedding AI agents](https://www.youtube.com/watch?v=afeKDUU0ZXI) that are context-aware, situationally intelligent, and deeply integrated into modern platform engineering workflows. Unlike brittle automation that breaks when the environment shifts even slightly, [AIRE is about supporting resilient](https://cleric.ai/blog/what-is-an-ai-sre), adaptive systems. It brings together the practices of platform engineering (think GitOps, CI/CD, Infrastructure as Code) with the reasoning and adaptability of modern AI. The result? [AI agents that don’t just automate tasks](https://kagent.dev), they [understand your systems and workflows](https://grafana.com/blog/2025/05/07/llm-grafana-assistant/) and [work alongside you to accomplish SRE](https://www.solo.io/blog/bringing-agentic-ai-to-kubernetes-contributing-kagent-to-cncf). 

These agents observe what’s happening across your architecture, correlate events across time and space (e.g., deployments, configuration changes, etc), access tribal knowledge encoded in your runbooks and codebase, and propose (and in the future, execute) changes that align with your standards. Imagine a team of interns, maybe not as knowledgeable as you, that can run down various hypotheses for you and quickly narrow the search field down to help pinpoint issues. But SRE doesn't only deal with incidents and trouble shooting issues. Onboarding services, establishing SLOs, promotion of releases through complex environments, etc can all be improved with AIRE.  

Now imagine a different outcome to the above scenario.

---

As the alerts start flooding in, I jump to our AIRE dashboard. I type in 

> "Help invtigate mortgag app failures," 

(misspellings because I'm a little frazzled of course).

I watch as it gathers the initial situational awareness: 

<blockquote>
Looking at logs, metrics, tracing.... <br>
Mortgage application services reporting 503 errors at 5:04 PM. <br>
Checking for recent deployments.... <br>
No deployments in the last 24 hours. <br>
No significant traffic spikes. CPU and memory utilization normal across all services.
</blockquote>

The agent begins formulating hypotheses right before my eyes:


<blockquote>
Based on previous incidents, I'm going to try to rule out database connection issues. <br>
Checking connection pools and database metrics...
</blockquote>

I see it pull query latency graphs, connection counts, and recent error logs.

<blockquote>
Database connectivity appears normal. <br>
Let me try to rule out network connectivity or partition issues. Checking network metrics between services...
</blockquote>

It displays packet loss ratios, DNS resolution times, and network flow diagrams.

<blockquote>
Network metrics within normal parameters. <br>
Let me try to rule out authentication and security issues. Checking auth logs and certificate status...
</blockquote>

I watch as the agent pulls certificate expiration dates, auth service logs, and visualizes a timeline of recent authentication attempts.

> Found potential issue: Authentication failures increasing across three specific services.

The agent zooms in, showing me correlations I would have taken hours to piece together:

* A graph showing failed authentication attempts spiking at exactly 5:01 PM
* Certificate logs showing a rotation job ran three days ago
* A timeline showing the previous certificate expired 17 minutes ago
* Configuration data showing three services still referencing the old certificate path

> High confidence (85%) root cause identified: Certificate rotation anomaly detected. Three services in the mortgage workflow are still using the previous certificate that expired 17 minutes ago. Authentication-proxy-7, payment-gateway-east, and mortgage-validation-service affected.

It presents me with a clear recommendation: 

> To alleviate downtime, you could force certificate propagation to the affected services. Estimated resolution time: 3 minutes.

I approve the recommendation with a single click. The agent executes the certificate refresh, verifies the new certs are properly loaded, and I watch as services begin responding normally.

**Total time: 8 minutes from alert to resolution.**

As I prepare to leave, the agent drafts a postmortem document noting that the rotation job's partial failure wasn't visible in our standard CI/CD pipeline dashboard. It suggests a new monitoring check and opens a ticket to modify the certificate rotation workflow to include validation steps.

Instead of panic, anxiety and long hours, I can relax and drive the soccer carpool listening to Taylor Swift and avoid any "do you know how difficult it is to juggle all these schedules!?!" from my lovely wife. 

To see this in real life, take a look at this quick demo (the AIRE part, not the carpool):

<iframe width="560" height="315" src="https://www.youtube.com/embed/Api7yz8w_Qk?si=mB3KB_0mBZMLBBoX" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>


## Condition Drift: Why Traditional Automation is brittle

Automation has always been part of the SRE toolbox. But let’s be honest: most automation is brittle.

It’s a series of hardcoded steps: If X, then Y. That works fine in static environments with predictable failure modes and somehow predicting all possible conditions that can occur. But modern systems aren’t static. They’re constantly evolving. Code changes daily, services scale up and down, infrastructure is redefined on the fly.

Automation doesn't know when your service graph changes. It doesn’t remember that an incident three months ago involved the same symptoms but a different root cause. It doesn’t understand why you’d do A instead of B in a specific context. So when conditions drift, and they always do, the scripts fall apart, or worse, make things worse.

Traditional automation doesn’t fail because it’s wrong, it fails because it lacks situational awareness.





## Context Is What Makes AIRE Different


AI Reliability Engineering (AIRE) flips the automation script (sorry... pun intended tho). It doesn’t just respond: it **understands**. And that understanding comes from three essential layers of **context**:

#### Temporal Context
This is time-based intuition. The agent recognizes that error rates spike every Thursday afternoon after a big batch job runs. It connects current symptoms to past events. It sees that this exact pattern occurred three months ago and was resolved by throttling a dependency. Time, history, and incident patterns are all part of the model.

#### System Context
This is the structural awareness: which services talk to which, what their dependencies are, what the typical error patterns look like, and how traffic flows through your system. It knows that the checkout service relies on the inventory service, which in turn has a fragile dependency on a third-party API you’ve cursed a thousand times.

#### Knowledge Context
This is your institutional memory: runbooks, previous incident retrospectives, internal documentation, team ownership mappings. AI agents trained on this corpus don’t just see logs—they understand what they mean in the context of your specific business logic and past decisions.

When these layers combine, AI agents don’t just do things. They make informed, situation-aware recommendations and actions. That's AIRE. 



## The Hidden Enabler: Platform Engineering

For those organizations that have invested heavily in Platform Engineering efforts, you're in luck. You don’t need to reinvent your infrastructure to make this work. In fact, the best foundation for context-aware AI isn’t some futuristic stack—it’s the modern platform engineering practices many teams are already using.

* **GitOps** ensures all changes to your system—infra or app—are declarative, versioned, and auditable. This is perfect for AI agents: every action they propose can be tracked, reviewed, and rolled back if necessary.
* **CI/CD** pipelines create a structured path from code to production. When an agent opens a pull request or proposes a config change, it doesn’t go rogue. It flows through your normal process.
* **Infrastructure as Code (IaC)** provides APIs for managing systems. Instead of shelling into servers, agents interact with Terraform, Helm, or Kubernetes manifests, ensuring changes are consistent and safe.
* **Service catalogs** and ownership metadata help AI understand system boundaries, team responsibilities, and escalation paths.
* **Observability platforms** metrics, logs, traces—are the lifeblood of AI situational awareness. This is where the signal lives. Combined with context, it becomes understanding.

In other words, AI Reliability Engineering isn’t a bolt-on. It’s an evolution of platform engineering, powered by context and grounded in the safe, proven workflows you already use.




## SRE is More than Just Incident Response

This isn’t limited to just incident response. Although incident response might be the most emotional, context-aware AI agents can enhance reliability across the entire ambit of SRE functions:

* **Incident Response**: As we saw, agents can triage, correlate, and even mitigate incidents in real time.
* **Root Cause Analysis**: By connecting current anomalies to historical patterns, agents can suggest likely causes within seconds.
* **Service Onboarding**: New microservice? The agent can generate baseline monitors, alert thresholds, runbooks, and even policy-as-code templates based on similar services in your environment.
* **Deployment Promotion**: Agents can assess rollout health, analyze canary metrics, and determine when it's safe to promote—without waiting for a human to comb through dashboards.
* **Proactive Anomaly Detection**: Not just reacting to thresholds, but detecting subtle drifts or early warning signs based on past incidents.
In each case, the value comes not from brute force, but from informed, contextual decision-making.




## A Critical Part of the AIRE flywheel: Humans

This isn't about replacing humans. A lot of the "give up software engineers, it's over!" is complete nonsense. This is about **unleashing humans**. 

Let me say louder for those of you in the back row who are barely paying attention: **"This is about making humans SUPER HUMAN!"**

While AI excels at processing vast datasets, correlating signals, and suggesting remediations at machine speed, **humans bring the irreplaceable gifts of intuition, judgment, and creative problem-solving to the table**. 

Together, they form a **reliability partnership greater than the sum of its parts**: the AI's tireless focus frees engineers from alert fatigue, its pattern recognition amplifies human decision-making, and its documentation capabilities preserve institutional knowledge across team transitions. 

The result? 

Engineers focus on designing resilient systems rather than firefighting, complex incidents resolve in minutes instead of hours, and yes SREs make it to family obligations without sacrificing service quality. This powerful symbiosis doesn't diminish the human element in reliability engineering -— it reclaims it, creating space for the uniquely human work of innovation, mentorship, and strategic thinking that no algorithm can replicate.


## The Future we Want: Dependable Humans

Let’s be real: incidents don’t just impact systems, they impact people. You, the human in the loop, juggling priorities, fielding alerts with one hand while texting “I’ll be late” with the other. Maybe you're driving carpool to your kid’s soccer game. Maybe your partner’s already handling the other practice. And just when you're about to exhale, the pager goes off.

It’s not just frustrating, it’s deflating. You want to be reliable for your team, but also present for your family. And right now, it feels like a zero-sum game.

But here’s the real promise of AI Reliability Engineering: it helps you be there for both.

The AI-human relationship we’re building here isn’t about replacement, it’s about reinforcement. It’s like a good teammate: one that never sleeps, learns fast, and steps in with context when you need a breather. And over time, that partnership becomes symbiotic. It gets smarter. You trust it more. And when your partner or kids hear "SRE" they'll feel like it means "Soccer Reliability and Everything (that really matters)" and not "Suddenly Ruining Evenings".

