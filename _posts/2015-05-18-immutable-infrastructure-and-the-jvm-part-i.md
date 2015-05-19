---
layout: post
title: "Immutable Infrastructure, hotdeploys, and the JVM"
modified:
categories: immutable
comments: true
tags: [JVM, immutable, docker, OSGI, classloaders]
image:
  feature:
date: 2015-05-18T18:57:43-07:00
---

Do you deploy and undeploy your JVM-based applications (regardless of JVM container/no-container) in production? ie, when you have new versions of an app or service, do you mutate the running JVM by "undeploying" and "hot deploying" the new, updated version of that app? Or, do you try to "move" a deployment of your application from one JVM to another at runtime?

![no test, no beer](/images/austinpowers.png)

The capabilities of many popular JVMs allow you to do this. Whether it's an advanced Java EE container, popular servlet container, or even OSGI container, we can quite easily undeploy and deploy applications at runtime for various reasons. However, I ask, is that a good practice?  Maybe it's just me, but I really think this is an absolutely dreadful practice; but what are your operations/DevOps teams doing?

I'd like to quickly blog on it from the perspective of the "immutable infrastructure" tread that is taking hold with the change in DevOps tooling starting with linux container formats.

[James Strachan](http://en.wikipedia.org/wiki/James_Strachan_(programmer)) recently wrote on his blog about the impact of Docker to the JVM ecosystem in his post [the decline of Java application servers when using docker containers](https://medium.com/@jstrachan/the-decline-of-java-application-servers-when-using-docker-containers-edbe032e1f30). If you haven't read it, I encourage it. 

One of the things he touches on is the JVM's susceptibility to memory leaks when dynamically undeploying and hot deploying applications. After a single redeploy, you may end up with a system that is unstable or unpredictable because of leaked objects, class structures, database connections, sockets, threads, class loaders, et.al.. 

And in may circumstances, leaking these objects is --> [very](https://plumbr.eu/blog/memory-leaks/what-is-a-permgen-leak) [easy](http://wiki.apache.org/tomcat/MemoryLeakProtection) [to do](http://zeroturnaround.com/rebellabs/rjc201/) <--

So maybe destabilizing our runtime deployments by hot deploys/redeploys is a bad thing to do.

 
So what options do we have? What about bringing up a new instance of the JVM in question with newly configured and deployed applications, controlling everything we can about the start order and deployment configurations. Then we can direct traffic from the older instance to the newer instance, and terminate the older instance at an appropriate time. 

Is this enough?

Well, the question is aimed squarely at whether or not the new applications and the new permutations of services (new versions, new configurations, along with the things that didn't change... i.e., codeployed services, etc) have even been tested together properly. The assumption that I personally make with any combination of applications and services that will be deployed to production is that the same permutation has been tested _exactly as is_ in lower environments. ie, that the exact set has been deployed in DEV, QA, IST, UAT, Prod Mirror, Prod, etc. The only way to change services in production is to properly test them in lower environments.

This line of thinking is predicated on strong automation, coherent testing, and an established set of disciplines and processes for moving changes to a system from inception to production. Linxu containers and image formats bring an vast improvement to the tooling for being able to do this, but the mindset and these best practices can be instilled even today (ie, even before you're able to move to Docker/Rocket/image formats):
  
* Don't hotdeploy/redeploy/migrate your java services in production at runtime
* Do have a very strong focus on your delivery pipeline/automation/testing to quickly make changes to your system






