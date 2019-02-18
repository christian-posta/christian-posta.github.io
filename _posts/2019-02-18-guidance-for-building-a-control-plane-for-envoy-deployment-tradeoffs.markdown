---
layout: post
title: Guidance for Building a Control Plane for Envoy - Deployment Tradeoffs
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-02-18T13:38:53-07:00
hidden: 1
---

## Deploying control plane components

Once you've built and designed your control plane, you'll want to decide exactly how its components get deployed. You have some choices here from co-locate control plane with the data plane all the way to centralize your control plane. There is a middle ground here as well: deploy some components co-located with the control plane and keep some centralized. Let's take a look.

In the Istio service-mesh project, the control plane components are deployed and run centralized and managed separately from the data plane. That is, the data plane runs with the applications and handles all of the application traffic and communicates with the control plane via xDS APIs over gRPC streaming. The control-plane components generally run in their own namespace and are ideally locked down from unexpected usage. 

The Gloo project follows a similar deployment model. The control-plane components are decoupled from the data plane and the Envoy data plane uses xDS gRPC streaming to collect configuration about listeners, routes, and clusters, etc. You could deploy the components co-located with the dataplane proxies with Gloo, but that's discouraged. We'll take a look at some of the tradeoffs in a bit.

Lastly, we take a look at co-deploying control plane components with the data plane. In the Contour project, by default, control plane components are deployed with the data plane though [there is an option to split up the deployment](https://github.com/heptio/contour/blob/master/docs/deploy-seperate-pods.md). Contour actually uses leverages CRDs or Ingress resources for its configuration, so all of the config-file handling and watching happens in Kubernetes. The xDS service, however, is co-deployed with the dataplane (again, that's by default -- you can split them).

When [eBay built their control plane for their deployment of Envoy]( https://www.youtube.com/watch?v=a1tXFUrqt5M&list=PLj6h78yzYM2PF_iYEBntfR0m4KAZET18Q&index=14&t=0s), they also co-deployed parts of their control plane (the discovery pieces) with their data plane. They basically wrote a controller to watch CRDs, Ingress, and Service resources and then generate config maps. These config maps would then be consumed by the `discovery` container running with the Pod and served to Envoy.

![](/images/control-plane/ebay-control-plane.png)
![](/images/control-plane/double-click-ebay-control-plane.png)

#### Should I keep control planes separated out?

There are pros and cons to the various approaches. [The Gloo team](https://github.com/solo-io/gloo/graphs/contributors) believes keeping the control plane separate is the right choice for most use cases, but that there could be optimization or extenuating reasons why you may co-locate some of the components. 

If Envoy is the heart and soul of your L7 networking, the control plane is the brains. The control plane necessarily will have different characteristics when it comes to:

* Security -- If somehow your dataplane gets compromised, you're in a world of hurt; you definitely do NOT want to exacerbate your situation by giving up control to the rest of your applications and network by allowing your control plane to become compromised. Additionally, a control plane could be dealing with distribution of keys, certificates, or other secrets that should be kept separate from the data plane. 
* Scaling --  You probably will end up scaling your data plane and control plane differently. 
* Grouping -- You may have different roles and responsibilities of the data plane; for example, you may have data plane Envoys at the edge which would need a different security and networking posture than a pool of shared proxies for your microservices vs any sidecar proxies you may deploy. Having the control plane co-located with the data plane makes it more difficult to keep data and configuration separate
* Resource usage -- You may wish to assign or throttle certain resource usage depending on your components. For example, your data plane may be more compute intensive vs the control plane (which may be more memory intensive) and you'd use different resource limits to fulfill those roles. Keeping them separate allows you more fine-grained resource pool options than just lumping them together. Additionally, if the control plane and data plane are collocated and competing for the same resources, you can get odd tail latencies which are hard to diagnose
* Deployment/lifecycle -- You may wish to patch, upgrade, or otherwise service your control plane independently of your data plane
* Storage -- If your control plane requires any kind of storage, you can configure this separately and without the data plane involved if you separate out your components


For these reasons, it makes sense to keep the control plane at arms length and decoupled from the data plane. 

### Takeaway

Consider the runtime components that make up your control plane and prefer to leave them deployed in a decoupled architecture. Co-locating may make sense, but don't prematurely optimize for this. 