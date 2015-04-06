---
layout: post
title: "Microservices for Enterprises Part I"
modified:
categories: 
comments: true
tags: [microservices, design, agile, IaaS, PaaS, cloud]
image:
  feature:
date: 2015-04-06T16:38:17-07:00
---

Technology is the foundation of differentiation whether you're a large enterprise or the small startup. If businesses fail to embrace that fact, they run the risk of losing marketshare and ultimately headed for the history books. Providing new services, products, or innovative creativity to improve the experience of existing services all have a foundation in technology and IT can help you deliver that. For IT groups, however, the task is daunting: support a rapidly changing and innovating business, keep up with the latest technologies that bring value, and at the same time provide stable and secure environments for existing assets.

![cat money](/images/risky.jpg)

We have fancy new technologies that deliver "cloud" services to us with a few clicks and swipe of a credit card. Or we can set up our own private clouds and host on our own infrastructure in our own data centers. We also have programming languages, frameworks, databases, caching solutions, et. al. that claim to help us differentiate. The new technology is great for the startups who build their teams to take advantage of this quick moving technology, prototype daily, and try out new things, but how do big enterprises leverage new technology and methodologies to differentiate themselves without sacrificing existing stability and revenue?



## Culture
Large organizations have a reputation for being slow or adverse to change. Those on the outside of large companies believe this might be true because they're old-fashioned, make a lot of money, and don't want to take risks. Inside those companies I hear something different. They absolutely want to change; they make a lot of money, but they absolutely want to make a lot more money. So what's holding them back? When it comes to IT, I believe it's a cultural and philosophical roadblock. Large organizations that invest in technology have long organized their development and operations teams with the assumption that critical technology resources like servers, networks, storage, middleware and applications are scarce resources. Because of this scarcity, they must take care to properly dole out resources, organize teams according to technology specializations, and instituting heavy processes to coordinate change amongst these divisions. This fosters a culture of "if it ain't broke don't fix it" and "playing it safe", i.e, the feeling that IT cannot (or will not) keep up with the changing business. However, with the popularization of cloud technologies, especially those honed in opensource communities, we can now rethink some of these assumptions and allow teams to achieve more autonomy without worrying as much about trying to share all resources and cross-functional synchronization. For example, a team working on a set of "loyalty services" own their services. If they want very deep control over the infrastructure they run their services on, they can self-provision instances on a public IaaS or an internal IaaS like OpenStack. They can manage the Operating System, networking, storage, and of course their applications. If they don't need that sort of control, they can relinquish that responsibility and rely more on a PaaS. They can spin up applications in whatever technology stack they prefer and expect the platform to take care of all of the lower-level infrastructure details. They can spin up new instances in whatever cloud platform they wish, prototype their applications, develop continuous integration or continuous delivery practices, and manage the lifecycle of their services up to production. This sort of autonomy employed by companies like Amazon or Netflix is part of a much wider cultural foundation. Cloud solutions can enable and foster this type of culture, however, it's still to be determined whether large enterprises can adapt.

## Enterprise needs
Besides all of the automation, flexibility, and freedom cloud services bring, what about our enterprise services? You have existing tools that you've invested quite a bit of money in an attempt to give you business agility and insight; tools like complex event processing/analytic engines, business process management suites, messaging infrastructure, integration buses, monitoring suites, databases, and others. Are those systems you can bring along with you "to the cloud?" Or do you have to rewrite everything? Have you invested in large heavyweight tooling that fits into cloud services like a square peg into a round hole? Or have you vetted your decisions to be able to take advantage of the autonomy that cloud infrastructures can deliver? Not everything in enterprises can be a 12-factor stateless app; choosing architectures and tools appropriate for the desired goals is important, and having cloud infrastructure to support this without prescriptive tradeoffs is key. 

## OpenSource FTW!
At the end of the day, I believe open source and open communities will be (and currently is) the best place to build out both the cloud solutions and the business middleware that these large companies will leverage. For example, the Docker and Kubernetes projects are both opensource, have contributors from various companies, and are thriving ecosystems on which we can build innovative cloud technologies. Moreover, companies will be leveraging cloud platforms to build out their own applications and innovate for their competitive business landscapes, and having the proper company culture, infrastructure, and middleware will all be factors that determine how successful any cloud initiative will be.



