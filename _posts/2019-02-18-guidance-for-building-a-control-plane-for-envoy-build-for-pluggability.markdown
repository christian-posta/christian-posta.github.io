---
layout: post
title: Guidance for Building a Control Plane for Envoy Part 4 - Build for Pluggability
modified:
categories: 
comments: true
tags: [control plane, microservices, envoy, istio, contour, gloo]
image:
  feature:
date: 2019-02-18T13:38:21-07:00

---

This is part 4 of a [series](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-to-manage-envoy-proxy-based-infrastructure/) that explores building a control plane for Envoy Proxy. Follow along [@christianposta](https://twitter.com/christianposta) and [@soloio_inc](https://twitter.com/soloio_inc) for the next part coming out in a week. 


In this blog series, we'll take a look at the following areas:

* [Adopting a mechanism to dynamically update Envoy's routing, service discovery, and other configuration](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-to-manage-envoy-proxy-based-infrastructure/)
* [Identifying what components make up your control plane, including backing stores, service discovery APIs, security components, et. al.](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-for-envoy-identify-components/)
* [Establishing any domain-specific configuration objects and APIs that best fit your usecases and organization](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-for-envoy-domain-specific-configuration-api/)
* Thinking of how best to make your control plane pluggable where you need it (_this entry_)
* Options for deploying your various control-plane components
* Thinking through a testing harness for your control plane

In the [previous entry](https://blog.christianposta.com/envoy/guidance-for-building-a-control-plane-for-envoy-domain-specific-configuration-api/) we explored building a domain-specific API for your control plane that best fits your organization and workflow preferences/constraints. 

## Building your control plane engine to be pluggable

Envoy is a very powerful piece of software and every day [new use cases and new contributions are being proposed to the community](https://github.com/envoyproxy/envoy/pull/4950). Although the core of Envoy is very stable, it's built on a [pluggable filter architecture](https://github.com/envoyproxy/envoy-filter-example) so folks can write new codecs for different L7 protocols or add new functionality. At the moment, Envoy filter's are written in C++ and there is an option to extend Envoy with [Lua](https://www.envoyproxy.io/docs/envoy/latest/configuration/http_filters/lua_filter) but there is also [some discussion to support Web Assembly](https://github.com/envoyproxy/envoy/issues/4272) for extensibility as well. Also noted, is the work the great folks at [Cilium](https://cilium.io) are doing around a [Go-based extension mechanism for Envoy](https://cilium.io/blog/2018/10/23/cilium-13-envoy-go/). Alongside the fast-moving Envoy community and the need to configure these new capabilities, there is also the need to include new domain-specific object models to support new platforms that want to take advantage of Envoy. In this section, we'll explore extending an Envoy control plane along both of those dimensions.

Extending Envoy is fairly straight forward by writing C++ filters. Envoy filters we've created on the [Gloo project](https://github.com/solo-io/envoy-gloo) include:

* [Squash](https://github.com/solo-io/squash) debugger (https://github.com/envoyproxy/envoy/tree/master/api/envoy/config/filter/http/squash)
* Caching (closed source at the moment; should opensource in the near future)
* Request/Response Transformation (https://github.com/solo-io/envoy-gloo/tree/master/source/extensions/filters/http/transformation)
* AWS lambda (https://github.com/solo-io/envoy-gloo/tree/master/source/extensions/filters/http/aws_lambda)
* NATS streaming (https://github.com/solo-io/envoy-nats-streaming, https://github.com/solo-io/envoy-gloo/tree/master/source/extensions/filters/http/nats/streaming)
* Google Cloud Functions (https://github.com/solo-io/envoy-google-function)
* Azure function (https://github.com/solo-io/envoy-azure-functions)

![](/images/control-plane/envoy-flow.gif)

In the above graphic, we can see how a request flows through Envoy and passes through a number of filters with specialized tasks that apply to the request and responses. You can read more about [the power of Envoy and the tradeoffs we took to build Gloo's control plane](https://medium.com/solo-io/building-a-control-plane-for-envoy-7524ceb09876) in a [blog post](https://medium.com/solo-io/building-a-control-plane-for-envoy-7524ceb09876) written by [Solo.io](https://solo.io) CEO/founder [Idit Levine](https://medium.com/@idit.levine_92620) and Solo.io Chief Architect [Yuval Kohavi](https://medium.com/@yuval.kohavi).

Because Envoy is so versatile and new features are added all the time, it's worth spending some time to consider whether you want to build your control plane to be extensible to be able to use these new features. On the [Gloo project](https://github.com/solo-io/gloo) we've chosen to do just that on the following levels:

* Build more opinionated domain-specific configuration objects on top of a *core* Gloo configuration object
* Control plane *plugins* to augment the existing behavior of control plane
* Create tools to expedite the previous two points 

Let's take a look at each of these levels and how they contribute to an extensible and flexible control plane.

### Core API objects, built with flexibility in mind

In the previous section we discussed focusing on the domain-specific configuration objects we would use to configure the control plane. In Gloo, we have the [lowest level configuration objects](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/proxy.proto.sk/) called [Proxy](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/proxy.proto.sk/) and [Upstream](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/). The `Proxy` defines the lowest level configurations that we can make on the underlying proxy (Envoy in this case). With the `Proxy` object, we define how requests get routed to `Upstreams`.


Here's an example of the Proxy object (as a CRD in Kubernetes for this example):


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

You can see the `Proxy` object specifies listeners, their types, as well as routing information. If you look close you can see it follows Envoy's configuration _to an extent_ but diverges to support additional capabilities. In the routes, you can see that requests are sent to "Upstreams". Gloo knows how to route to [Upstreams](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/) and you can see these definitions in the above `Proxy` object. The `Proxy` object is what is converted to Envoy xDS API by Gloo's control plane. If we take a look at the components that make up Gloo, we see the following:

```bash
NAME                             READY   STATUS    RESTARTS   AGE
discovery-676bcc49f8-n55jt       1/1     Running   0          8m
gateway-d8598c78c-425hz          1/1     Running   0          8m
gateway-proxy-6b4b86b4fb-cm2cr   1/1     Running   0          8m
gloo-565659747c-x7lvf            1/1     Running   0          8m
```

The `gateway-proxy` component is the Envoy proxy. The following components make up the control plane:

* `gateway`
* `discovery`
* `gloo`

The component that's responsible for this `Proxy`->Envoy xDS conversion is `gloo` which is an event-driven component responsible for the core xDS services and configuration of custom Envoy filters by transforming the `Proxy` object into Envoy's LDS/RDS/CDS/EDS APIs

![](/images/control-plane/gloo-crd-detail.png)

Gloo knows how to route to `Upstream`s and functions that exist on `Upstreams`. [Upstream](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/) is also a core configuration object for Gloo. The reason we needed this Upstream object is to encapsulate more fidelity about an upstream cluster's capabilities than what Envoy knows out of the box. Envoy knows about "clusters", but Gloo (on top of Envoy) knows about functions. This knowledge enables  [function-level routing](https://medium.com/solo-io/announcing-gloo-the-function-gateway-3f0860ef6600) which is a more powerful routing construct for composing new applications and APIs. Envoy knows about clusters in terms of "host:port" endpoints, but with Gloo, we can attach additional context to these clusters so they understand "functions" which can be REST method/path, gRPC operations, or cloud functions like Lambda. For example, here's a Gloo upstream named `default-petstore-8080`:

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

![](/images/control-plane/gloo-crd-discovery.png)

If you refer back to the components in the Gloo control plane, you'll see a `discovery` component that augments Envoy's discovery APIs by adding a "Upstream Discovery Service" (UDS), and a "Function Discovery Service" (FDS). The UDS uses a set of plugins (see next section) to automatically discover `Upstream`s from their respective runtime catalog. The simplest example is when running in Kubernetes, we can automatically discover the [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/). Gloo can also discover `Upstreams` from Consul, AWS [and others](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/plugins.proto.sk/#a-name-upstreamspec-upstreamspec-a). The Function Discovery Service (FDS) evaluates each of the `Upstreams` that has been discovered and tries to discover their type (REST, gRPC, GraphQL, AWS Lambda, etc). If the FDS can discover these additional properties about the upstream, it enriches the upstream metadata with these "functions". 

The `discovery` component in the Gloo control plane just uses its UDS and FDS services to discover and write `Upstream` objects into Kuberentes CRDs. From there, a user can create routing rules from specific API paths on the Envoy proxy to a specific function on an `Upstream`. The Envoy proxies do not interact with this control-plane component directly (recall, Envoy only consumes the xDS API exposed by the `gloo` component). Instead, the `discovery` component _facilitates_ the creation of `Upstream`s that can then be used by the `Proxy` object. This is a good example of using supporting microservices (the `discovery` service in this example) to contribute to the overall functionality of the control plane.

`Proxy` and `Upstream` are the lower-level domain-specific configuration objects as mentioned in the previous section. What's more interesting is how we can layer a set of configuration objects on top of this to satisfy user-specific use cases with a more opinionated workflow.

### Extending a domain specific configuration layer
In Gloo's control plane, there is also another component called the `gateway` component. This component implements the higher-level domain-specific configuration that users will end up interacting with (either directly through YAML files or indirectly through the `glooctl` CLI tool). The `gateway` component knows about two domain specific objects:

* [Gateway](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gateway/api/v1/gateway.proto.sk/) -- specify the routes and API endpoints available at a specific listener port as well as what security accompanies each API
* [VirtualService](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gateway/api/v1/virtual_service.proto.sk/) -- groups API routes into a set of "virtual APIs" that can route to backed functions (gRPC, http/1, http/2, lambda, etc); gives the developer control over how a route proceeds with [different transformations](https://gloo.solo.io/v1/github.com/solo-io/gloo/projects/gloo/api/v1/plugins/transformation/transformation.proto.sk/) in an attempt to decouple the front end API from what exists in the backend (and any breaking changes a backend might introduce)

![](/images/control-plane/gloo-crd.png)

These objects allow a decoupling from the `Proxy` object. When users create new `Gateway` or `VirtualService` objects using the more ergonomical or opinionated API, Gloo's `gateway` component takes those objects (CRDs in Kubernetes, config entries in Consul) and updates the underlying `Proxy` object. This is a common pattern for extending Gloo: prefer composability of control-plane components. This allows us to build more specialized controllers for more opinionated domain-specific objects to support different usage. For example, the [Solo.io](https://solo.io) team also built an open-source controller for Gloo called [Sqoop](https://sqoop.solo.io/) which follows this same pattern and extends the Gloo API for declaring routing rules that build on a [GraphQL Engine](https://graphql.org) with GraphQL Schemas. In Sqoop, we introduce [Schemas and ResolverMaps](https://sqoop.solo.io/introduction/concepts/api_objects/) objects that ultimately contribute to the Proxy object which then gets translated to Envoy xDS.

![](/images/control-plane/knative.png)

Another example of this layering of domain-specific configuration built on the base Gloo objects is our recent contribution to use Gloo proxy in [Knative Serving as an alternative to Istio](https://medium.com/solo-io/gloo-by-solo-io-is-the-first-alternative-to-istio-on-knative-324753586f3a). Knative has a specific object for declaring cluster-ingress resources called the [ClusterIngress](https://github.com/knative/serving/blob/master/pkg/client/clientset/versioned/typed/networking/v1alpha1/clusteringress.go) object that looks like this:

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


### Control plane plugins to augment the existing behavior of control plane

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

### Leverage tools to expedite the previous two bullets 

In the previous sections, we saw how to think about extensibility and flexibility of your control plane. We saw how using a multi-layer domain-specific configuration object allows for extensibility by adding new objects and controllers. At [Solo.io](https://solo.io) we've created an open-source project called [solo-kit](https://github.com/solo-io/solo-kit) that expedites building new, declarative, opinionated API objects for your control plane by starting with [protobuf](https://developers.google.com/protocol-buffers/) objects and code-generating the correct type-safe clients for interacting with these objects on your platform. For example, on Kubernetes, [solo-kit](https://github.com/solo-io/solo-kit) turns these protos into [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) and generates Golang Kubernetes clients for watching and interacting with these resources. You can also use Consul, Vault, and many others as the backend storage if you're not on Kubernetes. 

Once you've created the resources and generated the type-safe clients, you will want to detect when users create new resources or make changes to existing ones. With [solo-kit](https://github.com/solo-io/solo-kit) you just specify which resources you wish to watch, or a combination of resources called a "snapshot", and the client runs an event-loop to process any notifications. In your event loop you can update collaborating objects or core objects. In fact this is the way Gloo's layered domain-specific configuration objects work. See the [Gloo declarative model docs](https://gloo.solo.io/operator_guide/gloo_declarative_model/) for more information. 

### Takeaway

A control plane can be as simple or as complicated as you need. The Gloo team recommends focusing on a simple core to the control plane and then extend it through plugins and microservices controllers through composability. Gloo's architecture is built like this and enables [the Gloo team](https://github.com/solo-io/gloo/graphs/contributors) to quickly add any new features to support any platforms, configurations, filters, and more as they come up. That's why, although Gloo is very Kubernetes-native, it is built to run on any platform on any cloud. The core control plane design allows this. 

In the next part of this series, we'll take a look at the pros/cons of deploying control plane components for things like scalability, fault-tolerance, independence, and security. [Stay tuned](https://twitter.com/christianposta)!


