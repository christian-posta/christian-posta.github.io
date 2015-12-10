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

In the [previous post][previous] post, I outlined why [DevOps is not about efficiency][previous], and in fact how our old ways of looking at "complicated" problems by solving for efficiency first is actually not efficient or flexible in our now very [complex world][complex]. In fact, in some ways, letting go of our century-long instincts to apply reductionist management theories to create efficient workplaces may lead to building complex systems a little more *effectively* with room for flexibility and innovation. And at the end of the day [innovation powers our companies forward, not efficiently protecting what we already have][efficiency-myth].

The motivation, by the way, for writing this post(s) is to connect the dots somehow with what I've observed at a [particularly heralded DevOps Internet Unicorn][reality] and what I see at enterprises that I visit to do architectural assessments, distributed-systems implementations, cloud-native applications, microservices, DevOps, etc. ... in fact, it's all highly related... as [@littleidea][littleone] on twitter recently tweeted

>  my position is CD, microservices and devops are inseparable aspects of the same phenomenon

So what is this "phenomenon"? ... let's try to connect the dots.

So let's get back to the story and [recap a bit][previous]:

* We are operating in a more complex environment that at any time in history
* Strategies for complicated systems do not hold up for complex systems
* Focus on efficiency breeds management that may be suitable for complicated systems, but not complex systems
* To deal with complex systems, we need flexibility
* DevOps does not embrace these traditional reductionist management techniques made miraculous by Taylor et. al. 
  
  
## Dealing with Complex systems ... in the 1960s

I love this story from [General Stanley McChrystal's account of the NASA space program in his book Team of Teams][teams]. It's an illustration of the mindset that is the foundation of DevOps and is obviously (as you'll see shortly) *not constrained* to a developer or operations world; in fact the principles are rooted in [systems-thinking](https://en.wikipedia.org/wiki/Systems_thinking) which goes back longer than the now-hyped DevOps movement. 

On September 12, 1962, President John F. Kennedy gave his ["We choose to go to the moon" speech][speech] in front of 35,000 people at Rice University in which we proclaimed that the United States would send humans to land on the moon, and return safely, before anyone else would.


> But if I were to say, my fellow citizens, that we shall send to the moon, 240,000 miles away from the control station in Houston, a giant rocket more than 300 feet tall, ...  made of new metal alloys, some of which have not yet been invented, capable of standing heat and stresses several times more than have ever been experienced, fitted together with a precision better than the finest watch, carrying all the equipment needed for propulsion, guidance, control, communications, food and survival... and then return it safely to earth, re-entering the atmosphere at speeds of over 25,000 miles per hour, causing heat about half that of the temperature of the sun ... and do all this, and do it right, and do it first before this decade is out--then we must be bold.


For the president to say this was simply audacious. The United States at the time was trailing embarrassingly in the race to space and to the moon, and for him to proclaim that "with metal alloys not even invented" that the United States was going to make it to the moon first was almost laughable to some. The Soviet Union and successfully launched the first artificial satellite, [Sputnik](https://en.wikipedia.org/wiki/Sputnik_1), almost four years earlier. They had also put the first animal in space, did the first lunar flyby, the first lunar impact, and would soon after [put the first human into orbit](https://en.wikipedia.org/wiki/Yuri_Gagarin) -- the first man in space. 

The United States on the other hand had some significant failures on its record. In November 1960, NASA's first unmanned test flight, Mercury-Redstone I, [rose four inches off the ground then settled back down](https://en.wikipedia.org/wiki/Mercury-Redstone_1). Its escape rocket had broken off and fluttered into the air. A few months earlier, something similar happened: a structural incompatibility between the Mercury capsule and an Atlas rocket caused that effort to fail.

Nevertheless, less than 7 years after Kennedy's speech, with more than 600 million viewers around the world, Neil Armstrong set foot on the moon and proclaimed his now famous saying "one giant leap for mankind" ... and did it before anyone else. On the other hand, at the same time, the European Launcher Development Organization had just experienced its fifth consecutive failure to accomplish the exact same thing. 

The differences between NASA and ELDO had little to do with technology, expertise, resources or the like. The differences were later attributed to how the organizations were structured and how they worked together.

## The success of "systems thinking" at NASA

Part of why the United States had failed earlier in the space race was because of the failure of integration of the components required to power and control the various rockets and systems involved. For example, the Atlas rocket was originally designed to cary warheads but was replaced with satellites.  There were new communication measures put in place for the pieces to communicate with each other that failed. This caused a slight delay in shutoff signals for the engines of the various stages.
 
The way NASA was organized seemed akin to the "efficiency silos" we see in large companies today that were inspired by the Taylor reductionist thinking. There were small teams working on their own piece of the puzzle in isolation without regard for the bigger picture. Unpredictable vibrations throughout the rocket affected all disciplines (structural engineering, propulsion engineering, electrical, and others) but didn't experience these forces in their own, highly controlled specialized environments in which they worked to produce the pieces that would make up the rocket and launch mechanisms. Never before was so much electronics jammed so closely together before that each component was also subject to electromagnetic interference -- again, something they would not experience in their own silo'd environments. As they brought these highly efficiently created pieces together, they would fail in unexpected ways. 

The way NASA would overcome this, manage 300,000 individuals for 20,000 contractors, 200 universities, 80 countries and cost $19Billion is by systems management, systems thinking, and solving their organizational problems. And they had to; the President had already publicly signed them up for the task!

In 1963 NASA brought [George Mueller](https://en.wikipedia.org/wiki/George_Mueller_(NASA)) on board to lead the Office of Manned Space Flight project. Mueller objected at first and only accepted after NASA agreed to a restructuring led by him. Mueller quickly threw out the old org charts and required managers, engineers, and executives (who were comfortable working in their own confines) to communicate daily with each other and share information. This wreaked havoc at NASA headquarters. 

Mueller created an environment where information was shared instantly, there were daily cross-discipline meetings, there were field centers with live updating information, test results, etc. Groups from across the organization could instantly communicate. It was the "internet" before the internet. "You got instantaneous communication up and down" ... an "instantaneous transmission of knowledge across the organization" One administrator recounted "the reason that it worked and that we got it ready on schedule was we had everbody in that room that we needed to make a decision ... it got to the point were we could identify a problem in the morning and by close of business we could solve it, get the money allocated, get decisions made, and get things working"

This approach, systems management/thinking, is predicated on a core tenant which is intrinsically at odds with reductionist thinking:

> One cannot understand a part of a system without having at least a rudimentary understanding of the whole. 

In the end, what they created was a shared understanding across all teams of the project as a whole, even if establishing that understanding took time away from other duties and was "inefficient". NASA leadership understood that when creating a highly complex, even unknown product, confining specialists to a silo was stupid; high-level success depended on low-level efficiencies. Even one of the top executives, one of the most ardently against Mueller's approach, Wernher von Braun revealed "The real mechanism that makes NASA tick is a continuous cross-feed between the right and left side of the house"

Some of these innovations are quite simple: "take off the blinders and have people talk with each other"

## Does this mean we should all be generalists?

No.

Work in progres....


## So does that mean we're "killing the developer"?


## Inspiration for this dot-connecting

* [Team of Teams][teams] by [General Stanley McChrystal](https://twitter.com/stanmcchrystal)
* [The Connected Company][connected] by [Dave Gray](https://twitter.com/davegray)
* [Thinking in Systems][systems] by [Donella H Meadows](https://en.wikipedia.org/wiki/Donella_Meadows)
* [The Open Organization][open-org] by [Jim Whitehurst](https://twitter.com/JWhitehurst)

## Part III?




[previous]: http://blog.christianposta.com/devops/devops-and-the-myth-of-efficiency-part-i/
[complex]: https://larrycuban.wordpress.com/2010/06/08/the-difference-between-complicated-and-complex-matters/
[reality]: http://blog.christianposta.com/microservices/the-real-success-story-of-microservices-architectures/
[littleone]: https://twitter.com/littleidea
[efficiency-myth]: http://www.forbes.com/2009/10/16/efficiency-innovation-change-leadership-managing-taylor.html
[teams]: http://smile.amazon.com/Team-Teams-Rules-Engagement-Complex/dp/1591847486/ref=smi_www_rco2_go_smi_g2243581662?_encoding=UTF8&*Version*=1&*entries*=0&ie=UTF8
[connected]: http://smile.amazon.com/Connected-Company-Dave-Gray/dp/1491919477/ref=sr_1_1?s=books&ie=UTF8&qid=1449786330&sr=1-1&keywords=the+connected+company
[systems]: http://smile.amazon.com/Thinking-Systems-Donella-H-Meadows/dp/1603580557/ref=sr_1_1?s=books&ie=UTF8&qid=1449786361&sr=1-1&keywords=thinking+in+systems
[open-org]: http://smile.amazon.com/Open-Organization-Igniting-Passion-Performance/dp/1625275277/ref=sr_1_1?s=books&ie=UTF8&qid=1449786394&sr=1-1&keywords=the+open+organization
[speech]: https://en.wikipedia.org/wiki/We_choose_to_go_to_the_Moon