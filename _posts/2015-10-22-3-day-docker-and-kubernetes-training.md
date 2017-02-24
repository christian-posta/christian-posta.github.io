---
layout: post
title: "4-day Docker and Kubernetes Training"
modified:
categories: [kubernetes]
comments: true
tags: [openshift, kubernetes, docker, training, PaaS, cloud, containers, popular]
image:
  feature:
date: 2015-10-22T16:10:41-07:00
---

I just delivered a 4-day deep-dive training course on Docker and Kubernetes to a customer in Atlanta. In true open-source spirit, I'd like to [publish the source/slides](https://github.com/RedHatWorkshops/docker-kubernetes-workshop) and allow other people to benefit from it and contribute to making it better. Kubernetes is such an awesome project, and I learned a lot by doing this training. If you're interested in hearing how awesome kubernetes is, and how we've made it even better with openshift, get a hold of me (@christianposta)!


![kube](/images/kube.png)

## Intro

[http://christianposta.com/slides/docker/generated/intro.html](http://christianposta.com/slides/docker/generated/intro.html)

Introductions: how to set up the environment, etc.

## Day 1

[http://christianposta.com/slides/docker/generated/day1.html](http://christianposta.com/slides/docker/generated/day1.html)

This course does _not_ assume familiarity with any of the technologies on which we're training. We do assume a basic understanding of what VMs are as well as a little familiarity with Linux (ie... "it's not windows" seems a reasonable place to start). On the first-day we take a very high-level over of Docker, describe what it is, why it's caught fire, what things in your development and operations processes it can greatly improve. Then we start to explain some of the concepts, get you started with Docker on your laptop (Windows/Mac/Linux), and walk you through some hands-on labs. Later in the first day, we dig into concepts like Images, Links, Volumes, how that's all implemented, and the powerful things you can do with them.

## Day 2

[http://christianposta.com/slides/docker/generated/day2.html](http://christianposta.com/slides/docker/generated/day2.html)

Day two builds on our understanding of Linux containers: but while you're consumed with the awesomeness of Docker, we quickly burst that bubble and point out the areas that it lacks. Using containers in any non-trivial environment requires more than what the Docker format and API bring, so we talk about a little higher-level concepts like managing applications, abstracting away VMs and infrastructure, designing cloud-native apps for failure and to be resilient, etc. Then we talk about the benefits of those thoughts as well a the tough technical challenges. 

We dig into kubernetes, how simple it is, and what powerful constructs are built on top of it, including clustering, application management, stateful cloud applications, resiliency to failures, etc. We cover all of the simple concepts like Pods, Labels, Replication Controllers and Services. We also show how to install kubernetes on your local machine (Windows/Mac/Linux) and a lot of learn-by-example: ie, hands on guidance.

## Day 3

[http://christianposta.com/slides/docker/generated/day3.html](http://christianposta.com/slides/docker/generated/day3.html)

Day three continues where we left off with Day2. We dig into slightly more complex kubernetes concepts like Security, High Available masters, namespaces/grouping, Logging, Metrics collection, and DNS addons. This gives us the fundamentals to introduce higher-level concepts like the different type of zero (or near-zero) downtime deployments like Rolling updates/rollbacks, canary releases, blue/green deployments, A/B testing, etc. 

These concepts naturally lead into discussions on CI/CD. We also dig into that, with demos, explaining some of the glue tooling you can use to leverage some of your existing tooling and processes and combine with these tools to realize a CI/CD process.


## Day 4
All throughout, we talk about how great these technologies are as the base for a scalable, flexible, easy-to-consume cloud architecture. However, as we touch on throughout the course, for these technologies to be adopted in any meaningful way in large enterprises, there are considerations around networking, role-based access controls, security, registry, monitoring, etc that must be solved whether you take the onus on yourself or what not. We end day 4 talking about what OpenShift is, the parts of the puzzle it fills in with a focus on what our enterprise customers expect from a set of services like this. We also talk at a little higher level, like building microservices and how the pressures and complexities of microserivces can be alleviated with these tools.

Thanks to all that joined in person, and look forward to doing it again!


BTW, don't miss [my talk/workshop at the first Kubernetes Conference](http://sched.co/4Wc9): [kubecon.io November 9-12 in San Francisco!](http://kubecon.io)