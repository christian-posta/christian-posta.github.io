# Repository Instructions

## Christian Posta Blog Voice Memory

When writing or editing posts in `_posts/`, prefer Christian Posta's existing blog voice. This is especially important for AI agents, identity, authorization, API, MCP, service mesh, DevOps, and enterprise architecture posts.

Voice anchors:

- Start from a concrete enterprise/engineering problem, a customer pattern, a spec frustration, or a real conversation. Avoid opening with a polished abstract thesis unless the post already has one.
- Be direct and opinionated, but pragmatic. Christian often says where an approach works first, then where it breaks in enterprise reality.
- Use first person naturally: "I've been digging into...", "I think...", "I'm not sure yet...", "what I'm seeing...", "the more I think about this...".
- Use rhetorical questions to move the argument forward: "What does this even look like?", "So who is responsible?", "Can we just...?", "Where does this break?"
- Keep paragraph cadence close to Christian's posts: normal explanatory paragraphs with multiple related sentences. Do not create a stack of single-sentence paragraphs for emphasis. Use a standalone sentence only when it is genuinely a punchline, transition, or callout, not as the default rhythm.
- Prefer concrete enterprise examples over abstract categories: Kubernetes tokens, GitHub PATs, Salesforce, HubSpot, Snowflake, Slack, ServiceNow, Okta, Keycloak, SPIFFE, KMS, Vault, MCP servers, API gateways.
- Draw responsibility boundaries clearly. Christian often separates layers with "who holds what", "what problem are we solving", "what this buys us", "where it breaks", and "what should we do today".
- Include technical specifics: protocol names, claim/token behavior, config snippets, YAML/JSON, sequence diagrams, security properties, failure modes, and operational tradeoffs.
- Use concise bullets when enumerating risks, requirements, or patterns, but explain the important ones in prose afterward.
- Use casual emphasis where appropriate: "not great", "that's the part people miss", "read that again", "not the world we live in", "this is a non-starter", "this works great when...", "in practice, this is a disaster".
- Conclusions should make a recommendation or state the main point plainly. Do not end with a generic summary.

Avoid:

- Bland AI-model prose like "the architectural direction is compelling", "this highlights the importance of", "in modern systems", or "it is crucial to".
- Over-balanced essay structure that caveats every claim before making it.
- Paragraphs made of one sentence after another with blank lines between them. This reads like AI-generated LinkedIn prose and does not match the blog.
- Generic split-responsibility abstractions unless tied immediately to an example, a protocol, or an operational consequence.
- Slogans that sound detached from implementation. If using a memorable line, support it with concrete mechanics.
- Perfectly symmetrical lists and polished corporate transitions. Christian's strongest posts read like technical thinking out loud, not marketing copy.
- Making the post sound more certain than the source material supports. If a standard, product, or pattern is early, say that plainly.

Before rewriting a Christian Posta post:

1. Identify the concrete problem or conversation that should lead the post.
2. State the claim more directly than a generic essay would.
3. Add the enterprise reality check: where the obvious answer breaks.
4. Add implementation shape: who owns what, where credentials/state/policy live, what is enforced, and what can fail.
5. Preserve informality and first-person reasoning, while still fixing obvious typos and clarity issues.
