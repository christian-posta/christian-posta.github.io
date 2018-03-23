---
layout: post
title: "How a Service Mesh Can Help With Microservices Security"
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2018-03-22T16:12:59-07:00
---

I see lots of customers moving to microservices, (whether they [should or not is a topic for a different post](http://blog.christianposta.com/microservices/when-not-to-do-microservices/)), and in doing so they are attempting to solve some difficult organizational scaling problems. The details of going to microservice architecture often trades some old problems for new ones, however. Most of the customers I speak with have a strategy of having both an on-premise as well as public cloud deployment of their architecture. Breaking applications into smaller services AND having multi deployment sites/platforms creates some major challenges. In my opinion, service mesh implementations like [Istio](https://istio.io) aim to solve some of these challenges. I [actually have a lot to say about Istio and Service Mesh](http://blog.christianposta.com) in general, so please feel free to [follow along @christianposta](https://twitter.com/christianposta) to participate and stay up with the latest. 

One challenge you'll face as you go down this road is: security.

I know, I know. As developers, you probably already have a hate-hate relationship with security -- microservices makes it even worse. As we break applications into smaller services, we increase our surface area for attacks. Although there are many aspects of security here (application vulnerability, platform vulnerability, data protection, transport/network, etc) I'm going to concentrate this post mostly on how microservices communicate with each other and some of the problems that arise. 

Traditionally, we've assumed that networking boundaries/perimeters were enough to save us; ie, our applications didn't have to consider THAT much in the way of transport security because we were on a "protected, internal network". Stop and think for a second. Do you secure your internal applications with SSL/TLS? All of the communication that we used to do inside a single monolith via local calls is now exposed over the network. The first thing we need to do is encrypt all of our internal traffic. If you're doing microservices without TLS on the transport, you're setting yourself up for some nasty security problems.

Some mature customers have achieved the ability to encrypt all of their microservices traffic, but not without significant cost. Standing up Public Key Infrastructure, issuing keys and certificates, installing, rotating them etc is quite an expensive ordeal. Nevermind the headache that comes with trying to configure the right truststores/keystores (Java), proper SSL algorithms, making sure you have the right certificate chains, etc, etc. I've personally wasted many days trying to get this "just right". And then, when you get it just right, you don't want to touch it ever again. 

I've also seen instances where developers go along with SSL/TLS and then deploy their code into IST/UAT, etc only to find the security configuration they had in lower environments doesn't work. And in a rush to move things along to production, they do things like disabling TLS verification. Ouch.

A service mesh like Istio simplifies this quite a bit.  With Istio, all instances of an application have their own sidecar container. This sidecar acts as a service proxy to all outgoing and incoming network traffic. 

![](/images/istio-mesh.png)

Among the [many benefits achieved with this service proxy](https://istio.io/docs/concepts/what-is-istio/overview.html), one benefit relevant to this discussion is the ability to transparently do the TLS encryption. This means the proxies that sit in the path of the requests, which are collocated with the application, take on the responsibility of encrypting the traffic. Your application can stay free of certificates, trust stores, keystores and the like. Istio automates the delivery of the certificates and keys to the services, the proxies use them to encrypt the traffic (providing mutual TLS), and periodically Istio will rotate the keys/certificates to reduce exposure to compromise. 

![](/images/istio-auth.png)

With Istio [running on Kubernetes](https://istio.io/docs/setup/kubernetes/quick-start.html), as an example, whenever you deploy your application you should assign a service account under which the application should run -- after that, istio takes care of the rest. Istio will create a certificate/key pair for your service account, sign the certificate with a root CA key and issue the certificate/keys as a secret in Kubernetes. This secret will get mounted into the Pod where your application and Istio service proxy runs, and the service proxy will use the cert/keys to establish mTLS. 

![](/images/istio-mtls.png)


Another security concern with microservices is the [confused deputy problem](https://en.wikipedia.org/wiki/Confused_deputy_problem). In this case, an end user has asked a service to do something on its behalf. In this case, the service may be authorized to do this action, but a particular user may not be. Somehow we should tie user identity into the equation and evaluate authorizations based on that identity. One way of doing this is by using value tokens like [JWT](https://jwt.io). 

A couple things to say about this:

First, if you're passing around JWT tokens in the clear (without TLS/mTLS), you're asking for major trouble. Those tokens are not encrypted by default (just signed) and they can easily be coopted and replayed to your service. Again, here's where Istio mTLS can help. But even with mTLS enabled, a token could get leaked another way (i've seen these hard coded into src code!!). If all of your services are passing the JWT through to every other service, you're opening yourself up to the replay problem again. 

Second, if youre trying to do JWT verification across all of your microservices you run into the [same issues that you would with resiliency libraries](http://blog.christianposta.com/microservices/the-hardest-part-of-microservices-calling-your-services/). Each service has its own libraries and its own implementation of JWT verification. Even though projects like [JBoss Keycloak](http://www.keycloak.org) provide excellent multi-language support, it does become a burden both on the library maintainers as well as the application developers who take a dependency on these libraries. Making sure they're all implemented correctly, consistently and applied uniformly is a feat fraught with issues. 

Thankfully, Istio can help with both of these areas.

Fisrt, Istio can automate the JWT verification for you regardless of the application framework/language.  You can define an `EndUserAuthenticationPolicySpec` which configures the identity provider/credential providers that will be used for verification:

{% highlight yaml %}
--- 
apiVersion: config.istio.io/v1alpha2
kind: EndUserAuthenticationPolicySpec
metadata: 
  name: cars-api-auth-policy
  namespace: tutorial
spec: 
  jwts: 
    - issuer: http://keycloak:8080/auth/realms/istio
      jwks_uri: http://keycloak.tutorial:8080/auth/realms/istio/protocol/openid-connect/certs
      audiences: 
      - cars-web  
{% endhighlight %}

Then you can bind it to specific services:

{% highlight yaml %}
--- 
apiVersion: config.istio.io/v1alpha2
kind: EndUserAuthenticationPolicySpecBinding
metadata:
  name: cars-api-auth-policy-binding
  namespace: tutorial
spec:
  policies:
    - name: cars-api-auth-policy
      namespace: tutorial
  services:
    - name: cars-api
      namespace: tutorial
{% endhighlight %}

Note: this example came from my collegue [Kamesh Sampath](https://twitter.com/kamesh_sampath). In this configuration we've set up Keycloak to be the identity manager and issuer of JWT tokens (following OpenID Connect). For more information [see this blog](http://blog.keycloak.org/2018/02/keycloak-and-istio.html).

Lastly, what about propagation of the JWT token?

Istio by default will only propagate the JWT token one hop. It will take the body of the JWT token and pass it along to the application in a separate header. The JWT body will be sent in the `sec-istio-auth-userinfo` header. It will be the responsibility of the application to resubmit for a new token based on the end user's identity and the service's identity. This way we can scope tokens to single use and not propagate JWTs all over the place. The implementation for this is still evolving and I highly recommend following along [here](https://docs.google.com/document/d/1_ccf9pUyN9G0UQqPP-ngr2Do5HcU5zzQZNj6NH1i3gs/edit#heading=h.kt4x5aalmyhf) and [here](https://docs.google.com/document/d/1rU0OgZ0vGNXVlm_WjA-dnfQdS3BsyqmqXnu254pFnZg/edit#heading=h.kt4x5aalmyhf).

That's it for now. As the security story within Istio strengthens, I'll be sure to follow up. Follow me [follow along @christianposta](https://twitter.com/christianposta) for latest on Microservices, Service Mesh, Istio and more.