---
layout: post
title: "Microservices, DevOps, and the cost of change?"
modified:
categories: microservices
comments: true
tags: [microservices, design, agile]
image:
  feature:
date: 2015-03-10T12:02:24-07:00
---

As developers, we all love shiny new things. New technologies (Docker, Kubernetes), new languages (Golang, NodeJS), new hyped conversation starters (Microservices, DevOps, Cloud). And everyone seems to have an opinion about why you should do this architecture, or why you should use that language. At the end of the day, your employer is expecting you to deliver using a means to an end, but what is that end?

![cat money](/images/cat-money.jpg)

Believe it or not, businesses are around to make money. Yah, yah, they provide services, products, etc that we all want, otherwise they wouldn't make any money. But really, it's all about the money. And when they are making money, that's not good enough. They need to make more money. And more and more companies are coming around to the realization that technology is a significant differentiator. For example, you can [go to Disney World/Land and they know who you are, what attractions you are interested in, and when you are ready to eat lunch](http://www.wired.com/2015/03/disney-magicband/?mbid=social_twitter). Sounds creepy? Well, since they know this, they can provide you maps of the park with a customized trail to follow to hit all of your favorite rides in an order that's optimized for both location/distance and wait times. With the information they have, they can also re-route you or alert you to popular rides that may have short wait times. Or when you go for lunch, you can preorder on your phone/app and go sit down and they will greet you by name and find you when your food is ready. That's just the tip of the ice berg.
  
To be able to provide these kinds of services, and come up with new innovative ways to provide better customer service or better products, companies must rely on technology going forward. Or, their competition (be it large existing competitors, or competitors they don't even know about yet) will smoke them. To accommodate this relatively newer embrace of technology as a differentiator, businesses have to be __agile__. But okay, Mr Posta, you say. I've been hearing that for the last 10 years about "agile". WTF is different?
  
  
The difference is the technical solutions for this agility have been popping up organically and more specifically in the form of open collaboration, community and opensource. It's not being driven (at least of yet.... although it's fast becoming a "perceived goldmine" for vendors) by stuffy, know-it-all, committees coming up with egregious specs that they can then hand down to us from the castle of the all knowing. 

> But why should you care?

Well, your employer cares. To be able to achieve this "agility" you don't need a special (and very expensive) SOA suite. You need to adopt a culture that embraces reducing the _cost_ of change. Change should be constant. Your management structure, teams, developers, architects, DBAs, operations, build and release, security, and business people should be all on the same page with this effort. Otherwise, you end up loosening up "change" in one pocket (sorry) and tightening the noose in others. 

Microservices and DevOps are really more about culture and _reducing the cost of change_ than any particular technology. And if you stop and take a look around your current company/organizational structure, and really think about "what are the impediments to change".. you'll find them all over.
 
## Development
Are you not writing unit tests? Then you're slowing yourself down. You cannot make changes to your code base without a hint of confidence that the changes you make don't break existing functionality, or even the functionality you're writing.
 
Are you not doing continuous integration? then you're slowing yourself (and sinking deadlines) by not being able to communicate changes in your code base across your team. And when it comes time to integrate/merge/rebase with others on your team, you have a black hole (literally... how do you predict how long it will take to rectify these conflicts? you cannot..) in terms of time. So by slowing yourself, you incur a cost.
   
Are you creating all kinds of shared dependencies, custom libraries, shared domain logic, and home-grown frameworks? Then you might as well hang up the business right now. [I've all ready written about the cost of code reuse abuse](http://blog.christianposta.com/design/the-cost-of-code-reuse-abuse/).

## Operations
Are you hand crafting servers for deployment? Then have a look at some [thoughts on that](https://blog.engineyard.com/2014/pets-vs-cattle) and how by definition this introduces inefficiencies and introduces human errors. Huge cost for change. 

Are you deploying into application servers without [treating them as atomic upgrades](https://medium.com/@jstrachan/the-decline-of-java-application-servers-when-using-docker-containers-edbe032e1f30)? See above about introducing human errors, but also magnify that by introducing technology errors.

# Infrastructure
Do you have shared infrastructure? Does it cost more to provision VMs that physical boxes? Does it take weeks to provision VMs? Do you not script your environments? Have repeatable automation for creating an environment from scratch? Have upgrade/rollback automation (for both applications, databases, etc)? Then you're incuring a huge amount of cost to the business. You cannot be agile and support change with an environment like that.


At the end of the day, DevOps, Microservices, being "Agile", etc, are about creating a cultural that focuses on reducing the _cost_ of change. Be wary of the vendors trying to capitalize on this, be wary of your organizations embracing this half-assed, and try to keep perspective and the goals in mind regardless of your role. 