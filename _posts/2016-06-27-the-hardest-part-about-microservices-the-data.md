---
layout: post
title: "The Hardest Part About Microservices: The Data"
modified:
categories: microservices
comments: true
tags: [microservices, monlith, wildfly-swarm, docker, kuberetes, openshift, architecture]
image:
  feature:
date: 2016-06-27T11:43:58-07:00
---

As I've been promising in my past few articles about [event-driven systems](http://blog.christianposta.com/microservices/why-microservices-should-be-event-driven-autonomy-vs-authority/) and [carving up the monolith](http://blog.christianposta.com/microservices/carving-the-java-ee-monolith-into-microservices-perfer-verticals-not-layers/), here's the next installment in a series of articles trying to tackle the hard parts about microservices. Follow me ([@christianposta](http://twitter.com/christianposta)) to keep up! 

So what do I mean about "hard parts"? Well, instead of just waving  hands around saying "your microservices should have their own database" or  "your microservice should do one thing well", or my personal favorite "your microservice should be replaceable" I think people need to understand that microservices is not a free lunch and require a completely different way of thinking to be successful (see below). These are all useless platitudes IMHO but they're repeated ad-naseum. Anybody can say "your microservice should have separate databases" as though a commandment from the Microservices gods, but that doesn't really help anybody. What about transactions? What about consistency? What about queries? What about database partitioning? What about database changes? What about all of the network hops and overhead you introduce by breaking up your databases?

Stick with me: the hardest part about microservices is your data and you cannot hand-wave this away. 

I'll refer to the work I've been doing to help illustrate these concepts along the way in the [TicketMonster microservices implementation](https://github.com/search?utf8=✓&user=christian-posta&q=ticket). You should refer to the [Ticket Monster monolith](http://developers.redhat.com/ticket-monster/) as well for reference.

##  What are we thinking!?


Let's take a quick step back. The goals of a microservices architecture is:

* Business agility
* Autonomous systems and teams
* Scalability 

But we don't think in terms of that in any appreciable way. This is how we think:
 
* We try to ignore the domain as much as we can
* We are too brainwashed to think only in terms of a "single database" and single "canonical data model"
* We strive for "efficiency" above all else 

When we think like that, we are at odds with what we really want to achieve: business agility. You can call your new code base a "microservice" all you want, but it doesn't matter what you call it. 

For example SOA, when it started, had a lot of the same goals as microservices. But we proceeded to build layers and layers of "reusable" services kind of like the way we build machines.  We build machines by efficiently reproducing the individual parts that make up a machine and then carefully assembling the pieces. The parts for a specific machine are quite purpose built. This ends up being great if we are trying to churn out lots and lots of machines. It becomes very expensive and brittle in response to change. If we want to change one component in a purpose-built machine, we'll probably need to change the component adjacent to it and so on. Machines are not built for flexibility by design; they're built to do a set of functions over and over. Nor have our monoliths or SOA implementations been built for flexibility. We build a common set of "reusable" data services. On top of that we build a few layers of activity services. On top of that, we build process services, and so on and on. And if you didn't do these layers "you weren't doing SOA" and that's what we did strive for right? Thing is, you change one of those business process services now you have to change every layer underneath it and you have nasty ripple effects. [Don't build your overall architecture in layers!]((http://blog.christianposta.com/microservices/carving-the-java-ee-monolith-into-microservices-perfer-verticals-not-layers/) 

We've even built our teams as efficiently as possible. We have DBAs who only focus on database maintenance. We have developers only focused on coding, QA on testing, etc. Each team is shielded from the overall goal of the system and to make any changes we've got to file tickets and processes, and workflows, and so forth. Trying to build for business agility by focusing on efficiency, premature optimization, and ["reuse" is a terrible idea](http://blog.christianposta.com/design/the-cost-of-code-reuse-abuse/). Why should it take loads of tickets and 18 month planning cycles to make a change to your system?

What about databases? Why do we assume everything is one single large database? Maybe because the vendors who've sold us large SOA suites and monolithic application server suites all have their flagship products based on that thinking? We've built our distributed systems as though they're all a single in-memory process and mimic that with lots of RPC and even lots of baggage on top of RPC.. remember SOAP, WS-*? We've tried implementing transactions across distributed systems as though it's all just one big database with Two Phase Commit transactions etc. 

Lastly, we somehow thought lots and lots of centralized governance and micromanagement was a conduit to business agility. How that came about I still don't know. Management teams practice "agile" to squeeze even more pain out of their developers. And we employed lots of complex governance workflows and processes that cause any small amount of change to cause 5 different silos with 5 different VPs to get together and come up with the lowest common denominator.
 
So what if we thought about things differently. Let's see.

## Ticket Monster moves to microservices
At the fictitious Ticket Monster company the VPs are lamenting how long it takes to make changes to their bread and butter ticket-selling website. They want to add new features like a waitlist for tickets that aren't currently available, a rewards program for those folks who buy a lot of tickets, a recommendation engine, personalized mobile app, social integration and much more. They've decided to organize their teams around the business functionality that underpins the website and are even willing to adopt new technology where it fits. They want to improve their local development processes across developers as it's currently quite difficult to get the current version of the code deployed locally to work on. They currently have a complicated big-bang release process that they will also need to sort out. 

The Ticket Monster app is a layered Java EE with a single backing database. The teams agreed to start off the decomposition process by implementing a process based on an important first principle: We want to encourage changes to the system (otherwise how are we going to decompose!) so we need to have a safe way to deploy changes, test them, AND even more importantly, a way to rollback or undo a change. The teams decided that using Docker they can package their applications and configuration in a repeatable, consistent manner. With Docker, they can package all of their dependencies (including the JVM! remember, the JVM is a very important implementation detail of any application) and run them on their laptops as well as in dev/qa/production and remove some of the guessing about what's different across systems. No matter how much we try, how stringent our change process is, or what best-of-breed configuration automation, we always seem to end up with differences in the operating system, the app servers, and the databases. Docker helps ease that pain and helps us reason about a consistent software supply chain to deliver our applications. More on that in a bit. 

The original Ticket Monster application is a Java EE war file with all of the layers packaged as a single deployable. It gets deployed into a WildFly 10/EAP 7 application server and has extra notes in the JIRA tickets to configure the database connections and so forth. Our first step is to codify all of this from the WAR to the WildFly server to the JVM and all of the JVM dependencies into a single Docker container. We will continue to run the database outside of the Docker environment to begin. Later we'll come back and see how a Docker environment can easy our automation of managing and upgrading the database as well. 

At first, the development team started by making their development environments (on their laptops) Docker capable. They also changed their shared Dev environment to match similarly to their laptops with Docker. They set up a Jenkins CI build to build their docker container and deploy into Dev when they had new versions. They did this as a first step to get their hands familiar with Docker and identify what type of software supply chain they would need (OS, Middleware, tooling, and eventually their code) as well as get familiar with immutable delivery principles.  But everything from QA on up to Prod was still the old way of doing things. They were off in the right direction, but still not there.

### Deployments
The ticket monster teams were taking good advantage of Docker for deployments but they wanted to be able to do more sophisticated things like clustering their application and ability to do blue-green deployments to move to zero-downtime deployments. See here for [more about blue-green deployments and other deployments like canary and A/B testing, etc](http://blog.christianposta.com/deploy/blue-green-deployments-a-b-testing-and-canary-releases/). They also thought initially about breaking up their services and wondered how they would discovery and load balance across each other. Since they were already using Docker, they decided the awesome [Kubernetes project](http://kubernetes.io) would help them get to a _smarter_ cluster deployment. They decided to leverage Kubernetes to deploy their application in a cluster and started to take advantage of blue-green deployments which are a native feature of Kubernetes. They ran into some issues, however. What do they do with the database? A blue-green deployment basically allows you to stand up a new version of your application alongside the existing version. Initially, it does not take any load and is hidden from clients. You can start it up, do some basic smoke tests, and when you're ready, switch over the load to the new version. The team had questions about what to do with the database?

They settled on the following approach, and it's one they would continue to use after they've split up the monolith.

* deploy the new version of the app into its own cluster (running in Docker, managed by Kubernetes). this new version of the app would have a flag in it that, if enabled, would enable the new features of the application. On this release, the flag would be disabled so as to mimic as close as possible the previous version.
* now a new version of the tables would be applied to the database. the team decided to use the awesome [Liquibase](http://liquibase.org) project to handle configuration management/schema management of the database including rollbacks if needed. an important part about this part is that the previous version of the application would be able to deal with changes of the schema as long as they were backward compatible. non-backward compatible changes would be dealt with a different way (discussed later). 
* now the new version of the application is smoke tested. this could be something like running a test with a sampler user in the database or something similar.
* now the team has two options: first they could try a blue-green deployment by changing the [kubernetes service](http://kubernetes.io/docs/user-guide/services/) that's pointing to the old version to point to the new version. this would be an all-in-one switch over to the newly deployed version and would start taking production load. the risk here would be small (although still risk) as the new version would still be running as close to the old version as possible (because the flag was not switched). if everything works fine, at this point, you can proceed to the next step. or, they would switch the kubernetes service back to point to the old version. Alternative would be to try a canary release of the new version into production and see how it responds. for this, you could easily just change the labels of one of the services to match that of the current kubernetse service. 
* at this point you can employ a rolling upgrade to enable the flag of the new version. you can use a canary strategy here as well. if everything looks good you continue to enable the new version of the service by switching the flag.

Two main takeaways from this strategy (and there are variants of it as needed):

* First, if you're doing a deployment of a service/application you may have to do it in phases as above (another approach is discussed later). You may mix a combination of blue/green, canary, and rolling upgrade 
* Although we prefer pure immutable deployments, we can make a calculated deviation by moving the upgrade along slowly with version/feature flags.

### Breaking down the monolith
Now the ticket monster teams have a system in place for deploying the existing monolith in a safe, repeatable manner including rollbacks. They use Docker containers to take advantage of immutability and packaging as they move through a deployment pipeline and use Kubernetes to manage the cluster including rolling-upgrades, blue-green deployments, canary releases, starting/stopping pods, etc. Now they need to explore how best to break up the application.

Ideally we end up with autonomous services that own their entire vertical of the system. This includes User Interface components, service/domain components, and choice of backend persistence. But first iteration, they will try to break the UI components as a complete layer out of the monolith. Layers are not the goal, but they can be an intermediate step. If you take a look at the [Ticket Monster UI project](https://github.com/christian-posta/ticket-monster-ui) you'll see we've done just that. We even took the UI layer and put them into a http server complete with a forward proxy (httpd in this case). We did this for two reasons:

* We don't need to run the UI in a Java EE server since it's just a static set of JS/CSS/HTML resources
* We want to be able to use a forwarding proxy to obscure the actual locations of the would-be microservices in the backend.

Now with the forward proxy in place, we can not only hide the backend microservices that we'll build out, but we can side step having to enable [CORS](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing) on everything and also keep the security implementation a little simpler. We'll get to security later. 

The UI gets deployed as a Docker container inside of Kubernetes. The forwarding proxy will eventually map calls to backend microservices to the internal Kubernetes DNS name. For example:

.....put example here......



#### Determinig the boundaries

We split out a single layer of our application into a "UI" service, but that's the last layer we create. We want to create [verticals or self-contained systems](http://blog.christianposta.com/microservices/carving-the-java-ee-monolith-into-microservices-perfer-verticals-not-layers/) instead of layers. These SCSs will own their own database and their own service layers. So how do we go about breaking up the application.

For most enterprise applications, we will want to focus our boundaries around the [DDD concept of Bounded Context](http://martinfowler.com/bliki/BoundedContext.html). It's imperative that we don't just start breaking out services into "smaller" services based on technical function or some ambiguous metric like lines of code. It's absolutely paramount that we split our application into boundaries guided by the domain. Note, you may  not see the internet companies doing this as fastidiously. There's a good reason: they don't know about DDD. They don't care about it. Their domains, mostly, are quite simple. They deal with a different problem: that of scale. Posting tweets to twitter is an insanely simple "domain". You don't need DDD for that. Posting tweets from 100s of millions of users and trying to deduce the twitter "follower" stream for all those users is crazy complicated. But enterprises will have to deal with complexity in the domain _as well as_ potentially scale. Don't overlook the importance of modeling the domain as a way to prepare for performance and scale. They're both highly intertwined. 