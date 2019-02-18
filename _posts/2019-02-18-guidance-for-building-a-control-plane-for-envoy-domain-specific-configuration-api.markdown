---
layout: post
title: Guidance for Building a Control Plane for Envoy - Domain Specific Configuration API
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-02-18T13:36:36-07:00
---

## Establishing your control-plane interaction points and API surface

Once you've thought through what components might make up your control-plane architecture (see previous), you'll want to consider exactly how your users will interact with the control plane and maybe even more importantly, _who will your users be?_ To answer this you'll have to decide what roles your Envoy-based infrastructure will play and how traffic will traverse your architecture. It could be a combination of

* API Management gateway (north/south)
* Simple Kubernetes edge load balancer / reverse proxy / ingress control (north/south)
* Shared services proxy (east/west)
* Per-service sidecar (east/west)

For example, the Istio project is intended to be a platform service mesh that platform operators can build tools upon to drive control. Istio's domain-specific configuration objects for configuring Envoy center around the following objects:

* [Gateway](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#Gateway) -- define a shared proxy component (capable of cluster ingress) that specifies protocol, TLS, port, and host/authority that can be used to load balance and route traffic
* [VirtualService](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#VirtualService) -- rules for how to interact with a specific service; can specify things like route matching behavior, timeouts, retries, etc
* [DestinationRule](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#DestinationRule) -- rules for how to interact with a specific service in terms of circuit breaking, load balancing, mTLS policy, subsets definitions of a service, etc
* [ServiceEntry](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#ServiceEntry) -- explicitly add a service to Istio's service registry

Running in Kubernetes, all of those configuration objects are implemented as [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/).

[Heptio/VMWare Contour](https://github.com/heptio/contour) is intended as a Kubernetes ingress gateway and has a simplified domain-specific configuration model with both a CustomResourceDefinition (CRD) flavor as well as a [Kubernetes Ingress resource](https://kubernetes.io/docs/concepts/services-networking/ingress/)

* [IngressRoute](https://github.com/heptio/contour/blob/master/docs/ingressroute.md) which is a Kubernetes CRD that provides a single location to specify configuration for the Contour proxy
* [Ingress Resource support](https://github.com/heptio/contour/blob/master/docs/annotations.md) which allows you to specify annotations on your Kubernetes Ingress resource if you're in to that kind of thing

On the [Gloo project](https://github.com/solo-io/gloo/tree/master/docs/dev) we've made the decision to split the available configuration objects into two levels:

* The user-facing configurations for best ergonomics of user use cases and leave options for extensibility (more on that in next section)
* The lower-level configuration that abstracts Envoy but is not expressly intended for direct user manipulation. The higher-level objects get transformed to this lower-level representation which is ultimately what's used to translate to Envoy xDS APIs. The reasons for this will be clear in the next section.

For users, Gloo focuses on teams owning their routing configurations since the semantics of the routing (and the available transformations/aggregation capabilities) are heavily influenced by the developers of APIs and microservices. For the user-facing API objects, we use:

* [Gateway](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gateway/api/v1/gateway.proto.sk/) -- specify the routes and API endpoints available at a specific listener port as well as what security accompanies each API
* [VirtualService](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gateway/api/v1/virtual_service.proto.sk/) -- groups API routes into a set of "virtual APIs" that can route to backed functions (gRPC, http/1, http/2, lambda, etc); gives the developer control over how a route proceeds with [different transformations](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/plugins/transformation/transformation.proto.sk/) in an attempt to decouple the front end API from what exists in the backend (and any breaking changes a backend might introduce)

The user-facing API objects in Gloo drive the lower-level objects which are then used to ultimately derive the Envoy xDS configurations. For example, Gloo's lower-level, core API objects are:

* [Upstream](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/) -- captures the details about backend clusters and the functions that are exposed on this. You can loosely associate a Gloo Upstream with an [Envoy cluster](https://www.envoyproxy.io/docs/envoy/latest/api-v2/api/v2/cds.proto) with one big difference: An upstream can understand the actual service functions available at a specific endpoint (in other words, knows about `/foo/bar` and `/bar/wine` including their expected parameters and parameter structure rather than just `hostname:port`). More on that in a second. 
* [Proxy](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/proxy.proto.sk/) -- The proxy is the main object that abstracts all of the configuration we can apply to Envoy. This includes listeners, virtual hosts, routes, and upstreams. The higher-level objects (VirtualService, Gateway, etc) are used to drive this lower-level Proxy object.

The split between the two levels of configuration for the Gloo control allows us to extend the Gloo control-plane capabilities while keeping a simple abstraction to configure Envoy. This is explained in the next section. 

In the previous three examples (Istio, Contour, Gloo) each respective control plane exposes a set of domain-specific configuration objects that are user focused but are ultimately transformed into Envoy configuration and exposed over the xDS data plane API. This provides a decoupling between Envoy and a user's predisposed way of working and their workflows. Although we've seen a few examples of creating a more user and workflow focused domain-specific configuration for abstracting Envoy, that's not the only way to build up an Envoy control plane. [Booking.com has a great presentation](https://www.slideshare.net/IvanKruglov/ivan-kruglov-introducing-envoybased-service-mesh-at-bookingcom-version-7) on how they stayed much closer to the Envoy configurations and used an engine to just merge all the different teams' configuration fragments into the actual Envoy configuration. 

Alongside considering a domain-specific configuration, you should consider the specific touch points of your API/object model. For example, Kubernetes is very YAML and resource-file focused. You could build a more domain-specific CLI tool (like [OpenShift did with the oc CLI](https://docs.openshift.com/enterprise/3.2/dev_guide/new_app.html#dev-guide-new-app), like Istio [did with istioctl](https://istio.io/docs/reference/commands/istioctl/) and like Gloo [did with glooctl](https://gloo.solo.io/cli/glooctl/)

### Takeaway

When you build an Envoy control plane, you're doing so with a specific intent or set of architectures/users in mind. You should take this into account and build the right ergonomic, opinionated domain-specific API that suits your users and improves your workflow for operating Envoy. [The Gloo team](https://github.com/solo-io/gloo/graphs/contributors) recommends exploring _existing_ Envoy control plane implementations and only building your own if none of the others are suitable. As we'll see in the next section, it's possible to build a control plane that is fully extendable to fit many different users, workflows, and operational constraints. 
