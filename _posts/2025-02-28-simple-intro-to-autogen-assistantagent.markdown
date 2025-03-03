---
layout: post
title: Simple Intro to AutoGen AssistantAgent
modified:
categories: ai
comments: true
tags: [ai, inference, agentic, agents, autogen, frameworks]
image:
  feature:
date: 2025-02-28T15:07:07-07:00
---

Recently, I've been [building AI agents](https://www.anthropic.com/research/building-effective-agents) to help automate some parts of my workflow such as deep, meaningful technical research to contribute to technical material that I build. I am using the [AutoGen framework](https://microsoft.github.io/autogen/stable/index.html) from [Microsoft](https://github.com/microsoft/autogen) and I realized if you're new to agentic systems/workflows (like I was), it might be useful to share some of my learnings. This is not intended to be a "comprehensive overview" of AutoGen, please see the [offical docs](https://microsoft.github.io/autogen/stable/index.html) (or the source code!) for that. What I wanted to cover is the mental model to use when building with AutoGen, specifically the [AssistantAgent](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/agents.html) part of the AgentChat framework. 

### AssistantAgent

[AssistantAgent](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/agents.html) tries to cover the most common usecases when building an agentic system: an AI agent that chats with an LLM using "tools", and iterate to work on a problem (or set of problems). The first part of the mental model that would have helped me when getting started is this:

"The AssistantAgent is really just a simple wrapper around chatting with an LLM using tools". When I first approached the AssistantAgent, I was thinking "How can I get it to do x, y, z through configuration or code." It took me a little to realize, that's not how to use it. There's not much to configure. It's actually quite simple. 

I wanted to use AutoGen agents ([and teams](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/teams.html)) to help me research  technical topics by scraping the web, digesting the contents, summarizing it, and then generating some ideas. I started by using the AutoGen teams feature and using multiple agents. This got complicated and overwhelming quite quickly, especially as someone new to agents. And on top of it, the results I was getting was mostly garbage. It was not useful. I needed to start smaller, tune, and move on.

So I had to take a step back and think in terms of building blocks. But as a former programmer, I would tend to think too imperatively: how can I configure/program the agent to do X. That's the wrong way to think about it. If you're going to build agents at all, you need to think more along the lines of "what am I trying to solve, and should I leverage an LLM to figure out how to solve this problem." If you don't need an LLM to help think through how to solve a problem, you probably don't need to build an agent. 


> When researching topic <X>, come up with varying google search queries to help research focusing on technical use cases or case studies, avoiding marketing material. 


This is dead simple. Use the LLM's ability to generate text, in this case to brainstorm through various google search queries, and put that to work to help me try different google queries. We can pass in a tool that executes the search queries and ask the LLM to use it. And move on from there. Start simple, get that working, and move on. 

### The Agent Flow

AssistantAgent like I said is actually very simple. It just takes a message (that ends up being the prompt) through the `on_messages()` function and returns a response. 


![](/images/autogen-assistant/visual.png)

The AssistantAgent basically takes a [ChatMessage](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/messages.html) (ie, to give it a prompt to use, you send in a TextMessage), it sends the message to the LLM and gets a response. From this response, the LLM may choose to invoke a tool. The Agent then invokes the tool that the LLM requested. Then it returns the tool's response to the caller of the agent. Alternatively, it can call the LLM back with the tool's response. It adds the original prompt and the tool call responses to its local context. Each agent has _its own message history/context_. It sends this context each time it calls the LLM. So that means, for the agent to call the LLM again, it will need to get another ChatMessage. You can do this programatically yourself (calling on_messages() again), or include your agent as part of a team that can take multiple turns. See the diagram above. 


### That's it

That's it for now. As I start getting better mental models of building agentic teams I'll share that here!


