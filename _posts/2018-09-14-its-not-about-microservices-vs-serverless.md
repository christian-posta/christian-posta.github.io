---
layout: post
title: "Be as serverless as you can, but not more than that"
modified:
categories: serverless
comments: true
tags: [serverless, microservices]
image:
  feature:
date: 2018-09-14T13:54:43-07:00
---

No doubt, if you've been paying attention to technology trends, you've seen the rise in interest of "serverless". In some accounts, "serverless" is billed as the "next application architecture" style. I've even heard people say "you don't need technology X because serverless is the way of the future" or that "technology X is a red herring because serverless", etc. In this installment, we see why it's not about "microservices vs serverless". 

The best description of serverless I've seen thus far comes from [Patrick Debois](https://twitter.com/patrickdebois) in his ["serverless to service full" talk](https://www.slideshare.net/jedi4ever/from-serverless-to-service-full-how-the-role-of-devops-is-evolving). In that talk, he gives "serverless" a definition and _actually defining what it is_ and not what it's *not*. Focusing on what it's not (ie, no servers!!!!) actually distracts from any true meaning (of course there are servers!!). By focusing on the fact that it's more about using as-provided services (think things like SQS, DynamoDB, Gmail, Google Calendar, SalesForce, Fastly, etc) and stitching them together to provide some kind of functionality, we can arrive at [a more interesting definition](https://www.slideshare.net/ceposta/intro-to-knative-115084435):

> outsourcing core infrastructure services to service providers and stitching it all together through APIs (and functions) to deliver business value

In many ways, this idea of "leveraging existing services and building on top of it" isn't new. It's an incarnation of the spirit behind "Services Oriented Architecture":

![](/images/first-serverless/soa-twitter.png)

If we can leverage existing services that lower the barrier of entry (ie, sign up for an API instead of procure hardware, set up security/networking/DNS/operating systems, etc), we can more quickly build interesting things for our customers. This is one part about what serverless is. The second part is the fact that you don't have to own all of the technology from these different services. That is, you pay for usage (metered) and SLA, and you don't own and have to solve difficult technology problems to work on business-value providing functionality. This point was well communicated by [Ben Kehoe](https://twitter.com/ben11kehoe) [in a recent podcast](http://devopscafe.libsyn.com/devops-cafe-ep-79-guests-joseph-jacks-and-ben-kehoe). I completely agree with this. 

So when I'm asked by our customers "if serverless is the next evolution of application architecture should I just skip over microservices and containers"?  The answer:

> Be as serverless as you can, but not more than that.

Let's dissect that.

As technologists we are drawn to technology and any of the new shiny trends. Serverless, containers, etc all count. But at the end of the day, our role as technologists is to help the business find and exploit business value and do that faster than our competitors. 

![](/images/first-serverless/explore-spectrum.png)

If we're at the "explore" part of our application lifecycle (as all startups are), what we want to do is quickly invalidate our hypotheses about what will deliver customer value and equally quickly find what does deliver value. Customers aren't able to articulate what they value until they see it. It's best to rapidly experiment by putting services out in front of them and observe how they respond. If something shows little customer interest, it's best to ditch it and move on. To do this, we cannot sink massive investments into setting up infrastructure, development costs, partners, etc. We have to run these experiments as cheaply as possible and the "serverless" approach presents an excellent opportunity to do this. We can create digital properties for our customers by leveraging existing technical services without massive investment and critically: we can pay as we go. If we have zero interest in our new product/service, then it doesn't cost us much. If we have some initial unpredictable, spikey interest, we have a platform (Services + FaaS) that can quickly scale without much headache. 

If we stumble upon something that does provide customer value (ie, product/market fit), then we want to build on it, scale it, and build a profitable product around it. At this point, you may find yourself wanting to go toward a partly serverless and partly not serverless architecture to solve for this. You'll have to confront both technical decisions around "how much of my stack *should I own* to be able to deliver business value and differentiation" and "am I willing to outsource SLA, regulatory compliance, price, and roadmap to my service provider"? In the exploratory phase, outsourcing everything to service providers may be fine. But as a business matures, real discussion about how the organization (structure, operations, TCO, etc) is impacted by these decisions. This is a very real problem affecting our customers.

As you start to find predictable patterns for your new product/service, decide you want to optimize certain parts (both for cost and technical things like latency, tail latency, etc), you may decide the serverless approach is too expensive and it may be worth taking ownership of more parts of the stack. Take a look at this [account of serverless and its surrounding infrastructure becoming too expensive for an application with more predictable usage patterns](https://medium.com/coryodaniel/from-erverless-to-elixir-48752db4d7bc)

Lastly, for your existing applications that do generate a pile of money, you cannot just magically move that all off to service providers. You can, however, try to modernize parts of them to participate in some of the newer digital initiatives your company has. We see organizations making massive strides toward higher performing IT and organizations by modernizing to services architectures (Microservices/APIs/SOA etc) built on containers and Kubernetes, which if extended to its logical conclusion, can be built as a platform of organizational services which enable parts of an organization to go "serverless". That is, parts of the organization (those engaged in exploratory efforts) can leverage the rest of the enterprise without having to strictly "own" the full implementation. 

Different parts of the enterprise portfolio and [different spectrums of the application-development lifecycle](https://read.acloud.guru/the-serverless-spectrum-147b02cb2292) require different tools and different approaches with all of them aimed at "what's the best way to go fast and deliver value given my current context?". We should be more focused on unearthing what our real "context" is and make the best decisions on investment, ownership, technology, etc based on that.


Ask yourself:


* Where are you in your product lifecycle?
* What technology should you own to solve your business problems?
* How comfortable is your team currently with existing technology?
* How strategic and "core" to your business is the functionality you're thinking to take "serverless"?

Happy to take disagreements or thoughts in the comments or on Twitter [@christianposta](https://twitter.com/christianposta)