---
layout: post
title: Guidance for Building a Control Plane to Manage Envoy Proxy at the edge, as a gateway, or in a mesh
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-02-12T10:01:56-07:00
---

[Envoy](https://www.envoyproxy.io) has become a popular networking component as of late. Matt Klein [wrote a blog a couple years back](https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a) talking about Envoy's dynamic configuration API and how it has been part of the reason the adoption curve for Envoy has been up and to the right. He called the blog the "universal data plane API". With [so many other projects adopting Envoy](https://www.envoyproxy.io/community) as a central component to their offering, it would not be a stretch to say "Envoy has become the universal data plane in cloud-native architectures" for application/L7 networking solutions, not just establishing a standardized API.

That not-withstanding, because of [Envoy's universal data plane API](https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a), we've seen a multitude of implementations of a management layer to configure and drive Envoy-based infrastructure. Because this is a broad and depp topic, we'll tacke it in a multi-blog series. In this series of blog posts, we're going to take a deep dive into what it takes to build a control plane for Envoy so you can use this information to evaluate what type of infrastructure will fit your organization and usecases best. In fact, there were some [great talks at EnvoyCon/KubeCon](https://blog.envoyproxy.io/envoycon-recap-579d53576511) where some organizations shared their experiences adopting Envoy including how they built their own control planes. Some of the reasons folks chose to build their own control plane:

* Had existing solutions built on different data planes with pre-existing control planes and needed to retrofit Envoy in
* Building for infrastructure that doesn't have any existing opensource or other Envoy control planes (ie, VMs, AWS ECS, etc)
* Don't need to use all of Envoy's features; just a subset
* Prefer an domain-specific API/object model for Envoy configuration that fits their workflows/worldview better
* Other control planes weren't in a mature state when their respective organizations were ready to deploy

However, just because some early adopters built their own bespoke control planes doesn't mean YOU should do the same thing now. First, projects building control planes for Envoy have matured quite a bit in the last year and you should explore using those before deciding to re-create yet another control plane. Second, as the folks at Datawire found, and [Daniel Bryant](https://twitter.com/danielbryantuk) recently articulated, [building a control plane for Envoy is not for the faint of heart](https://www.infoq.com/articles/ambassador-api-gateway-kubernetes).

I work on [a couple](https://github.com/istio/istio) [open-source projects](https://github.com/solo-io/gloo) that have built a control plane for Envoy. In this series of blogs, I'm hoping to explore the different ways to build a control plane for Envoy and hopefully leave some guidance for those to determine whether they would fit your use cases. If nothing else, you can learn what options there are for building a control plane for Envoy and use that to guide your implementation if you have to go down that path. 

In this blog series, we'll take a look at the following areas:

* Adopting a mechanism to dynamically update Envoy's routing, service discovery, and other configuration
* Identifying what components make up your control plane, including backing stores, service discovery APIs, security components, et. al.
* Establishing any domain-specific configuration objects and APIs that best fit your usecases and organization
* Thinking ahead of time how best to make your control plane pluggable where you need it
* Options for deploying your various control-plane components
* Thinking through a testing harness for your control plane

[Where I work](https://www.solo.io) we build open-source tools on top of [Envoy](https://www.envoyproxy.io) to help organizations operationalize microservices architectures with technology such as [service mesh](https://github.com/solo-io/supergloo/), [API Gateways](https://github.com/solo-io/gloo), and [debugging tools](https://github.com/solo-io/squash). We've built open-source tools like [debugging filters for Envoy](https://www.envoyproxy.io/docs/envoy/latest/configuration/http_filters/squash_filter), a platform to [manage multi-cluster/lifecycle/integration of service meshes](https://github.com/solo-io/supergloo) and a [function/ingress gateway for migrating monoliths to microservices built on Envoy](https://github.com/solo-io/gloo). Specifically the function gateway, [Gloo](https://gloo.solo.io), has a control-plane for Envoy that we can refer to in this series of posts as an example of how to build a simple abstraction that allows for pluggability and extensibility at the control points you need. Other solid control-plane implementations you can use for reference are [Istio](https://istio.io) and [Heptio Contour](https://github.com/heptio/contour) and we'll use those as good examples throughout the blog series.

To kick off the series, let's look at using Envoy's dynamic configuration APIs to update Envoy at runtime to deal with changes in topologies and deployments.

## Dynamically configuring Envoy with its xDS API

One of the main advantages of building on top of Envoy is it's data plane API. With the data plane API, we can [dynamically configure most of Envoy's important runtime settings](https://www.envoyproxy.io/docs/envoy/v1.9.0/intro/arch_overview/dynamic_configuration). Envoy's configuration via its xDS APIs is [eventually consistent by design](https://blog.envoyproxy.io/embracing-eventual-consistency-in-soa-networking-32a5ee5d443d) -- that is -- there is no way to affect an "atomic update" to all of the proxies in the cluster. When the control plane has configuration updates, it makes them available to the data plane proxies through the xDS APIs and each proxy will apply these updates independently from each other. 

The following are the parts of Envoy's runtime model we can configure dynamically through xDS:

* [Listeners Discovery Service API - LDS](https://www.envoyproxy.io/docs/envoy/v1.9.0/configuration/listeners/lds#config-listeners-lds) to publish ports on which to listen for traffic
* [Endpoints Discovery Service API- EDS](https://www.envoyproxy.io/docs/envoy/v1.9.0/api-v2/api/v2/eds.proto#envoy-api-file-envoy-api-v2-eds-proto) for service discovery, 
* [Routes Discovery Service API- RDS](https://www.envoyproxy.io/docs/envoy/v1.9.0/configuration/http_conn_man/rds#config-http-conn-man-rds) for traffic routing decisions 
* [Clusters Discovery Service- CDS](https://www.envoyproxy.io/docs/envoy/v1.9.0/configuration/cluster_manager/cds#config-cluster-manager-cds) for backend services to which we can route traffic
* [Secrets Discovery Service - SDS](https://www.envoyproxy.io/docs/envoy/v1.9.0/configuration/secret) for distributing secrets (certificates and keys)

The API is defined with [proto3 Protocol Buffers](https://www.envoyproxy.io/docs/envoy/v1.9.0/configuration/overview/v2_overview#config-overview-v2) and even has a couple reference implementations you can use to bootstrap your own control plane:

* [go-control-plane](https://github.com/envoyproxy/go-control-plane)
* [java-control-plane](https://github.com/envoyproxy/java-control-plane)

Although each of these areas (LDS/EDS/RDS/CDS/SDS, together "xDS") are dynamically configurable, that doesn't mean you must configure everything dynamically. You can have a combination of parts that are statically defined and some parts that are updated dynamically. For example, to implement a type of service discovery where `endpoints` are expected to be dynamic but the `clusters` are well known at deploy time, you can statically define the `clusters` and use the [Endpoint Discovery Service](https://www.envoyproxy.io/docs/envoy/v1.9.0/api-v2/api/v2/eds.proto#envoy-api-file-envoy-api-v2-eds-proto) from Envoy. If you are not sure exactly which [upstream clusters](https://www.envoyproxy.io/docs/envoy/v1.9.0/intro/arch_overview/terminology) will be used at deploy time you could use the [Cluster Discovery Service](https://www.envoyproxy.io/docs/envoy/v1.9.0/configuration/cluster_manager/cds#config-cluster-manager-cds) to dynamically find those. The point is, you can build a workflow and process that statically configures the parts you need while use dynamic xDS services to discover the pieces you need at runtime. One of the reasons why you see different control-plane implementation is not everyone has a fully dynamic and fungible environment where all of the pieces should be dynamic. Adopt the level of dynamism that's most appropriate for your system given the existing constraints and available workflows. 

In the case of Gloo, we use a control plane [based on go-control-plane](https://github.com/solo-io/gloo/blob/ac3bddf202423b297fb909eb6eff498745a8c015/projects/gloo/pkg/xds/envoy.go#L76) to implement the xDS APIs to serve Envoy's dynamic configuration. Istio uses this implementation also as does Heptio Contour. This control plane API leverages [gRPC streaming](https://grpc.io/docs/guides/concepts.html#server-streaming-rpc) calls and stubs out the API so you can fill it with an implementation. Another project, which is unfortunately deprecated but can be used to learn a lot, is [Turbine Labs' Rotor project](https://github.com/turbinelabs/rotor).  This is a highly efficient way to integrate Envoy's data plane API with the control plane. 

gRPC streaming is not the only way to update Envoy's configuration. In [previous versions of the Envoy xDS API](https://www.envoyproxy.io/docs/envoy/v1.5.0/api-v1/api), polling was the only option to determine whether new configuration was available. Although this was acceptable, and met the criteria for "eventually-consistent" configuration updates, it was less efficient in both network and compute usage. It can also be difficult to properly tune the polling configurations to reduce wasted resources. 

Lastly, some Envoy management implementations opt to generate [static Envoy configuration files](https://www.envoyproxy.io/docs/envoy/latest/configuration/overview/v2_overview#static) and periodically replace the configuration files on disk for Envoy and then perform a [hot reload of the Envoy process](https://blog.envoyproxy.io/envoy-hot-restart-1d16b14555b5). In a highly dynamic environment (like Kubernetes, but really any ephemeral-compute based platform) the management of this file generation, delivery, hot-restart, etc can get unwieldy. Envoy was originally operated in an environment that performed updates like this (Lyft, where it was created), but now with the availability of the xDS services

### Takeaway
[The Gloo team](https://github.com/solo-io/gloo/graphs/contributors) believes using gRPC streaming and the xDS APIs is the ideal way to implement dynamic configuration and control for Envoy. Again, not all of the Envoy configurations should be served dynamically, however if you're operating in a highly dynamic environment, the option to configure Envoy dynamically is critical. Other environments may not have this need. Either way, gRPC streaming API for the dynamic parts is ideal.  Some benefits to this approach:

* event-driven configuration updates; configuration is pushed to Envoy when it becomes available in the control plane
* no need to poll for changes
* no need to hot-reload Envoy
* no disruption to traffic















## Final words

* Build with control-plane observability in mind
    * Can put an Envoy proxy alongside
    * Lots of logging/debugging


## At Solo, we built Gloo    

* Reference to my blog
At solo, we built Gloo.
* Gloo is a function gateway with some filters that allow Envoy to understand functions
    * Provide a control plane
        * gloo
        * discovery
        * gateway
        * glooctl for user access
    * Provides an augmentation of the Envoy xDS with more rich “upstreams” and “functions/definitions"
* We’ve stuck to first principles when designing our control plane to minimize missteps:
    * Control plane is a core component in complex distributed system
        * Pay attention to its deign and maintainability
    * Focus on experience of the user (Control Plane is the main API to a networking system)
    * Build it to be testable, observable, and pluggable
    * 
*     









