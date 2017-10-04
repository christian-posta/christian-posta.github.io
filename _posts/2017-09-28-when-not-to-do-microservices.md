---
layout: post
title: "About When Not to Do Microservices"
modified:
categories: microservices  
comments: true
tags: [microservices, network, distributed systems, circuit breaker, tracing, security]
image:
  feature:
date: 2017-09-28T10:45:36-07:00
---

Quick interlude to my last blog. As part of [my last blog on low-risk monolith to microservice architecture](http://blog.christianposta.com/microservices/low-risk-monolith-to-microservice-evolution/), I made this statement about microservices and not doing them: 

> "Microservices architecture is not appropriate all the time".
 
I've had some interesting reactions. Some of it along the lines of "how dare you". I also poked at that a bit [on twitter a month or so ago](https://twitter.com/christianposta/status/902644004239564800)

![Don't do microservices](/images/dontmusvc/mvp-musvc.png)

Let me expand a little bit. 

Doing microservices, or monoliths, or SOA, or Microliths or whatever fancy term gets bandied about at present is *not the point*. Businesses ideally will be looking for [new] ways to deliver customer value and technology can be a differentiator. The key problem we face as we journey down this path of "deliver value" is actually quite simple: uncertainty. We literally do not know what will deliver value. Customers are also poor at articulating it.  We have lots of ideas, good ideas some times, but we don't actually *know* what deliver customer value until we experiment and try. Microsoft published an awesome paper [about experimentation](http://ai.stanford.edu/~ronnyk/ExPThinkWeek2009Public.pdf) that everyone should stop and go read right now. Part of what they discovered is that 66% of the "good ideas" people have actually have zero impact (or even worse) on the metric it was intended to effect.  The folks who are able to run cheap experiments, run lots of them, and learn what brings value to customers faster than their competitors are gonna win. 

Microservices is about optimizing for speed. But there's more to it:


![Don't do microservices](/images/dontmusvc/optimize-bml.png)


The key statement from that tweet stream:

> ...when your current application/org architecture impedes this or has become a bottleneck. 

Many moons ago [Simon Wardley](http://twitter.com/swardley) blogged an eye-opening piece (for me) about [Pioneers, Settlers, and Town Planners](http://blog.gardeviance.org/2012/06/pioneers-settlers-and-town-planners.html). Basically *pioneers* focus on creating long-term options for an organization. Their work is inherently rife with unknowns: Who can predict what's going to happen in 3 years or beyond? Pioneers go off and experiment with wild, divergent approaches running many experiments hoping to reduce uncertainty about what may bring value to a company in 3+ yrs. This "pioneering" effort is intended to turn up a few decent options that we can build upon and take to the next level. The "settlers" end up doing this.  They figure out how to scale the product engineering, scale marketing, sales, etc and build the pieces of the organization to make this product a successful differentiator. Ultimately over the years, as a result of competitive diffusion, etc,  our new product is no longer uniquely differentiated but still delivers massive value. It will be around for a long time and there are things we can do to make it run more effectively. We probably have lots of people working on this. These are the Town Planners in @swardley's analogy. 

So WTF? How does this tie in? Well... were do you think  you fit in your organization?

## If you're the Pioneers, stick with monoliths. 

As pioneers you have to move quick. You have zero idea whether a "thing" will bring value. You want to run cheap experiments as quickly as possible and learn. You may not even be writing any code! [Barry O'Reilly](https://barryoreilly.com) has a great story about running experiments. He talks about starting an online picture-driven wine shop... but not by building it out, organizing suppliers, lining up distributors, etc. I'm pretty sure I've also heard him say the most inefficient way to test a hypothesis is to build it out completely. In his story he talks about reducing uncertainly by coming up with hypothesises like "people who take pictures of wine probably might want to buy that wine" and coming up with cheap experiments to test that hypothesis. For example, doing a quick scan on twitter/facebook/instagram for people who've posted pictures of wine and send them a response with a link to a page that allows them to buy that wine. The purpose of that experiment is just to see if people would even click on the link. Running lots of these small experiments doesn't require building out a complete product and absolutely reduces the uncertainty in your idea. You may, at some point, come to a point where you build an Minimum Viable Product. But again, the point of the MVP is to test hypothesis and elicit learning. An MVP is not product engineering. You're not building this for scale. In fact, you're doing the opposite. You're probably going to be running MANY MVP tests and throwing them away. A monolith is a perfect way to attack this. A monolith will actually allow you to go faster because changing things quickly can be done all in a single place. Doing microservices at this point is infinitely overkill and will distract you from your objective: Figure out something that delivers value.


## If you're the Settlers, you may need microservices

Once you stumble upon something that delivers value, you will probably want to scale it. This involves creating a product team: prodcut managers, testers, marketing, sales, etc. On the product side, you'll want to be adding features and moving quickly, again, to run smaller tests about certain features. If your team is just getting startd, small, etc, and you're still figuring out the right boundaries of the business org and the technical features, don't do microservices. This is still an immature stage of the product development path. You're likely to optimize too early around APIs, boundaries, etc and cause a world of hurt when you need to make changes. Again, our goal is to make changes quickly to test them out. Once you find that your application has too many people working on it, you're trying to get too many changes out that are stepping on each other, you're probably at the point to optimize for microservices. Microservices involves a lot of complexity. [Matt Klein recently said](https://t.co/rJCfSPDJpa) "don't take on compexlity when you don't need to". He's absolutely correct. 

## If your'e the Town Planners, you may need microservices

If you're working on the flagship product that has been around for a while you have to evaluate how quickly you're changing the product and whether there are certain hot spots of change. You may also want to introduce new features around the existing monolith/product and just as described in the Settlers section, you may be running into org and system architecture bottlenecks for doing this. In these cases microservices may be a great fit for you. Microservices help you optimize for "speed" in this case. 


We're currently experiencing a lot of ["microservices envy"](https://www.thoughtworks.com/radar/techniques/microservice-envy) in our industry. It's easy to lose track of our jobs as technologists to help find and cultivate customer value using technology. Don't over optimize and complicate things when you don't need to. Solve the problems you have, not someone else's.  

Okay! [Back to the monolith to microservices migration discussion](http://blog.christianposta.com/microservices/low-risk-monolith-to-microservice-evolution/)! Stay tuned!
