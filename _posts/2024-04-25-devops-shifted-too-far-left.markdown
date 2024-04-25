---
layout: post
title: "Don't get hit with the pendulum: DevOps shifted too far left"
modified:
categories: 
comments: true
tags: [platform engineering, kubernetes, networking, devops]
image:
  feature:
date: 2024-04-25T10:37:20-07:00
---


You probably wouldn't be surprised if I told you modern networking based on open source projects like [Istio](https://istio.io), [SPIFFE](https://spiffe.io), [Cilium](https://cilium.io) and others ([See my paper about the CAKES stack](https://www.infoworld.com/article/3715061/better-application-networking-and-security-with-cakes.html)) are typically consumed by what we now call "platform engineering" teams. You've probably heard the term platform engineering or seen some nice write-ups on it ([like the one from my industry colleague](https://thenewstack.io/platform-engineering/platform-engineering-infrastructure-meets-dev-experience/) [Daniel Bryant](https://twitter.com/danielbryantuk)). 

![](/images/devops-left/pend.png)

At [Solo.io](https://solo.io) working with our partners and customers, we get to see some of the important details about how platform engineering teams emerge, how they get funded, how they work with other parts of the organization and some of the opportunities and [challenges they've run into](https://blog.christianposta.com/does-platform-engineering-solve-the-people-problem/). Through this, I've observed something worth saying out loud: just like other examples of large pendulum swings in our industry, DevOps has introduced a large swing in a direction that doesn't produce desired outcomes at large organizations: shifting too far left.

> What do I mean by DevOps shifting too far left?

Let's recall that DevOps is a movement that attempts to break down silos in IT organizations to improve delivery speed and quality of software. A lot of beneficial practices emerged from DevOps including a focus on automation, improving communication between teams, and trying to shift certain delivery activities "to the left", ie, closer to development. For example, introducing quality testing, vulnerability scanning, security testing, et. al. closer to the time code is built and tested instead of farther down the delivery pipeline (to the right). Accounting for these non-functional requirements closer to development creates a tighter feedback loop and reduces the cost of delivery because it's cheaper to correct any issues earlier in the delivery pipeline.

Shifting left has benefits as pointed out above. However, taken to the extreme, this shift left can be detrimental. 

> "You build it, you run it"

Another popular idea in the implementation of DevOps is application teams taking more responsibility for the code they ship. In principle, this is a great idea. In practice in some organizations, this has turned into "You build it.... like, everything, the code (pick whatever language you want!), the tests, the docker images, the Kubernetes clusters, CNIs, service mesh, the observability tooling, the integration with CI/CD, the api gateways, the ALBs/NLBs, databases, underlying VPCs, etc etc etc. And then you run all of that." 

Sounds like you should be running AWAY from all of that.

Not only have some organizations tried to turn their application delivery teams into "full stack app to infrastructure engineers", but they have told each of their teams/lines of business they are all responsible for doing this themselves. The "decentralization" enables each team/LOB to "go faster".

In practice, this is a disaster. A very very very expensive, disaster. And no, you go slower.

We've seen this scenario quite a few times and they kind of go like this:

Some executive declares "we're doing DevOps now" and going all in on the Cloud. They start handing out AWS developer accounts like candy and each team is off and running. Initially each team feels liberated; they get to do whatever they want. Then they quickly realize there's actually a lot to do for the "you run it part" when there are no established best practices, tooling, and they don't have the experience on the team. They fumble a bit, try some things, fail at some things, and end up throwing up their hands or burning out. They go back to an infrastructure team and say "can you run this for us" and the infra teams look at whats there and say "hell no". Now you have a bunch of teams with a lot of infrastructure technical debt unable to safely deploy code.

I want to be clear, this is not inherently a "DevOps" issue. It's more how large organizations have embraced and implemented DevOps. And that's likely part of how "platform engineering" became a thing. A team of specialists working cross-silos that build and support underlying infrastructure and exposes common golden-path workflows with tools, SDKs, UIs, automation, declarative configuration, etc that best fits how the developers want to work. They are measured by improving developer experience, reducing costs, and improving compliance. 

Platform engineering is about the most "big enterprise" thing these organizations could do to best practice "DevOps" and the "you build it, you run it" mantra. Even when I worked at Amazon.com through my time at Zappos.com, the Amazonians living the "you build it, you run it" mantra had a massive amount of tooling to do builds, deploys, testing, monitoring, alerting, etc at their disposal. It was not as simple as "here's AWS, knock yourself out". That was over 10 years ago when I was there, so I cannot comment how it is now (please [reach out](https://www.linkedin.com/in/ceposta) if you have insight on what it's like now). 

Will platform engineering being the appropriate solution? It's the next part of the journey most organizations are embarking on, there are still challenges around the people problem, but it seems to fit better from my observations.