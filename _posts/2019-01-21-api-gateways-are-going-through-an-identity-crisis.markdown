---
layout: post
title: API Gateways Are Going Through an Identity Crisis
modified:
categories: microservices
comments: true
tags: [microservices, istio, envoy, service mesh, resilience, sidecar, api gateway, solo.io]
image:
  feature:
date: 2019-01-21T10:54:23-07:00
---

API Gateways are going through a bit of an [identity crisis](https://en.wikipedia.org/wiki/Identity_crisis) these days. 

* Are they centralized, shared resources that facilitate the exposure and governance of APIs to external entities?

* Are they cluster ingress sentries that tightly control what user traffic comes into the cluster or leaves it? 

* Or are they some kind of API coalescing glue to more succinctly express an API depending on the type of clients it may have? 

* And of course the elephant in the room and a question I often hear: “does service mesh make API gateway obsolete?”

## Some context
With how fast technology moves, and how quickly the industry shuffles through technology and architecture patterns, you’d be forgiven to be thinking “all of this is making my head spin”. In this post I’m hoping to boil down the different identities of an “API gateway”, clarify what groups in the organization may use an API gateway (the problems they’re trying to solve), and re-focus on first principles. Ideally, by the end of this post, you’ll better understand the role of API infrastructure at these different levels for different teams and how to get the most value out of each level. 

Before we dive in, let’s be very clear about the term API. 

### My definition of API:

An explicitly and purposefully defined interface designed to be invoked over a network that enables software developers to get programmatic access to data and functionality within an organization in a controlled and comfortable way. 

These interfaces abstract the details of the technology infrastructure that implements them. For these designed network endpoints, we expect some level of documentation, usage guidance, stability and backwards compatibility. 

In contrast, just because we can communicate with another piece of software over the network does not necessarily mean that remote endpoint is an API by this definition. Lots of systems communicate with each other, however that communication happens more haphazardly and trades off immediacy with coupling and other factors.

We create APIs to provide a thoughtful abstraction over parts of the business to enable both new business functionality as well as  serendipitous innovation. 

First up on the list when talking about API gateways is API management.

## API Management

A lot of folks think about API Gateways in terms of API management. This is fair. But let’s take a quick look at what exactly this gateway does. 

[With API Management](https://en.wikipedia.org/wiki/API_management), we are looking to solve the problem of  “when we wish to expose existing APIs for others to consume”, how do we track who uses these APIs, enforce policies about who’s allowed to use them, establish security flows to authenticate and authorize permissible use and build a catalog of services that can be used at design time to promote API usage and lay the foundation for effective governance. 

 We want to solve the problem of “we have these existing, curated, APIs that we want to share with others but share them _on our terms_”. 

API Management also does nice things to allow users (potential API consumers) to self-service,  sign up to different plans for API consumption (think: numbers of calls per user per endpoint within a given time frame for a specified price point). The piece of infrastructure where we are able to _enforce_ these kind of management functions is the _gateway_ through which our API traffic traverses. A this point, we can enforce things like authentication, rate limiting, metrics collection, other policy enforcement, el. al. 

![](/images/identity-crisis/api-management-sketch.png)

Examples of API Management software that leverages an API gateway: 

* [Google Cloud Apigee](https://apigee.com/api-management/#/homepage)
* [Red Hat 3Scale](https://www.3scale.net)
* [Mulesoft](https://www.mulesoft.com)
* [Kong](https://konghq.com)

At this level, we are thinking in terms of APIs (as defined above) and how best to manage and allow access to them. We are not thinking in terms of servers, hosts, ports, containers, or even services (another poorly defined word, but stick with me!).

API management (and thus their corresponding gateways) are usually implemented as tightly controlled shared infrastructure owned by either a “platform team”, “integration team”, or other API infrastructure teams. 

One thing to note: we want to be careful not to allow any business logic into this layer. As mentioned in the previous paragraph, API management is shared infrastructure, but since our API traffic traverses it, it has the tendency to re-create the “all-knowing, all-being” (think Enterprise Service Bus) governance gate through which we must all coordinate to make changes to our services. In theory this sounds great. In practice, this can end up being an organizational bottleneck.  See this post for more: [Application Network Functions with ESBs, API Management, and Now... Service Mesh?](http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/)


## Cluster ingress
To build and implement APIs, we focus on things like code, data, productivity frameworks and so on. But for any of these things to provide value, they must be tested, deployed into production and monitored. As we start deploying to cloud-native platforms, we start thinking in terms of deployments, containers, services, hosts, ports, etc and building our application to live in this environment. We’re probably crafting workflows (CI) and pipelines (CD) to take advantage of the cloud platform to move quickly, make changes, get them in front of customers, and so on. 

In this environment, we may build and maintain multiple clusters to host our applications and need some way of accessing the applications and services inside those clusters. Think for example in terms of Kubernetes. We may use a [Kubernetes Ingress controller](https://kubernetes.io/docs/concepts/services-networking/ingress/) to allow access into the Kubernetes cluster (everything else in the cluster is not accessible from the outside). That way we keep very tight control over what traffic may enter (or even leave) our cluster with well-defined entry points like domain/virtual hosts, ports, protocols, et. al. 

At this level, we may want some sort of ["ingress gateway"](https://istio.io/docs/tasks/traffic-management/ingress/) to be the traffic sentry for allowing requests and messages into the cluster. At this level you’re thinking more in terms of “I have this service in my cluster, I need people outside the cluster to be able to invoke it”. This could be a service (exposing an API), an existing monolith, a gRPC service, a cache, a message queue, a database, etc. Some folks have chosen to call this an API gateway, and some of them might actually do more than traffic ingress/egress, but the point is the problems at this level exist at the cluster-operations level. As we tend to deploy more clusters (vs a single, highly multi-tenant cluster) we end up with more ingress points and the need for those to interact with each other.

![](/images/identity-crisis/cluster-ingress-sketch.png)

Examples of these types of ingress implementations include:

* Envoy Proxy and projects that build upon it including:
    * [Datawire Ambassador](https://www.getambassador.io)
    * [Solo.io Gloo](https://gloo.solo.io)
    * [Heptio Contour](https://github.com/heptio/contour)
* HAproxy
    * Including [OpenShift’s Router](https://docs.openshift.com/container-platform/3.9/install_config/router/index.html)
* [NGINX](https://github.com/kubernetes/ingress-nginx)
* [Traefik](https://traefik.io)

This level of cluster ingress controller is operated by the platform team, however this piece of infrastructure is often associated with a more decentralized, self-service workflow (as you would expect from a cloud-native platform). [See the “GitOps” workflow as described by the good folks at Weaveworks](https://www.weave.works/blog/gitops-operations-by-pull-request)


## API Gateway pattern
Another expansion on the term “API gateway” is the one I typically think of when I hear the term and that’s the one that most closely resembles the API gateway *pattern*. [Chris Richardson](https://www.chrisrichardson.net) does an excellent job of covering this usage in [his book “Microservices Patterns”](https://microservices.io/book) in chapter 8. I highly recommend getting this book for this and other microservices-patterns education. A quicker tour can be seen on his [microservices.io site on API Gatway Pattern](https://microservices.io/patterns/apigateway.html) In short, the API-gateway pattern is about curating an API for more optimal usage by different classes of consumers. This curation involves a level of API indirection. Another term you may hear that represents the API gateway pattern is “backend for frontends” where "front end" can be literal front ends (UIs), mobile clients, IoT clients, or even other service/application developers. 

In the API Gateway pattern, we are explicitly simplifying the calling of a group of APIs to emulate a cohesive API for an “application” for a specific set of users, clients, or consumers. Recall that as we use microservices to build our systems, the notion of “application” kind of disappears. The API Gateway pattern helps to restore this notion. The key here is the API gateway, when it’s implemented, _becomes_ the API for clients and applications and is responsible for communicating with any backend APIs and other application network endpoints (those that don’t meet the aforementioned definition of API).

Unlike the Ingress controller from the previous section, this API gateway is much closer to the developers view of the world and is less concentrated on what ports or services are exposed for outside-the-cluster consumption. This “API gateway” is also different from the API management worldview where we are managing _existing APIs_. This API gateway mashes up calls to backends that _may_ expose APIs, but may also talk to things less described as APIs such as RPC calls to legacy systems, calls with protocols that don’t fit the nice semblance of “REST” such as hacked together JSON over HTTP, gRPC, SOAP, GraphQL, websockets, and message queues. This type of gateway may also be called upon to do message-level transformation, complex routing, network resilience/fallbacks, and aggregation of responses. 

If you’re familiar with the [Richardson Maturity model of REST APIs](https://www.crummy.com/writing/speaking/2008-QCon/act3.html), an API gateway implementing the API gateway pattern would be called upon to integrate much more of the Level 0 requests (and everything in between) than the Level 1 - 3 implementations. 

![](/images/identity-crisis/richardson-model.png)

[https://martinfowler.com/articles/richardsonMaturityModel.html](https://martinfowler.com/articles/richardsonMaturityModel.html)


These types of gateway implementations still need to solve for things like rate-limiting, authentication/authorizations, circuit breaking, metrics collection, traffic routing and the like. These types of gateways can be used at the edge of your cluster as a cluster ingress controller or deep within your cluster as application gateways. 

![](/images/identity-crisis/api-gateway-pattern.png)

Examples of this type of API Gateway include:

* [Spring Cloud Gateway](http://spring.io/projects/spring-cloud-gateway)
* [Solo.io Gloo](https://gloo.solo.io)
* [Netflix Zuul](https://github.com/Netflix/zuul)
* [IBM-Strongloop Loopback/Microgateway](https://strongloop.com)

This type of gateway can also be built using more general purpose programming or integration languages/frameworks like:

* [Apache Camel](https://github.com/apache/camel)
* [Spring Integration](https://spring.io/projects/spring-integration)
* [Ballerina.io](https://ballerina.io)
* [Eclipse Vert.x](https://vertx.io)
* [NodeJS](https://nodejs.org/en/)

Since this type of API gateway is so closely related to the development of applications and services, we’d expect developers to be involved in helping to specify the APIs exposed by the API gateways, understanding any of the mashup logic involved, as well as need the ability to quickly test and make changes to this API infrastructure. We also expect operations or SRE to have some opinions about  security, resiliency, and observability configuration for the API gateway. This level of infrastructure must also fit into the evolving, on-demand, self-service developer workflow. Again see the GitOps model for more on that. 


## Bring on the service mesh

Part of operating a services architecture on cloud infrastructure includes the difficulty of building the right level of observability and control into the network. In previous iterations of solving for this problem, [we used application libraries and hopeful developer governance to achieve this](http://blog.christianposta.com/microservices/application-safety-and-correctness-cannot-be-offloaded-to-istio-or-any-service-mesh/). However, at scale and across a polyglot environment, the [emergence of service-mesh technology lends a better solution](http://blog.christianposta.com/microservices/application-safety-and-correctness-cannot-be-offloaded-to-istio-or-any-service-mesh/). Service mesh brings the following capabilities to a platform and its constituent services by transparently implementing

* Service to service (ie, east-west traffic) resilience
* Security including end-user auth verification, mutual TLS, service-to-service RBAC/ABAC
* Black-box service observability (focused on network communication) for things like requests/second, request latency, request failures, circuit-breaking events, distributed tracing, etc
* Service-to-service rate limiting, quota enforcement, etc


The astute reader will recognize that there appears to [be some overlap in functionality with an API gateway and service mesh](https://dzone.com/articles/api-gateway-vs-service-mesh). The goal of the service mesh is to solve these problems generically for any service/application by doing so transparently at L7. In other words, the service mesh wishes to blend into the service (without actually being coded into the service’s code). On the other hand, API gateways live _above_ the service mesh and with the applications (L8?). Service mesh brings value to the flow of requests between services, hosts, ports, protocols, etc (east/west traffic). They can also provide basic cluster ingress capabilities to bring some of this functionality to the north/south traffic. However, this should not be confused with the capabilities that the API gateway can bring to north/south traffic (as in north/south to the cluster AND north/south to an application or group of applications). 


Service Mesh and API gateway overlap  in functionality in some areas but are complementary in that they live at different levels and solve different problems. The ideal solution would be to plug and play each of the components (API Management, API Gateway, Service Mesh) into your solution with nice boundaries between the components as you need them (or exclude them as you don’t need them). Equally important is finding the implementation of these tools that [fit into your decentralized developer and operations workflow](https://developer.ibm.com/apiconnect/2018/12/10/api-management-centralized-or-decentralized/). Even though there is confusion in the terms and identities of these different components, we should rely on first principles and understand where in our architecture these components bring value and how they can exist independently and co-exist complementarity. 

![](/images/identity-crisis/api-layers.png)

## We’d love to help!

Some of you may know that I’m passionate about helping people especially in the world of cloud, microservices, event-driven architectures, and service mesh. At my company, [Solo.io](https://developer.ibm.com/apiconnect/2018/12/10/api-management-centralized-or-decentralized/), we are helping organizations cut through the confusion and successfully adopt API technology like gateways and service mesh at the appropriate level as well as at the pace they can successfully consume them (if they need them, more importantly!!). We’re building tools like [Gloo](https://gloo.solo.io), [Scoop](https://sqoop.solo.io), and [SuperGloo](https://supergloo.solo.io) on top of technology like [Envoy Proxy](https://www.envoyproxy.io), [GraphQL](https://graphql.org), and [Istio](https://istio.io) to help implement API gateway and service-mesh management. Please reach out to us ([@soloio_inc](https://twitter.com/soloio_inc), [http://solo.io](http://www.solo.io)) or me directly ([@christianposta](http://www.twitter.com/christianposta), [blog](http://blog.christianposta.com)) to get a deep dive on our vision and how our technology can help your organization. In the next series of blogs, we'll dig deeper into the API Gateway pattern, the difficulties of multiple clusters, multi-service-mesh difficultes and more! Stay tuned!


Also related reading: 

[http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/](http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/)
