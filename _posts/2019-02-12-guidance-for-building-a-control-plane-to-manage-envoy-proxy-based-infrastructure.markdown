---
layout: post
title: Guidance for Building a Control Plane to Manage Envoy Proxy at the edge or in a mesh, Part One
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-02-12T10:01:56-07:00
---

[Envoy](https://www.envoyproxy.io) has become a popular networking component as of late. Matt Klein [wrote a blog a couple years back](https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a) talking about Envoy's dynamic configuration API and how it has been part of the reason the adoption curve for Envoy has been up and to the right. He called the blog the "universal data plane API". With [so many other projects adopting Envoy](https://www.envoyproxy.io/community) as a central component to their offering, it would not be a stretch to say "Envoy has become the universal data plane in cloud-native architectures" for application/L7 networking solutions, not just establishing a standardized API.

That not-withstanding, because of [Envoy's universal data plane API](https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a), we've seen a multitude of implementations of a management layer to configure and drive Envoy-based infrastructure. In fact, there were some [great talks at EnvoyCon/KubeCon](https://blog.envoyproxy.io/envoycon-recap-579d53576511) and some organizations shared their experiences adopting Envoy including how they built their own control planes. Some of the reasons folks chose to build their own control plane:

* Had existing solutions built on different data planes with pre-existing control planes and needed to retrofit Envoy in
* Building for infrastructure that doesn't have any existing opensource or other Envoy control planes (ie, VMs, AWS ECS, etc)
* Don't need to use all of Envoy's features; just a subset
* Prefer an domain-specific API/object model for Envoy configuration that fits their workflows/worldview better
* Other control planes weren't in a mature state when their respective organizations were ready to deploy

However, just because some early adopters built their own bespoke control planes doesn't mean YOU should do the same thing now. First, projects building control planes for Envoy have matured quite a bit in the last year and you should explore using those before deciding to re-create yet another control plane. Second, as the folks at Datawire found, and [Daniel Bryant](https://twitter.com/danielbryantuk) recently articulated, [building a control plane for Envoy is not for the faint of heart](https://www.infoq.com/articles/ambassador-api-gateway-kubernetes).

I work on [a couple](https://github.com/istio/istio) [open-source projects](https://github.com/solo-io/gloo) that have built a control plane for Envoy. In this series of blogs, I'm hoping to explore the different ways to build a control plane for Envoy and hopefully leave some guidance for those to determine whether they would fit your use cases. If nothing else, you can learn what options there are for building a control plane for Envoy and use that to guide your implementation if you have to go down that path. 

At [Solo.io](https://www.solo.io) we build open-source tools on top of [Envoy](https://www.envoyproxy.io) to help you operationalize microservices architectures with technology such as service mesh. We've built open-source tools like [debugging filters for Envoy](https://www.envoyproxy.io/docs/envoy/latest/configuration/http_filters/squash_filter), a platform to [manage multi-cluster/lifecycle/integration of service meshes](https://github.com/solo-io/supergloo) and a [function/ingress gateway for migrating monoliths to microservices built on Envoy](https://github.com/solo-io/gloo). Specifically the function gateway, [Gloo](https://gloo.solo.io), has a control-plane for Envoy that we can refer to in this series of posts as an example of how to build a simple abstraction that allows for pluggability and extensibility at the control points you need. Other solid control-plane implementations you can use for reference are [Istio](https://istio.io) and [Heptio Contour](https://github.com/heptio/contour) and we'll use those as good examples throughout the blog series.

## xDS API
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


## Building your control plane engine to be pluggable

Envoy is a very powerful piece of software and every day [new use cases and new contributions are being proposed to the community](https://github.com/envoyproxy/envoy/pull/4950). Although the core of Envoy is very stable, it's built on a [pluggable filter architecture](https://github.com/envoyproxy/envoy-filter-example) so folks can write new codecs for different L7 protocols or add new functionality. At the moment, Envoy filter's are written in C++ and there is an option to extend Envoy with [Lua](https://www.envoyproxy.io/docs/envoy/latest/configuration/http_filters/lua_filter) but there is also [some discussion to support Web Assembly](https://github.com/envoyproxy/envoy/issues/4272) for extensibility as well. Alongside the fast-moving Envoy community and the need to configure these new capabilities, there is also the need to include new domain-specific object models to support new platforms that want to take advantage of Envoy. In this section, we'll explore extending an Envoy control plane along both of those dimensions.

Extending Envoy is fairly straight forward by writing C++ filters. Envoy filters we've created on the [Gloo project](https://github.com/solo-io/envoy-gloo) include:

* [Squash](https://github.com/solo-io/squash) debugger (https://github.com/envoyproxy/envoy/tree/master/api/envoy/config/filter/http/squash)
* Caching (closed source at the moment; should opensource in the near future)
* Request/Response Transformation (https://github.com/solo-io/envoy-gloo/tree/master/source/extensions/filters/http/transformation)
* AWS lambda (https://github.com/solo-io/envoy-gloo/tree/master/source/extensions/filters/http/aws_lambda)
* NATS streaming (https://github.com/solo-io/envoy-nats-streaming, https://github.com/solo-io/envoy-gloo/tree/master/source/extensions/filters/http/nats/streaming)
* Google Cloud Functions (https://github.com/solo-io/envoy-google-function)
* Azure function (https://github.com/solo-io/envoy-azure-functions)

Because Envoy is so versatile and new features are added all the time, it's worth spending some time to consider whether you want to build your control plane to be extensible to be able to use these new features. On the [Gloo project](https://github.com/solo-io/gloo) we've chosen to do just that on the following levels:

* Build more opinionated domain-specific configuration objects on top of a *core* Gloo configuration object
* Control plane *plugins* to augment the existing behavior of control plane
* Create tools to expedite the previous two points 

Let's take a look at each of these levels and how they contribute to an extensible and flexible control plane.

#### Core API objects, built with flexibility in mind

In the previous section we discussed focusing on the domain-specific configuration objects we would use to configure the control plane. In Gloo, we have the [lowest level configuration object](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/proxy.proto.sk/) called [Proxy](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/proxy.proto.sk/). Here's an example of the Proxy object (as a CRD in Kubernetes for this example):


```yaml
apiVersion: gloo.solo.io/v1
kind: Proxy
metadata:
  clusterName: ""
  creationTimestamp: "2019-02-15T13:27:39Z"
  generation: 1
  labels:
    created_by: gateway
  name: gateway-proxy
  namespace: gloo-system
  resourceVersion: "5209108"
  selfLink: /apis/gloo.solo.io/v1/namespaces/gloo-system/proxies/gateway-proxy
  uid: 771377f2-3125-11e9-8523-42010aa800e0
spec:
  listeners:
  - bindAddress: '::'
    bindPort: 8080
    httpListener:
      virtualHosts:
      - domains:
        - '*'
        name: gloo-system.default
        routes:
        - matcher:
            exact: /petstore/findPet
          routeAction:
            single:
              destinationSpec:
                rest:
                  functionName: findPetById
                  parameters: {}
              upstream:
                name: default-petstore-8080
                namespace: gloo-system
        - matcher:
            exact: /sample-route-1
          routeAction:
            single:
              upstream:
                name: default-petstore-8080
                namespace: gloo-system
          routePlugins:
            prefixRewrite:
              prefixRewrite: /api/pets
    name: gateway
status:
  reported_by: gloo
  state: 1
```

You can see the Proxy object specifies listeners, their types, as well as routing information. If you look close you can see it follows Envoy's configuration _to an extent_ but diverges to support additional capabilities. In the routes, you can see that requests are sent to "upstreams". Gloo knows how to route to [Upstreams](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/) and you can see these definitions in the above Proxy object. THe Proxy object is what is converted to Envoy xDS API by Gloo's control plane. If we take a look at the components that make up Gloo, we see the following:

```bash
NAME                             READY   STATUS    RESTARTS   AGE
discovery-676bcc49f8-n55jt       1/1     Running   0          8m
gateway-d8598c78c-425hz          1/1     Running   0          8m
gateway-proxy-6b4b86b4fb-cm2cr   1/1     Running   0          8m
gloo-565659747c-x7lvf            1/1     Running   0          8m
```

The `gateway-proxy` component is the Envoy proxy. The following comprise the control plane:

* `gateway`
* `discovery`
* `gloo`

The component that's responsible for this Proxy->Envoy xDS conversion is:

* `gloo` -- an event-driven component responsible for the core xDS services and configuration of custom Envoy filters by transforming the Proxy object into Envoy's LDS/RDS/CDS/EDS APIs

Gloo knows how to route to Upstreams and functions that exist on Upstreams. [Upstream](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/) is also a core configuration object for Gloo. The reason we needed this Upstream object is to encapsulate more fidelity about the upstream's capabilities than what Envoy knows out of the box. Envoy knows about "clusters", but Gloo (on top of Envoy) knows about functions. This knowledge enables  [function-level routing](https://medium.com/solo-io/announcing-gloo-the-function-gateway-3f0860ef6600) which is a more powerful routing construct for composing new applications and APIs. Envoy knows about clusters in terms of "host:port" endpoints, but with Gloo, we can attach additional context to these clusters so they understand "functions" which can be REST method/path, gRPC operations, or cloud functions like Lambda. For example, here's a Gloo upstream named `default-petstore-8080`:

{% raw %}
```yaml
---
discoveryMetadata: {}
metadata:
  labels:
    discovered_by: kubernetesplugin
    service: petstore
    sevice: petstore
  name: default-petstore-8080
  namespace: gloo-system
status:
  reportedBy: gloo
  state: Accepted
upstreamSpec:
  kube:
    selector:
      app: petstore
    serviceName: petstore
    serviceNamespace: default
    servicePort: 8080
    serviceSpec:
      rest:
        swaggerInfo:
          url: http://petstore.default.svc.cluster.local:8080/swagger.json
        transformations:
          addPet:
            body:
              text: '{"id": {{ default(id, "") }},"name": "{{ default(name, "")}}","tag":
                "{{ default(tag, "")}}"}'
            headers:
              :method:
                text: POST
              :path:
                text: /api/pets
              content-type:
                text: application/json
          deletePet:
            headers:
              :method:
                text: DELETE
              :path:
                text: /api/pets/{{ default(id, "") }}
              content-type:
                text: application/json
          findPetById:
            body: {}
            headers:
              :method:
                text: GET
              :path:
                text: /api/pets/{{ default(id, "") }}
              content-length:
                text: "0"
              content-type: {}
              transfer-encoding: {}
          findPets:
            body: {}
            headers:
              :method:
                text: GET
              :path:
                text: /api/pets?tags={{default(tags, "")}}&limit={{default(limit,
                  "")}}
              content-length:
                text: "0"
              content-type: {}
              transfer-encoding: {}
```
{% endraw %}

Notice, we have more fidelity in terms of what functions are exposed by this upstream. In this case, the upstream happens to be a REST service exposing an [Open API Spec/Swagger](https://github.com/OAI/OpenAPI-Specification) document. Gloo automatically discovered this information and enriched this Upstream object with that information that can then be used in the Proxy object. 

If you refer back to the components in the Gloo control plane, you'll see a `discovery` component that augments Envoy's discovery APIs by adding a "Upstream Discovery Service" (UDS), and a "Function Discovery Service" (FDS). The upstream discovery service uses a set of plugins (see next section) to automatically discover upstreams. The simplest example is when running in Kubernetes, we can automatically discover the [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/). Gloo can also discover upstreams from Consul, AWS [and others](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/plugins.proto.sk/#a-name-upstreamspec-upstreamspec-a). 

The `discovery` component in the Gloo control plane just uses its UDS and FDS services to discover and write Upstream objects into Kuberentes CRDs. From there, a user can create routing rules from specific API paths on the Envoy proxy to a specific function on an upstream. The Envoy proxies do not interact with this control-plane component directly (recall, Envoy only consumes the xDS API exposed by the `gloo` component). Instead, the `discovery` component _facilitates_ the creation of Upstreams that can then be used by the Proxy object. This is a good example of using supporting microservices (the `discovery` service in this example) to contribute to the overall functionality of the control plane.

Proxy and Upstream are the lower-level domain-specific configuration objects as mentioned in the previous section. What's more interesting is how we can layer a set of configuration objects on top of this to satisfy user-specific use cases with a more opinionated workflow.

#### Extending a domain specific configuration layer
In Gloo's control plane, there is also another component called the `gateway` component. This component implements the higher-level domain-specific configuration that users will end up interacting with (either directly through YAML files or indirectly through the `glooctl` CLI tool). The `gateway` component knows about two domain specific objects:

* [Gateway](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gateway/api/v1/gateway.proto.sk/) -- specify the routes and API endpoints available at a specific listener port as well as what security accompanies each API
* [VirtualService](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gateway/api/v1/virtual_service.proto.sk/) -- groups API routes into a set of "virtual APIs" that can route to backed functions (gRPC, http/1, http/2, lambda, etc); gives the developer control over how a route proceeds with [different transformations](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/plugins/transformation/transformation.proto.sk/) in an attempt to decouple the front end API from what exists in the backend (and any breaking changes a backend might introduce)

These objects allow a decoupling from the `Proxy` object. When users create new `Gateway` or `VirtualService` objects using the more ergonomical or opinionated API, Gloo's `gateway` component takes those objects (CRDs in Kubernetes, config entries in Consul) and updates the underlying `Proxy` object. This is a common pattern for extending Gloo: prefer composability of control plane components. This allows us to build more specialized controllers for more opinionated domain-specific objects to support different usage. For example, the [Solo.io](https://solo.io) team also built an open-source controller for Gloo called [Sqoop](https://sqoop.solo.io/) which follows this same pattern and externds the Gloo API for declaring routing rules that build on a [GraphQL Engine](https://graphql.org) with GraphQL Schemas. In Sqoop, we introduce [Schemas and ResolverMaps](https://sqoop.solo.io/introduction/concepts/api_objects/) objects that ultimately contribute to the Proxy object which then gets translated to Envoy xDS.

Another example of this layering of domain-specific configuration built on the base Gloo objects is our recent contribution to use Gloo proxy in [Knative Serving as an alternative to Istio](MISSING). Knative has a specific object for declaring cluster-ingress resources called the [ClusterIngress](https://github.com/knative/serving/blob/master/pkg/client/clientset/versioned/typed/networking/v1alpha1/clusteringress.go) object that looks like this:

```yaml
apiVersion: networking.internal.knative.dev/v1alpha1
kind: ClusterIngress
metadata:
  labels:
    serving.knative.dev/route: helloworld-go
    serving.knative.dev/routeNamespace: default
  name: helloworld-go-txrqt
spec:
  generation: 2
  rules:
  - hosts:
    - helloworld-go.default.example.com
    - helloworld-go.default.svc.cluster.local
    - helloworld-go.default.svc
    - helloworld-go.default
    http:
      paths:
      - appendHeaders:
          knative-serving-namespace: default
          knative-serving-revision: helloworld-go-00001
        retries:
          attempts: 3
          perTryTimeout: 10m0s
        splits:
        - percent: 100
          serviceName: activator-service
          serviceNamespace: knative-serving
          servicePort: 80
        timeout: 10m0s
  visibility: ExternalIP
```

 To support this use case in Gloo, all we did was [build a new controller that watches](https://github.com/solo-io/gloo/blob/ac3bddf202423b297fb909eb6eff498745a8c015/projects/clusteringress/pkg/translator/translate.go#L19) and converts [ClusterIngress](https://github.com/knative/serving/blob/master/pkg/client/clientset/versioned/typed/networking/v1alpha1/clusteringress.go) objects into Gloo's [Proxy](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/proxy.proto.sk/). Please see [this blog for more information on using Gloo within Knative](MISSING) to simplify [Knative Serving](https://github.com/knative/serving) installation to use Gloo as the cluster ingress. 


#### Control plane plugins to augment the existing behavior of control plane

In the previous section we looked at extending the capabilities of the control plane by layering domain-specific configuration objects on top of core objects. Another point of extension is directly in the control-pane core objects itself. In Istio that would be `VirtualService` and `DestinationRule`, in Contour that would be `IngressRoute` and in Gloo that would be the `Proxy` and `Upstream` objects. For example, Gloo's [Proxy object](https://github.com/solo-io/gloo/blob/7a5c3a9a7a060841a7047efce79e5b7b3ed981be/projects/gloo/api/v1/proxy.proto#L30)  contains extension points for [Listeners](https://github.com/solo-io/gloo/blob/7a5c3a9a7a060841a7047efce79e5b7b3ed981be/projects/gloo/api/v1/proxy.proto#L90), [Virtualhosts](https://github.com/solo-io/gloo/blob/7a5c3a9a7a060841a7047efce79e5b7b3ed981be/projects/gloo/api/v1/proxy.proto#L124) and [Routes](https://github.com/solo-io/gloo/blob/7a5c3a9a7a060841a7047efce79e5b7b3ed981be/projects/gloo/api/v1/proxy.proto#L154). This means there are well defined spots in the Proxy configuration that we can introduce new functionality to our configuration (ie, if we wish to expose new Envoy functionality or if we write new filters for Envoy for which we'd like to expose configuration, etc). with minimal fuss. For example, we have written a handful of [plugins that enrich the routing and transformation capabilities](https://github.com/solo-io/gloo/blob/a27e1018640c46f7a25e4c1a0dc1f4cadf1773f5/projects/gloo/api/v1/plugins.proto#L44) of Envoy. For example, to transform a request coming into Envoy and destined to a service named `foo-service`, we can maninpulate the headers or body with [Inja templates](https://github.com/pantor/inja). See the [function routing guide in Gloo's documentation](https://gloo.solo.io/user_guides/function_routing/) for more.


```
routes:
- matcher:
    prefix: /
  routeAction:
    single:
      upstream:
        name: foo-service
        namespace: default
  routePlugins:
    transformations:
      requestTransformation:
        transformationTemplate:
          headers:
            x-canary-foo
              text: foo-bar-v2
            :path:
              text: /v2/canary/feature
          passthrough: {}
```

To see the full list of plugins available on the Gloo [Proxy](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/proxy.proto.sk/) and [Upstream](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/) objects, see [the documentation here](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/plugins.proto.sk/)

Once you've added new plugins to your control plane, you can extend your user-facing domain-specific configuration objects to take advantage of these new capabiliites. You can augment your existing controllers to do this or add new ones (following the principle of microservices loosely coordinating with each other). We've written [extensive examples to help you write controllers](https://gloo.solo.io/dev/example-proxy-controller/) to augment your control-plane functionality or reach out on [Slack](https://slack.solo.io) for any more pointers on this. 

#### Leverage tools to expedite the previous two bullets 

In the previous sections, we saw how to think about extensibility and flexibility of your control plane. We saw how using a multi-layer domain-specific configuration object allows for extensibility by adding new objects and controllers. At [Solo.io](https://solo.io) we've created an open-source project called [solo-kit](https://github.com/solo-io/solo-kit) that expedites building new, declarative, opinionated API objects for your control plane by starting with [protobuf](https://developers.google.com/protocol-buffers/) objects and code-generating the correct type-safe clients for interacting with these objects on your platform. For example, on Kubernetes, [solo-kit](https://github.com/solo-io/solo-kit) turns these protos into [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) and generates Golang Kubernetes clients for watching and interacting with these resources. You can also use Consul, Vault, and many others as the backend storage if you're not on Kubernetes. 

Once you've created the resources and generated the type-safe clients, you will want to detect when users create new resources or make changes to existing ones. With [solo-kit](https://github.com/solo-io/solo-kit) you just specify which resources you wish to watch, or a combination of resources called a "snapshot", and the client runs an event-loop to process any notifications. In your event loop you can update collaborating objects or core objects. In fact this is the way Gloo's layered domain-specific configuration objects work. See the [Gloo declarative model docs](https://gloo.solo.io/operator_guide/gloo_declarative_model/) for more information. 

### Takeaway

A control plane can be as simple or as complicated as you need. The Gloo team recommends focusing on a simple core to the control plane and then extend it through plugins and microservices controllers through composability. Gloo's architecture is built like this and enables [the Gloo team](https://github.com/solo-io/gloo/graphs/contributors) to quickly add any new features to support any platforms, configurations, filters, and more as they come up. That's why, although Gloo is very Kubernetes-native, it is built to run on any platform on any cloud. The core control plane design allows this. 



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

## Testing your control plane

* Build tests
    * Gloo does e2e testing OUTSIDE of k8s cluster
        * If you can, you can run tests more frequently
    * Also in k8s

### Takeaway


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









