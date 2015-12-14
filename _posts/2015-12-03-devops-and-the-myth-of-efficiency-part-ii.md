---
layout: post
title: "DevOps and the Myth of Efficiency, Part II"
modified:
categories: devops
comments: true
tags: [devops, team-of-teams, microservices, organization, culture]
image:
  feature:
date: 2015-12-03T20:10:08-07:00
---

In the [previous post][previous] post, I outlined why [DevOps is not about efficiency][previous], and how our old ways of looking at "complicated" problems by solving for efficiency first is actually not effective or flexible in our now very [complex world][complex]. In fact, **letting go of our century-long instincts to apply reductionist management theories** to create efficient workplaces may lead to building complex systems a little more *effectively* with room for flexibility and innovation. And at the end of the day [innovation powers our companies forward, not efficiently protecting what we already have][efficiency-myth]. To voice an opinion, let me know [@christianposta][twitter]

The motivation, by the way, for writing this post(s) is to connect the dots somehow with what I've seen first hand, and participated in at a [particularly heralded DevOps Internet Unicorn][reality] and what I see at enterprises that I visit to do architectural assessments, distributed-systems implementations, cloud-native applications, microservices, DevOps, etc. ... in fact, it's all highly related... as [@littleidea][littleidea] on twitter recently tweeted

>  my position is CD, microservices and devops are inseparable aspects of the same phenomenon

So what is this "phenomenon"? ... let's try to connect the dots. The TL;DR version is at the end :)

So let's get back to the story and [recap a bit][previous]:

* We are operating in a more complex environment than at any time in history
* Strategies for complicated systems do not hold up for complex systems
* Focusing on *efficiency* breeds management that may be suitable for complicated systems, but not complex systems
* To deal with complex systems, we need flexibility
* DevOps does not embrace these traditional reductionist management techniques made miraculous by Taylor et. al. 

![Micro](/images/cloud_22.jpg)
  
  
## Dealing with Complex systems ... in the 1960s

I love this story from [General Stanley McChrystal's account of the NASA space program in his book Team of Teams][teams]. It's an illustration of  the foundation of DevOps principles and is obviously (as you'll see shortly) *not constrained* to a developer or operations world; in fact the principles are rooted in [systems-thinking](https://en.wikipedia.org/wiki/Systems_thinking) which goes back longer than the now-hyped DevOps movement. 

On September 12, 1962, President John F. Kennedy gave his ["We choose to go to the moon" speech][speech] in front of 35,000 people at Rice University. He proclaimed that the United States would send humans to land on the moon, and return safely, before anyone else would:


>Wwe shall send to the moon, 240,000 miles away from the control station in Houston, a giant rocket more than 300 feet tall, ...  made of new metal alloys, some of which have not yet been invented, capable of standing heat and stresses several times more than have ever been experienced, fitted together with a precision better than the finest watch, carrying all the equipment needed for propulsion, guidance, control, communications, food and survival...and do all this, and do it right, and do it first before this decade is out--then we must be bold.


For the president to say this was simply audacious. The United States at the time was trailing embarrassingly in the race to space and to the moon, and for him to proclaim that "with metal alloys not even invented" that the United States was going to make it to the moon first was almost laughable to some. The Soviet Union and successfully launched the first artificial satellite, [Sputnik](https://en.wikipedia.org/wiki/Sputnik_1), almost four years earlier. They had also put the first animal in space, did the first lunar flyby, the first lunar impact, and would soon after [put the first human into orbit](https://en.wikipedia.org/wiki/Yuri_Gagarin) -- the first man in space. 

The United States on the other hand had some significant failures on its record. In November 1960, NASA's first unmanned test flight, Mercury-Redstone I, [rose four inches off the ground then settled back down](https://en.wikipedia.org/wiki/Mercury-Redstone_1). Its escape rocket had broken off and fluttered into the air. A few months earlier, something similar happened: a structural incompatibility between the Mercury capsule and an Atlas rocket caused those efforts to fail.

Nevertheless, less than 7 years after Kennedy's speech, with more than 600 million viewers around the world, Neil Armstrong set foot on the moon and proclaimed his now famous saying "one giant leap for mankind" ... and did it before anyone else. On the other hand, at the same time, the European Launcher Development Organization had just experienced its fifth consecutive failure to accomplish the exact same thing. 

The differences between NASA and ELDO had little to do with technology, expertise, resources or the like. The differences were later attributed to how the organizations were structured and how they worked together.

## The success of "systems thinking" at NASA
 
The way NASA was organized before the Office of Manned Space Flight (OMSF) project kicked off seemed akin to the "efficiency silos" we see in large companies today that were inspired by the Taylor reductionist thinking. There were small teams working on their own piece of the puzzle in isolation without regard for the bigger picture. Unpredictable vibrations throughout the rocket affected all disciplines (structural engineering, propulsion engineering, electrical, and others) but didn't experience these forces in their own, highly controlled specialized environments. Never before was so much electronics jammed so closely together before that each component was also subject to electromagnetic interference -- again, something they would not experience in their own silo'd environments. As they brought these highly efficiently created pieces together, they would fail over and over again in unexpected ways. 

The way NASA would overcome this, manage 300,000 individuals for 20,000 contractors, 200 universities, 80 countries and cost $19Billion is by systems management, systems thinking, and solving their organizational problems. And they had to; the President had already publicly signed them up for the task!

In 1963 NASA brought [George Mueller](https://en.wikipedia.org/wiki/George_Mueller_(NASA)) on board to lead the (OMSF) project. Mueller objected at first and only accepted after NASA agreed to a restructuring of the project(s) led by him. Mueller quickly threw out the old org charts and required managers, engineers, and executives (who were comfortable working in their own confines and silos) to communicate daily with each other and share information. This wreaked havoc at NASA headquarters. 

Mueller created an environment where information was shared instantly, there were daily cross-discipline meetings, there were field centers with live updating information, test results, etc. Groups from across the organization could instantly communicate. It was the "internet" before the internet. "You got instantaneous communication up and down" ... an "instantaneous transmission of knowledge across the organization" One administrator recounted "the reason that it worked and that we got it ready on schedule was we had everybody in that room that we needed to make a decision ... it got to the point were we could identify a problem in the morning and by close of business we could solve it, get the money allocated, get decisions made, and get things working"

On the other side of the pond at ELDO, different countries produced different parts of the rockets, boosters, satellite test vehicles, etc. They did not share information, their contractors reported directly to their own national agencies, and each sought to maximize its own economic advantages. Multiple interface failures resulted in 5 separate failed launches and French journalist Jean-Jacques Servan-Schreiber argued that Europe's lag in the space race was not a question of money but of "methods of organisation above all" in his book *The American Challenge*.

## Systems thinking

This approach, systems management/thinking, is predicated on a core tenant which is intrinsically at odds with reductionist thinking... for systems with many intricate interactions, are complex and unknown:

> One cannot understand a part of a system without having at least a rudimentary understanding of the whole. 

In the end, what NASA created was a "shared understanding" across all teams of the project as a whole, even if establishing that understanding took time away from other duties and was "inefficient". NASA leadership understood that when creating a highly complex, even unknown product, confining specialists to a silo was stupid; high-level success depended on low-level efficiencies. Even one of the top executives, one of the most ardently against Mueller's approach, Wernher von Braun revealed "the real mechanism that makes NASA tick is a continuous cross-feed between the right and left side of the house" 

![Micro](/images/Innovation-cartoon.png)

## Does this mean we should all be generalists?

No.

Specialization is still essential, but the key is having a "rudimentary understanding of the whole." [In McChrystal's book][teams] he refers to this as a *"shared conciousness"* where the different specialized teams "share a fundamental, holistic understanding of the operating environment and of [the] organization".

In [Jim Whitehurst's Open Organization][open-org], he talks about igniting passion and directing that passion toward a common, shared purpose.

Whatever you call it, our teams should be aware of the common purpose, see and understand the bigger vision at all stages etc... and the effort at doing this will necessarily be "inefficient". 


## So does that mean we're "killing the developer"?

So what about [how DevOps is killing the developer](https://jeffknupp.com/blog/2014/04/15/how-devops-is-killing-the-developer/)?

So when we talk about "DevOps", we talk about creating  "shared consciousness" between developers and operations (and others really) teams. The steps, processes, automation and implementation of "devops" is really about creating "shared consciousness" between teams, and each organization may have its own way of doing this that are peculiar and specific to the context of that organization. Just "automating your builds" or buying a tool is not DevOps. In fact, [making something run efficiently that is not effective is a horrible use of time](http://blog.gardeviance.org/2015/12/efficiency-vs-effectiveness-repeated.html), regardless of what buzzword you try to associate for justification.
  
So are we "killing the developer"?

The article about "killing the developer" tries to draw a line between "DevOps", a familiarity with the the rest of the cross-functional responsibilities and then jumps to that necessitating a "full stack developer". And because of this full-stack developer mindset, which the author claims originated from startups, that we're killing developers by making them generalists. 

Nope. DevOps is making the developer more effective.
 
Let's take it a step further: DevOps, Microservices, Cloud, etc are all about [making organizations more effective](http://blog.christianposta.com/microservices/the-real-success-story-of-microservices-architectures/). It's laying the groundwork to treat our organizations as complex systems, not machines. This approach lends itself to *really understanding* the value of **feedback**, **failure**, **learning**, **autonomy**, and **emergent behavior** which are critical for any complex system to exhibit to evolve and stay relevant in a complex, not merely complicated, world.



## Inspiration for this dot-connecting

I've experienced a lot of these forces first hand and was looking for a good way to articulate it holistically. These books have so far helped in that regard, and I highly recommend them:

* [Team of Teams][teams] by [General Stanley McChrystal](https://twitter.com/stanmcchrystal)
* [The Connected Company][connected] by [Dave Gray](https://twitter.com/davegray)
* [Thinking in Systems][systems] by [Donella H Meadows](https://en.wikipedia.org/wiki/Donella_Meadows)
* [The Open Organization][open-org] by [Jim Whitehurst](https://twitter.com/JWhitehurst)

## Part III?

So what about the cool technology that's coming out and branded as "DevOps" etc? What about CI/CD, build automation, etc? How do these all play into the narrative I've outlined above? I was oringinally planning to write two parts, but I've got more to say. Stay tuned to part III!



[previous]: http://blog.christianposta.com/devops/devops-and-the-myth-of-efficiency-part-i/
[complex]: https://larrycuban.wordpress.com/2010/06/08/the-difference-between-complicated-and-complex-matters/
[reality]: http://blog.christianposta.com/microservices/the-real-success-story-of-microservices-architectures/
[littleidea]: https://twitter.com/littleidea
[efficiency-myth]: http://www.forbes.com/2009/10/16/efficiency-innovation-change-leadership-managing-taylor.html
[teams]: http://smile.amazon.com/Team-Teams-Rules-Engagement-Complex/dp/1591847486/ref=smi_www_rco2_go_smi_g2243581662?_encoding=UTF8&*Version*=1&*entries*=0&ie=UTF8
[connected]: http://smile.amazon.com/Connected-Company-Dave-Gray/dp/1491919477/ref=sr_1_1?s=books&ie=UTF8&qid=1449786330&sr=1-1&keywords=the+connected+company
[systems]: http://smile.amazon.com/Thinking-Systems-Donella-H-Meadows/dp/1603580557/ref=sr_1_1?s=books&ie=UTF8&qid=1449786361&sr=1-1&keywords=thinking+in+systems
[open-org]: http://smile.amazon.com/Open-Organization-Igniting-Passion-Performance/dp/1625275277/ref=sr_1_1?s=books&ie=UTF8&qid=1449786394&sr=1-1&keywords=the+open+organization
[speech]: https://en.wikipedia.org/wiki/We_choose_to_go_to_the_Moon
[twitter]: https://twitter.com/christianposta