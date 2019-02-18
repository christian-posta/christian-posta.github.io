---
layout: post
title: Guidance for Building a Control Plane for Envoy - Identify Components
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-02-18T13:36:17-07:00
---

## Identify which components you need for your control plane

As the spectrum of operating environments varies wildly, so too could the components needed to implement a control plane for Envoy. For example, at one extreme, if you have Envoy files statically generated at build time and shipped to your Envoy, you will need components like:

* Template engine
* Data store / VCS
* Per-service configurations
* An orchestrator to put the pieces together
* A way to deliver these to Envoy and hot restart

On the other hand, if you opt to use the gRPC streaming xDS implementation, you'll need:

* The core xDS service
* A discovery registry + whatever integrations you need 
* An abstract object model to describe your Envoy configuration


Other ancillary components you'd most likely need to support operations of Envoy:

* Certificate/CA store
* Statistics collection engine
* Distributed tracing backend/engine
* External authentication
* Rate limiting services

In general, you'll want to consider building your control plane so that the components run independently and can loosely collaborate to provide the needs of the control plane. For example, in Gloo we have the following components that drive the basic control plane:

* `Gloo` -- an event-driven component responsible for the core xDS services and configuration of custom Envoy filters
* `Discovery` -- an optional component that knows how to work with service discovery services (Consul, Kubernetes, etc) to discover and advertise upstream clusters and endpoints. It can also discover REST endpoints (using swagger), gRPC functions (based on gRPC reflection), and AWS/GCP/Azure cloud functions. This component creates configuration (on Kubernetes, it's represented with [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)) that the `Gloo` component can use to build the canonical Envoy configurations represented through xDS. We'll see more in later sections of this series of blogs.
* `Gateway` -- This component allows users to use a more comfortable object model to configure an Envoy Proxy based on its role (ie, edge gateway, shared proxy, knative cluster ingress, etc). This part of the control plane also generates configuration that the `Gloo` control plane can use to generate Envoy configuration through xDS

As  you can see these base components work in concert to build the appropriate Envoy configuration served through xDS. Gloo implements a lot of its power (discovery capabilities, semantic understanding of a function, etc) by using these losely coordinating control-plane components that work to serve Envoy configuration. When Gloo is deployed into Kubernetes, the storage and configuration representations take on a "kube-native" feel: everything is represented by [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). Specifically, all of the user-facing configurations are CRDs as well as the core configuration that drive the xDS endpoints. You can just use the Kubernetes API and kubectl to interact with Gloo. However, we also provide a `glooctl` [CLI tool to simplify interactions with the Gloo control plane](https://gloo.solo.io/cli/) -- specifically so you don't have to fuss around with all the YAML if you don't want to. In this way, Gloo is very focused on developer experience and hacking YAML for developers (or anyone?) can be quite tedious.

Istio also takes a similar approach of using loosely coordinating control-plane components that are configured through Kubernetes CRDs. Istio's control plane is made up of:

* `Istio Pilot` -- the core xDS service
* `Istio Galley` -- a configuration/storage abstraction 
* `Istio Citadel` -- a CA/certificate engine
* `Istio Telemetry` -- a sink for telemetry signals
* `Istio Policy` -- a pluggable policy engine


### Takeaway
Identify the core components you'll need for your control plane. Don't try to build a single, monolithic control plane abstraction as that will become a nightmare to maintain and update. Build the components you want for your control plane in a loosely coupled architecture. If you can build on top of Kubernetes, then do so: [Kubernetes provides a very powerful integration data plane](https://medium.com/@allingeek/kubernetes-as-a-common-ops-data-plane-f8f2cf40cd59) for operating distributed systems, such as an Envoy control plane. If you do build a control plane on top of Kubernetes, you should leverage [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) to drive configuration of your control plane. Some folks have chosen to build their control plane using [Ingress definitions](https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md), [service annotations](https://www.getambassador.io/reference/configuration/), or [configuration maps]( https://www.youtube.com/watch?v=a1tXFUrqt5M&list=PLj6h78yzYM2PF_iYEBntfR0m4KAZET18Q&index=14&t=0s). These may have been appropriate work-arounds before Kubernetes CRDs were available but at this point you should avoid those paths and stick with CRDs.
