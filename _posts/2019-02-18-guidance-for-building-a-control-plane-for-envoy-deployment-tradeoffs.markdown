---
layout: post
title: Guidance for Building a Control Plane for Envoy Part 5 - Deployment Tradeoffs
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-02-18T13:38:53-07:00
---

This is part 5 of a [series](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-to-manage-envoy-proxy-based-infrastructure/) that explores building a control plane for Envoy Proxy. Follow along [@christianposta](https://twitter.com/christianposta) and [@soloio_inc](https://twitter.com/soloio_inc) for more!. 


In this blog series, we'll take a look at the following areas:

* [Adopting a mechanism to dynamically update Envoy's routing, service discovery, and other configuration](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-to-manage-envoy-proxy-based-infrastructure/)
* [Identifying what components make up your control plane, including backing stores, service discovery APIs, security components, et. al.](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-for-envoy-identify-components/)
* [Establishing any domain-specific configuration objects and APIs that best fit your usecases and organization](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-for-envoy-domain-specific-configuration-api/)
* [Thinking of how best to make your control plane pluggable where you need it](https://blog.christianposta.com/guidance-for-building-a-control-plane-for-envoy-build-for-pluggability/)
* Options for deploying your various control-plane components (_this entry_)
* Thinking through a testing harness for your control plane

In the [previous entry](https://blog.christianposta.com/guidance-for-building-a-control-plane-for-envoy-build-for-pluggability/) we explored why a pluggable control plane is crucial for keeping up with the fast-moving Envoy API as well as integrating with different workflows an organization may wish to adopt. In this post, we'll look at the tradeoffs in deploying the various control-plane components. 

## Deploying control plane components

Once you've built and designed your control plane and its various supporting components, you'll want to decide exactly how its components get deployed. You'll want to weight various security, scalability, and usability concerns when settling into what's best for your implementation. The options vary from co-deploying control plane components with the data plane to completely separating the control plane from the data plane.  There is also a middle ground here as well: deploy some components co-located with the control plane and keep some centralized. Let's take a look.

In the Istio service-mesh project, the control plane components are deployed and run separately from the data plane. This is very common in a service-mesh implementation. That is, the data plane runs with the applications and handles all of the application traffic and communicates with the control plane via xDS APIs over gRPC streaming. The control-plane components generally run in their own namespace and are ideally locked down from unexpected usage. 

The Gloo project, as an API Gateway, follows a similar deployment model. The control-plane components are decoupled from the data plane and the Envoy data plane uses xDS gRPC streaming to collect configuration about listeners, routes, endpoints, and clusters, etc. You could deploy the components co-located with the dataplane proxies with Gloo, but that's discouraged. We'll take a look at some of the tradeoffs in a bit.

![](/images/control-plane/separatecontrolplane.png)

Lastly, we take a look at co-deploying control plane components with the data plane. In the Contour project, by default, control plane components are deployed with the data plane though [there is an option to split up the deployment](https://github.com/heptio/contour/blob/master/docs/deploy-seperate-pods.md). Contour actually  leverages CRDs or Ingress resources for its configuration, so all of the config-file handling and watching happens in Kubernetes. The xDS service, however, is co-deployed with the dataplane (again, that's by default -- you can split them).

![](/images/control-plane/codeployed.png)

When [eBay built their control plane for their deployment of Envoy]( https://www.youtube.com/watch?v=a1tXFUrqt5M&list=PLj6h78yzYM2PF_iYEBntfR0m4KAZET18Q&index=14&t=0s), they also co-deployed _parts_ of their control plane (the discovery pieces) with their data plane. They basically wrote a controller to watch CRDs, Ingress, and Service resources and then generate config maps. These config maps would then be consumed by the `discovery` container running with the Pod and hot restarted with changed, which updated Envoy.

![](/images/control-plane/ebay-control-plane.png)
![](/images/control-plane/double-click-ebay-control-plane.png)

In the Ebay case, we see a "hybrid" approach and was highly influenced by the specifics of the rest of their architecture. When evaluating a control plane for Envoy, or considering building one yourself, how should you deploy the control-plane components?

#### Should I keep control planes separated from data plane?

There are pros and cons to the various approaches. [The Gloo team](https://github.com/solo-io/gloo/graphs/contributors) believes keeping the control plane separate is the right choice for most use cases and you should avoid fully co-deploying your control plane with your data plane.

![](/images/control-plane/separatecontrolplane.png)

If Envoy is the heart and soul of your L7 networking, the control plane is the brains. Deploying the control-plane separate from the data plane is important for these reasons:

* Security -- If somehow a node in your data plane gets compromised, you definitely do NOT want to exacerbate your situation by giving up control to the rest of your applications and network by allowing your control plane to become compromised. Additionally, a control plane could be dealing with distribution of keys, certificates, or other secrets that should be kept separate from the data plane. 
* Scaling --  You probably will end up scaling your data plane and control plane differently. For example, if your control plane is polling Kubernetes for services/endpoints etc, you definitely don't want to co-locate those components with your data plane -- you'll choke any chance of scalability. 
* Grouping -- You may have different roles and responsibilities of the data plane; for example, you may have data plane Envoys at the edge which would need a different security and networking posture than a pool of shared proxies for your microservices vs any sidecar proxies you may deploy. Having the control plane co-located with the data plane makes it more difficult to keep data and configuration separate
* Resource usage -- You may wish to assign or throttle certain resource usage depending on your components. For example, your data plane may be more compute intensive vs the control plane (which may be more memory intensive) and you'd use different resource limits to fulfill those roles. Keeping them separate allows you more fine-grained resource pool options than just lumping them together. Additionally, if the control plane and data plane are collocated and competing for the same resources, you can get odd tail latencies which are hard to diagnose
* Deployment/lifecycle -- You may wish to patch, upgrade, or otherwise service your control plane independently of your data plane
* Storage -- If your control plane requires any kind of storage, you can configure this separately and without the data plane involved if you separate out your components


For these reasons, we recommend  to keep the control plane at arms length and decoupled from the data plane. 

### Takeaway

Building a control plane for Envoy is not easy and once you get to understand what's needed from a control plane for your workflow, you'll need to understand how best to deploy it. The Gloo team recommends building a pluggable control plane and keeping it separate from the data plane for the reasons outlined above. Gloo's architecture is built like this and enables [the Gloo team](https://github.com/solo-io/gloo/graphs/contributors) to quickly add any new features and scale to support any platforms, configurations, filters, and more as they come up. Again, follow along [@christianposta](https://twitter.com/christianposta) and [@soloio_inc](https://twitter.com/soloio_inc) for more Envoy, API Gateway, and service mesh goodness.. 