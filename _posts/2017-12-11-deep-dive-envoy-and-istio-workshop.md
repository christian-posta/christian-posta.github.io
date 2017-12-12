---
layout: post
title: "Deep Dive Envoy and Istio Workshop"
modified:
categories: microservices
comments: true
tags: [microservices, istio, envoy, service mesh, resilience, sidecar]
image:
  feature:
date: 2017-12-11T19:01:31-07:00
---

Just getting back from KubeCon 2017 and I can tell you the excitement about [Istio](https://istio.io) and service mesh in general is through the roof! There were lots of talks about Istio/service mesh (including a panel with [Matt Klein](https://twitter.com/mattklein123), [Jason McGee](https://twitter.com/jrmcgee), [Lin Sun](https://twitter.com/linsun_unc), [William Morgan](https://twitter.com/wm), Sven Mawson and myself).

![](/images/istiologo.png)

There is [lots](https://blog.openshift.com/evaluate-istio-openshift/) [of great](http://blog.christianposta.com/microservices/00-microservices-patterns-with-envoy-proxy-series/) [material](https://developer.ibm.com/dwblog/2017/istio-service-mesh-kubecon-news-announcements/) coming out about Istio including a [istio workshop](https://github.com/ZackButcher/istio-workshop) delivered by [Zach Butcher](https://twitter.com/ZackButcher) et. al. at KubeCon. 

I've [started putting together a workshop diving deeper into how Istio works](http://blog.christianposta.com/istio-workshop/slides/#/title). including exploring in detail parts of Envoy (the default Istio proxy), and the core components like Pilot and Mixer. 
 
 
This workshop starts off at a high level, but make no mistake: it's intended to be at a lower level and hands on. We walk through some pieces of the Istio technology with the hope of giving the attendee/reader a good understanding of how the pieces come together, how to debug things when there are issues, and how to become more comfortable with Istio and Envoy.


DISCLAIMER: this material is a work in progress; expect to see updates frequently. 

The agenda as it is right now:

* How did we get here?
* Meet Envoy Proxy
* Hands on with Envoy Proxy
* Meet Istio Service Mesh
* Hands on with Istio Service Mesh<
* Additional resources


Ideally, I'd like to get this into a good state and donate to the Istio repositories directly. 

I really need feedback on the material! Please [take a look](http://blog.christianposta.com/istio-workshop/slides/#/title) and [let me know](http://twitter.com/christianposta) if you have any feedback, comments, ideas. Thanks, and [follow along on twitter](http://twitter.com/christianposta) for updates. 