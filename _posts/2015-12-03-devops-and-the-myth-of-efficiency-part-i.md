---
layout: post
title: "DevOps and the Myth of Efficiency, Part I"
modified:
categories: devops
comments: true
tags: [devops, team-of-teams, microservices, organization, culture]
image:
  feature:
date: 2015-12-03T20:10:04-07:00
---

This post is for those of you working in large companies or "enterprises" and are exploring what "DevOps" really means and why you're struggling with it. I've decided to split this into a [two-part post][second-part] to make it easy to digest some of the thoughts here; I suspect I'll be writing a lot here and build upon some [of my other posts][my-posts]. Hit me on twitter [@christianposta][twitter] to voice disagreements. 

There is some great stuff about DevOps, empathy, and organizational change on the 'nets. I travel far and wide to help enterprises develop and architect distributed systems (traditional, cloud-native, and in-between) for the purposes of providing business value. It's not a surprise that businesses want to deliver business value faster to remain competitive in their respective markets, and software/technology helps them do this. No, scratch that. **Software/technology is the KEY DIFFERENTIATOR and MEANS OF DELIVERY for that business value.** Yet, even with so much discussion, blogging, conferences talks, etc. companies are still *struggling* to understand what DevOps really means and how to approach it. If you've seen job postings for "DevOps engineer" or queries about joining a "DevOps team" you'll know exactly what I'm talking about. To deliver business value faster, we have to approach things differently than we've traditionally done. 

   
![Micro](/images/devops-cartoon.png)   

I've [written about the impact of working on small teams that are the poster child for the DevOps and microservices  movement][reality] and time and time again I try to draw on that experience to help guide clients down the right *path* with these concepts. But there's a disconnect between how an Internet Unicorn implements (and continually evaluates and evolves) a DevOps approach and how large, established legacy enterprises think about it. To them it's just another "team" .. or "job title".. or "technology they can just buy"... because that's how companies for the last 130+ years think about doing things. And I'm convinced *the crux of that previous point* is why enterprises have such difficulty wrapping their heads around "DevOps" and by corollary "microservices" and how to take proper advantage of what the cloud brings to the table. These are all related concepts, so let's take a step back and understand where we should be coming from.
 

## Complicated vs Complex

We live in a complex world, not merely a complicated one. This has always been the case, but complexity is showing up in more and more places as a result of technology. So what's the difference between complicated, complexity, and why should we care? [Treating systems as complicated, when in reality they are complex, can have profoundly negative consequences][hbr-complex]. 
  
Simple systems are just that. Easy to understand, predictable, and very few moving parts. 

> [Simple systems] contain few interactions and are extremely predictable. Think of switching a light on and off: The same action produces the same result every time.


Complicated systems are understandable, though have more moving parts. There is a predictable set of inputs, and maybe a well-known formula, pattern, or process for combining those inputs, and a well-understood output. For eaxmple, a car engine is quite complicated. There are many moving parts, they're connected and interact with each other in well-defined ways, and they can be dismantled into their constituent parts, understood individually, and reassembled according to some manual.

In terms of how to deal with and manage a complicated system, [another way to put it][another-way]:

> A complicated system assumes expert and rational leaders, top-down planning, smooth implementation of policies, and a clock-like organization that runs smoothly. Work is specified and delegated to particular units.

Complex systems, on the other hand, are made up of many interactions who's inputs/outputs/behaviors are continuously changing and are unpredictable. For example, cities are complex systems. So are financial systems, climate patterns, raising children, and business markets (nice mix of examples!). Try as you might to predict and apply inputs that may have worked in the past, they may or may not produce the desired output in the future. 
 
Said another way, complicated systems have expected outputs based on inputs. Complex systems cannot be predicted based on inputs no matter how deterministic they look, and are continuously changing.  
 

> "Why should I care" you ask... Good question.



## Dealing with complexity

Our business markets are changing fast. Technology has made our business landscapes *far more complex* than they have ever been. Social media allows us to have far more connections and interactions with unknown/unpredictable results than there has ever been at any time in the history of the world. Dave Caroll, a guitarist who flew on United Airlines a few years back arrived at this destination found that his guitar which he checked for the flight had been damaged. United refused to pay any restitution, so he [posted a video of a song he made called "United Breaks Guitars"][breaks-guitars]. The video went viral, amassing 5 million+ hits in about a month. Within 4 days, United Airlines stock price fell 10% costing shareholders $180 million dollars in value. Nobody could have predicted the effect of posting that video. On the other hand technology is an equally powerful force for disruption. While your business/company can effect some poor customer service and have negative ramifications over night, a startup that takes a new approach to an existing market can pop up over the weekend, go viral, and significantly disrupt an existing market. Or that startup over the weekend could have absolutely zero affect on any market whatsoever. The unpredictability of our markets because of technology has made things much more complex.

![Micro](/images/disorganized.png)

To deal with complexity, a system (or company) must be able to react swiftly. This is where the need for "agility" comes from; not just "business-level agility" but because our companies are more and more powered by software and technology, we need agile software systems and software delivery teams. But there-in lies the motivation for the title of this article. We've spent the last 130+ years optimizing for efficiency in our companies. This efficiency has lead to remarkable things, however efficiency is great for dealing with complicated problems (like making a car engine). Dealing with complex problems requires something else.


## Efficiency is no longer enough

Back in the 1800s, it was common to have craftsman working their trades (like cutting, molding, fitting steel for example) based on apprenticeships/mentorships, experience, and potentially harmful mistakes. Each craftsman approached their trade as though they knew the right way to do it. Then along came [Fredric Winslow Taylor][fred-taylor] who appeared to perform miracles: he recreated a small part of the steel cutting factory he operated for the Paris world expo in 1900. He won a gold medal for this "invention". His team of a couple men and a few lathes were able to cut 50 ft of steel per minute when the norm at the time was about 9ft/min.  At the time, this was revolutionary; akin to Steve Jobs introducing the iPhone for the first time. This miracle was attributed to not a new lathe, or new technology. On the contrary it is attributed to Taylor's reductionist management approach: through many experiments, measurements, and process alterations, Taylor found the optimal temperature to cut steel, the optimal distance the workers should stand from each other and their tools, the most optimal way for water to cool the steel, etc,etc. In short Taylor focused on the efficiencies of the process. At his steel plant, not only was he incredibly efficient at churning out steel chips, he could do it at an incredibly cheaper price than any anyone else: not only did he have efficiency, he could lay off the expensive craftsman and replace them with less-skilled workers who could follow the directions from the sheets set out by taylor and his "managers".
   
Does this sound somewhat similar to our software model a few years back? Waterfall efficiency, outsource developers, etc,etc?

For much of the 20th century  "efficiency" was the goal and management structures were put in place to squeeze as much efficiency and do away with expensive craftsmanship. We were further divided up into groups of specialization, told we don't need to know anything about the overall process just concentrate on our small chunk of the pie. Further, we were treated as dumb, expensive code-monkey, replaceable parts in a complicated machine. 

This works great when we're dealing with mere complicated systems. With known inputs, known processes, 18-month planning cycles, and our predictions for a complicated landscape, we could reliably churn out products with this reductionist, efficient model. But when things are complex, unknown, unpredictable, trying to play by the same rulebook is liable to put you out of business. Just ask Kodak... or Borders... or Blockbuster.
 
The problem is that efficiency focuses every ounce of effort on reducing variability and focusing on the pre-determined output. However, in our complex world, we need to be ready to be *flexible* and react to unforeseen events, market conditions, competitors, etc. and you achieve flexibility by leaving room for variability (by defintion) which is at odds with the efficient, clock-work model we cherish so dearly. 


![Micro](/images/deafops.jpg)

## DevOps is not about efficiency

Take a look around at your organizations: at least from the IT perspective, you probably have "specializations" and roles conceived in the name of efficiency: developers who hack the code; DBAs who hack the databases; operations teams who manage the servers; build and release teams who chuck the code into app servers; infosec who decrees security requirements; etc,etc,etc. The name of the game has been "you developers be efficient at churning out code; don't worry about the rest of the process, just do as your told"... "you DBAs.. install, manage, and tune your databases... don't worry about the applications" ... "you QA folks, just test the damn software, don't worry about where it runs or how it was created" ,etc,etc. Efficiency FTW! The more efficient we are individually, the better we'll be!

Except in reality this "efficiency" and silo/specialization of teams causes more needs to synchronize; it causes more "bad communication"... it even causes bad behavior:

> Bad behavior arises when you abstract people away from the consequences of their actions

And actually slows down our teams to be able to deliver software, and in turn deliver business value. DevOps is not about efficiency in this regard.


## Part II

[In part II we'll look at][second-part] a historic event of the United States' race to space and how what we term "DevOps" made that possible. Management, teams, etc were the difference with technology being a second consideration. Sound familiar?




[my-posts]: http://blog.christianposta.com/posts/
[twitter]: https://twitter.com/christianposta
[reality]: http://blog.christianposta.com/microservices/the-real-success-story-of-microservices-architectures/
[hbr-complex]: https://hbr.org/2011/09/learning-to-live-with-complexity
[breaks-guitars]: https://en.wikipedia.org/wiki/United_Breaks_Guitars
[another-way]: https://larrycuban.wordpress.com/2010/06/08/the-difference-between-complicated-and-complex-matters/
[fred-taylor]: https://en.wikipedia.org/wiki/Frederick_Winslow_Taylor
[gold-medal]: http://www.units.miamioh.edu/technologyandhumanities/taylor.htm
[second-part]: http://blog.christianposta.com/devops/devops-and-the-myth-of-efficiency-part-ii/