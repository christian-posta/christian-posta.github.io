---
layout: post
title: Exposing microservices running in AWS EKS with a microservices/API gateway like Solo Gloo
modified:
categories:
comments: true
tags: [AWS, EKS, Kubernetes, Load Balancers, Envoy, Gloo, Microservices]
image:
  feature:
date: 2019-02-07T21:10:27-05:00
---

So you've decided to run your Kubernetes workloads in AWS. [As we've seen before](https://medium.com/solo-io/easy-aws-eks-cluster-provisioning-and-user-access-5e3cdc01dfc6) setting up [AWS EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) requires a lot of patience and headache. You may be able to get it working. For others, you should check out the `eksctl` [tool from Weaveworks](https://github.com/weaveworks/eksctl).

Now that you've got a Kubernetes cluster, you want to start deploying your microservices to it and start exposing and integrating APIs and services to your clients and other parts of your organization. At [Solo.io](https://www.solo.io) we've [open-sourced a microservices gateway](https://medium.com/solo-io/announcing-gloo-the-function-gateway-3f0860ef6600) built on top of [Envoy Proxy](https://www.envoyproxy.io) named [Gloo](https://github.com/solo-io/gloo). [Gloo](https://github.com/solo-io/gloo) is a platform agnostic control plane for Envoy purposefully built to understand "function" level calls (think combination of HTTP path/method/headers, gRPC calls, or Lambda functions) for the purposes of composing them and building richer APIs for both north-south AND east-west traffic. Gloo is also highly complementary to service-mesh technology like [Istio](https://istio.io). 

Gloo's functionality includes:

<a href="https://gloo.solo.io"><img src="/images/aws-eks/gloo.png" align="right" /></a>

* Function routing (REST methods, gRPC endpoints, Lambda/Cloud Functions)
* Fine grained traffic shifting (function canary, function weighted routing, etc)
* Request/content transformations (implicit and explicit)
* Authorization / Authentication
* Rate limiting
* gRPC
* WebSockets 
* SOAP / WSDL 
* Deep metrics collection
* GraphQL Engine for aggregate data APIs
* powerful platform-agnostic discovery mechanisms

[Gloo](https://github.com/solo-io/gloo) has very deep Kubernetes-native support and can be run as a cluster-ingress for your Kubernetes cluster. As a side note, for some much-needed clarification on Ingress, API Gatweay, API Management (and even service mesh) take a look at the blog post ["API Gateways are going through an identity crisis"](http://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/)

In helping folks use Gloo in AWS EKS, we've had to navigate through the fairly complex choices of choosing and exposing services running in Kubernetes. These options will be the same for other Kuberentes-native ingress, API, or function gateways. Since AWS EKS is Kubernetes, we could expose a microservices/API gateway like Gloo in the following ways:

* a Kubernetes [Ingress Resource](https://kubernetes.io/docs/concepts/services-networking/ingress/)
* a Kubernetes [Service with type LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)
* a Kubernetes [Service as a NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport) (not recommended for production)

On Gloo, we are also working on [native OpenShift support](https://docs.openshift.com/container-platform/3.9/install_config/router/index.html) and should have it shortly. 

In the meantime, if you're running workloads on AWS EKS, you may have some questions about how to leverage a microservices gateway or whether you should just use the AWS managed  [AWS API Gateway](https://aws.amazon.com/api-gateway/)? 

Let's explore the options here. 

## Using AWS API Gateway with your EKS cluster
AWS EKS is really a managed control plane for Kubernetes and you run your worker nodes yourself. A typical setup is to have your worker nodes (EC2 Hosts) in a private VPC and using all of the built in VPC isolation, security groups, IAM policies, etc. Once you start deploying workloads/microservices to your Kubernetes cluster, you may wish to expose them and/or provide a nicely decoupled API to your clients/customers/partners, etc. Your first question is probably along the lines of "well, since I'm using AWS, it should just be super easy to use the [AWS API Gateway](https://aws.amazon.com/api-gateway/) in front of my Kubernetes cluster". 

![](/images/aws-eks/question.png)

As you start to dig, you realize it's not exactly that straight forward to connect AWS API Gateway to your EKS cluster. What you find is AWS API Gateway runs in it's own VPC and is completely managed so you cannot see any details about its infrastructure. Luckily, with AWS API Gateway, you _can_ do ["Private Integrations" to connect to HTTP endpoints running in your own VPC]( https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-private-integration.html). 

![](/images/aws-eks/nlb.png)

Private Integrations allow you to expose a [Network Load Balancer (NLB)](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) in your private VPC which can terminate traffic for your API Gateway to VPC integration. So basically the AWS API Gateway would create a [VpcLink](https://docs.aws.amazon.com/apigateway/api-reference/resource/vpc-link/) to a [NLB running in your VPC](https://aws.amazon.com/about-aws/whats-new/2017/11/amazon-api-gateway-supports-endpoint-integrations-with-private-vpcs/). 

So that's great! The Network Load Balancer is a [very powerful load balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) but even if it runs inside your VPC it doesn't know about or understand the workloads running in your Kubernetes cluster (ie, Kubernetes Pods). Let's change this. At this point we need to deploy some kind of [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-controllers) endpoint which understands how to route to Pods. Some folks might tend to favor using the native Kubernetes Ingress resource at this point, or you really could just use a single Kubernetes service exposed as a "LoadBalancer". In fact, we can take this a step further. The default load balancer created when you specify *LoadBalancer* in a Kubernetes Service in EKS is a [classic load balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/introduction.html). The problem with this is the API Gateway cannot route to a classic load balancer. We need the [Kubernetes service running inside EKS to create a network load balancer](https://aws.amazon.com/blogs/opensource/network-load-balancer-support-in-kubernetes-1-9/). For example, this configuration would create a classic load balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: gloo
  namespace: default
  annotations: {}
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: gloo
type: LoadBalancer
```

Adding the annotation `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"` will cause AWS to create a network load balancer when we create this service in EKS:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: gloo
  namespace: default
  labels:
    app: gloo
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  externalTrafficPolicy: Local
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: gloo
type: LoadBalancer
```

At this point, we have the correct combination of load balancer (NLB in private VPC) and AWS API Gateway configured correctly. We can even have [AWS web application firewall (WAF)](https://docs.aws.amazon.com/waf/latest/developerguide/how-aws-waf-works.html) enabled on the AWS API Gateway. The only problem is, we have the power (and cost) of the AWS API Gateway at the edge, but it still doesn't understand the workloads we have running within the Kubernetes cluster. 

![](/images/aws-eks/ingress.png)

When we want to do things like canary releases, API aggregation, function routing and content transformation, we need to do that within the Kubernetes cluster. Gloo solves for that. So do you really need API Gateway -> NLB -> API Gateway? In this case, you could just promote your network load balancer to a public subnet, let Gloo handle all of the API Gateway routing, traffic shaping, rate limiting, and not lose any of the functionality of the AWS API Gateway (Lambda routing, AuthZ/N, Websockets, etc). 

![](/images/aws-eks/gloo-routing.png)

## Alternative set ups

We started the previous section with an assumption that an AWS API Gateway would be simpler to integrate with our Kubernetes cluster when using EKS than an alternative solution. We found that's not the case. We do have other options, however. If you're using EKS, you'll need some sort of API gateway or microservices gateway [that runs within Kubernetes](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-controllers). But how do we get traffic to our EKS cluster? And what if we want to take advantage of things like the AWS Web Application Firewall (WAF)? 

The options we have, given the various types of load balancers and tradeoffs of running a microservices/API Gateway in AWS EKS come down to the following:

### AWS API Gateway + private VPC NLB + simple Kubernetes Ingress

![](/images/aws-eks/simple-ingress.png)

This is similar to the previous section, but instead of using a powerful microservices gateway like Gloo, you opt to use a basic ingress controller in Kubernetes. In this case you leverage the AWS API Gateay, have nice things like the AWS Web Application Firewall, but you lose the fidelity of workloads running in EKS (pods)

### AWS API Gateway + private VPC NLB + powerful Kubernetes microservices gateway like Gloo

![](/images/aws-eks/gloo-routing.png)

This is the usecase from the previous section. Now you've gained the power of a microservices gateway closer to the workloads in EKS, but you've got a redundant and expensive gateway at your edge. The benefit here is you still can take advantage of AWS web application firewall (WAF).

### Public NLB + powerful Kubernetes microservices gateway like Gloo

![](/images/aws-eks/public-nlb.png)

In this case, we've eschewed the AWS API Gateway and are just using a network load balancer sitting in a public subnet. All of the power of the microservices/API gateway now sits close to your workloads in EKS, but you lose the web application firewall (cannot be applied to NLB). If you have your own WAF you're using, this may not be a bad tradeoff.

### Public ALB + private NLB + powerful Kubernetes microservices gateway like Gloo

![](/images/aws-eks/alb-nlb.png)

You can more finely control the public facing network requests with an Application Load Balancer (which you can apply AWS WAF) and still keep your EKS traffic private and controlled through a private NLB. With this approach you can also centrally manage all of your certificates for TLS through CloudFormation

### Public ALB managed as a Kubernetes Ingress Controller + Kubernetes API Gateway private to the Kuberentes cluster

![](/images/aws-eks/alb-control.png)

You can use the [Kubernetes Ingress with Application Load Balancer](https://aws.amazon.com/blogs/opensource/kubernetes-ingress-aws-alb-ingress-controller/) 3rd-party plugin to manage your ALB in Kubernetes. At this point you can run your API Gateweay locally and privately within your EKS cluster and still take advantage of WAF because we're using an ALB. The downside is this functionality is provided by a third-party plugin and [you cannot centrally manage your certificates](https://www.sentialabs.io/2018/10/21/Integrating-EKS-with-other-AWS-services.html#fifth-challenge-deploying-api-gateway-in-front-of-eks) with cloud formation. That is, you have to use the [Ingress annotations to manage those](https://kubernetes-sigs.github.io/aws-alb-ingress-controller/guide/ingress/annotation/#ssl). 

## Conclusion

There are a handful of options to run your microservices/API Gateway in AWS EKS. Each combination comes with tradeoffs and should be carefully considered. We built [Gloo](https://github.com/solo-io/gloo) specifically to be a powerful cross platform, cross-cloud microservices API Gateway. This means you have even more options when running on AWS, on premises, or any other cloud. Each organization will have their unique constraints, opinions, and options. We believe there are good options to make a monolith to microserivces or on-premises hybrid deployment to public cloud a success. If you have an alternative suggestion for this use case, [please reach out to me @christianposta on twitter](http://www.twitter.com/christianposta) or in the comments of this blog.
