---
layout: post
title: Diving Into Istio 1.6 Certificate Rotation
modified:
categories: 
comments: true
tags: [istio, microservices]
image:
  feature:
date: 2020-07-13T13:41:03-07:00
---

[Istio is a powerful service mesh](https://istio.io/latest/) built on [Envoy Proxy](https://www.envoyproxy.io) that solves the problem of connecting services deployed in cloud infrastructure (like [Kubernetes](https://kubernetes.io)) and do so in a secure, resilient, and observable way. Istio's control plane can be used to specify declarative policies like those around circuit breaking, traffic routing, authentication/authorization, et. al. 

One important capability that [Istio provides is workload identity](https://istio.io/latest/docs/concepts/security/#istio-identity). With workload identity, we can encode an identity into a verifiable document and enforce authentication and authorization policies around this identity. Istio uses x509 certificates and [SPIFFE](https://spiffe.io) to implement identity and uses this mechanism to accomplish two important security practices: implement authentication and encrypt the transport (TLS/mTLS). With these foundational pieces in place, we can strongly secure all traffic between services.

## Understanding Istio's CA behavior

In this blog (and accompanying videos) we look at some typical use cases as well as some useful practices for dealing with things like Certificate Authority root certificates, intermediates, and rotating these various certificates as needed. Istio implements CA capabilities in its control plane component `istiod`. This component is responsible for bootstrapping the CA, serving a gRPC endpoint that can take Certificate Signing Requests (CSRs), and handling the signing of requests for new certificates or rotated certificates. 

On the client side, a service within the `istio-proxy` (that is, running as a sidecar with the workload) is responsible for creating workload certificates and initiating the CSR process with `istiod`. The default workload certificate validity is for 24 hours. This can be changed on the workload/client side with an environment variable `SECRET_TTL`. For example, to issue certificates for a shorter period of time, you could set `SECRET_TTL` environment variable to `12h0m0s`. 

## Bootstrapping a signing certificate to Istio's CA

Out of the box, Istio's CA will automatically create a signing key/certificate on bootstrap that's valid for 10 years. This "root" key will then be used to anchor all trust in the system by signing the workload CSRs and establishing the root certificate as the trusted CA. When Istiod starts up, you can see what root certificate it creates by checking the logs. You should see something like this:

```
2020-07-14T13:20:19.133413Z     info    Use self-signed certificate as the CA certificate
2020-07-14T13:20:19.186407Z     info    pkica   Load signing key and cert from existing secret istio-system:istio-ca-secret     
2020-07-14T13:20:19.187275Z     info    pkica   Using existing public key: -----BEGIN CERTIFICATE-----

You should see Certificate here

-----END CERTIFICATE-----                                                                                                                                    
                                                                                                                                                             
2020-07-14T13:20:19.284857Z     info    pkica   The Citadel's public key is successfully written into configmap istio-security in namespace istio-system.
```

If you're just exploring Istio, this default root CA should be sufficient. If you're setting up for a live system, you should probably not use the built-in, self-signed root. In fact, you likely already have PKI in your organization and would be able to introduce Intermediate certificates that can be used for Istio workload signing. These intermediates are signed by your existing trusted Roots. 

You can plug in your own `cacerts` secret [following the Istio documentation](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/).

## Signing Certificate Rotation

Here's where things can get a bit tricky. The Root of a certificate chain must be trusted by the workloads for any of the Istio mTLS/Authentication/Identity properties to work. So as you plan out your PKI, you should think about the appropriate processes to rotate any of the signing certificates Istio uses to issue workload certificates. In the next series of short (~5m each) videos, we walk through rotating Istio CA's signing certificates so as to minimize downtime when new trusted roots are introduced.

### Setting the context: Understanding Istio's Root CA

In this video we walk through the basics of bootstrapping Istio's signing CA (as discussed above). This video sets the context for the rest of the videos. 

<iframe width="560" height="315" src="https://www.youtube.com/embed/zIc2sRqW7h0" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>


### Plugging in your own signing certificates 

In this video we see what happens if we go from Istio's default, out of the box CA to our own CA with a different root. Notice how we break mTLS and trust in the system:

<iframe width="560" height="315" src="https://www.youtube.com/embed/XCXd2oOcxk0" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>


### Rotating intermediate certificates (same root)

In this video, we're on our own certificate with an organizational trust root and we wish to issue and rotate the intermediate certificate that Istio CA uses to sign workloads, let's see what happens when we do that:

<iframe width="560" height="315" src="https://www.youtube.com/embed/eW2xPylVkgY" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>


### Establishing trust for multiple roots (temporarily)

In this video we show how Istio can trust multiple root certificates for a period of time to enable rotation of the signing certificate with a new root (ie, when we need to rotate a Root CA):

<iframe width="560" height="315" src="https://www.youtube.com/embed/yBs58MnM7dE" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

### Rotating intermediate certificates (different root)

In this last video we introduce the new signing certificate which has a different/new root. Let's see how Istio behaves in this scenario:

<iframe width="560" height="315" src="https://www.youtube.com/embed/LHe7XQ8DTiM" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

## Where to go from here

Istio's powerful CA capabilities enable strong security between services. Some planning and thought needs to go into deploying and operating this infrastructure. Hopefully this material gives you things to think about. Feel free to reach out to me ([@christianposta](https://twitter.com/christianposta)) if you have any questions about this blog, or [get involved](https://istio.io/latest/about/community/join/) with the Istio community!