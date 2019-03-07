---
layout: post
title: Guidance for Building a Control Plane for Envoy Part 2 - Identify Components
modified:
categories: envoy
comments: true
tags: [control plane, microservices, envoy, istio, contour, gloo]
image:
  feature:
date: 2019-02-18T13:36:17-07:00
---

This is part 2 of a [series](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-to-manage-envoy-proxy-based-infrastructure/) that explores building a control plane for Envoy Proxy. 

In this blog series, we'll take a look at the following areas:

* [Adopting a mechanism to dynamically update Envoy's routing, service discovery, and other configuration](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-to-manage-envoy-proxy-based-infrastructure/)
* Identifying what components make up your control plane, including backing stores, service discovery APIs, security components, et. al. _(this entry)_
* [Establishing any domain-specific configuration objects and APIs that best fit your usecases and organization](https://blog.christianposta.com/)
* Thinking of how best to make your control plane pluggable where you need it
* Options for deploying your various control-plane components
* Thinking through a testing harness for your control plane

In the [previous entry to this series](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-to-manage-envoy-proxy-based-infrastructure/) we explored dynamically configuring Envoy which is an important part of running Envoy in a cloud-native environment. In this entry, we take a look at the cooperating components you may need to support your control plane. 


## Identify which components you need for your control plane

As the spectrum of operating environments varies wildly, so too could the components needed to implement a control plane for Envoy. For example, at one extreme, if you have Envoy files statically generated at build time and shipped to your Envoy, you may need components like:

* Template engine
* Data store / VCS for the values that go into the templates
* Any service-specific configurations that may/may not be stored with the services/applications
* An orchestrator to put the pieces together 
* A way to deliver these to Envoy 
* A way to trigger a reload/hot-restart of the configuration files

On the other hand, if you opt to use the gRPC streaming xDS implementation, you'll need:

* The core xDS service interface and an implementation
* A component to handle registering/deregistering services into the service registry
* A service registry
* An abstract object model to describe your Envoy configuration (optional)
* A data store to hold the configuration


Other ancillary components you'd most likely need to support operations of Envoy:

* Certificate/CA store
* Statistics collection engine
* Distributed tracing backend/engine
* External authentication
* Rate limiting services

In general, you'll want to consider building your control plane so that the components run independently and can loosely collaborate to provide the needs of the control plane. The last thing you want to do is support a microservices deployment with Envoy by deploying a monolith control plane. For example, in the [open-source Gloo project](https://gloo.solo.io)] we have the following components that drive the control plane:

* `Gloo` -- an event-driven component responsible for generating configuration for and serving the core xDS services and configuration of custom Envoy filters
* `Discovery` -- an optional component that knows how to work with service discovery services (Consul, Kubernetes, etc) to discover and advertise upstream clusters and endpoints. It can also discover REST endpoints (using swagger), gRPC functions (based on gRPC reflection), and AWS/GCP/Azure cloud functions. This component creates configuration (on Kubernetes, it's represented with [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)) that the `Gloo` component can use to build the canonical Envoy configurations represented through xDS. We'll see more in later sections of this series of blogs.
* `Gateway` -- This component allows users to use a more comfortable object model to configure an Envoy Proxy based on its role (ie, edge gateway, shared proxy, knative cluster ingress, etc). This part of the control plane also generates configuration that the `Gloo` control plane can use to generate Envoy configuration through xDS

![](/images/control-plane/gloo-control-plane.png)

As  you can see these base components are deployed as services that work in concert to build the appropriate Envoy configuration served through xDS. Gloo implements a lot of its powerful discovery capabilities, semantic understanding of a function, etc by using these loosely coordinating control-plane components that work to serve Envoy configuration. When Gloo is deployed into Kubernetes, the storage and configuration representations take on a "kube-native" feel: everything is represented by [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). Specifically, all of the user-facing configurations are CRDs as well as the core configuration that drive the xDS endpoints. You can just use the Kubernetes API and kubectl to interact with Gloo. However, we also provide a `glooctl` [CLI tool to simplify interactions with the Gloo control plane](https://gloo.solo.io/cli/) -- specifically so you don't have to fuss around with all the YAML if you don't want to. In this way, Gloo is very focused on developer experience and hacking YAML for developers (or anyone?) can be quite tedious.

Istio also takes a similar approach of using loosely coordinating control-plane components that are configured through Kubernetes CRDs. Istio's control plane is made up of:

* `Istio Pilot` -- the core xDS service
* `Istio Galley` -- a configuration/storage abstraction 
* `Istio Citadel` -- a CA/certificate engine
* `Istio Telemetry` -- a sink for telemetry signals
* `Istio Policy` -- a pluggable policy engine

![](/images/control-plane/istio-control-plane.png)


Heptio Contour actually has only two components that makes up its control plane, however, since it's based solely on Kubernetes, it actually leverages a lot of built-in Kubernetes facilities like the Kubernetes API/Storage, and CRDs for driving configuration. 

* `contour` server
* `init-container` bootstrap

![](/images/control-plane/contour-control-plane.png)

Contour uses an `init-container` to generate a static bootstrap configuration file for Envoy that tells where to find the xDS services. The xDS server is the second component in the control plane and is by default deployed alongside the data plane with an option to deploy separately. We'll look at this architecture and its tradeoffs in part 5 of this series "Deploying control-plane components".

### Takeaway
Identify the core components you'll need for your control plane. Don't try to build a single, monolithic control plane abstraction as that will become a nightmare to maintain and update. Build the components you want for your control plane in a loosely coupled architecture. If you can build on top of Kubernetes, then do so: [Kubernetes provides a very powerful integration data plane](https://medium.com/@allingeek/kubernetes-as-a-common-ops-data-plane-f8f2cf40cd59) for operating distributed systems, such as an Envoy control plane. If you do build a control plane on top of Kubernetes, you should leverage [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) to drive configuration of your control plane. Some folks have chosen to build their control plane using [Ingress definitions](https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md), [service annotations](https://www.getambassador.io/reference/configuration/), or [configuration maps]( https://www.youtube.com/watch?v=a1tXFUrqt5M&list=PLj6h78yzYM2PF_iYEBntfR0m4KAZET18Q&index=14&t=0s). These may have been appropriate work-arounds before Kubernetes CRDs were available but at this point you should avoid those paths and stick with CRDs. Like Tim Hockin (founder of Kubernetes) said on a recent podcast, annotations for driving an Ingress Gateway resource is a poor choice. 

The next entry in this series is actually already posted: [Guidance for Building a Control Plane for Envoy Part 3 - Domain Specific Configuration API](http://blog.christianposta.com/)
