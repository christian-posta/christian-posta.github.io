---
layout: post
title: "Traffic Shadowing With Istio: Reducing the Risk of Code Release"
modified:
categories: microservices
comments: true
tags: [microservices, istio, envoy, service mesh, resilience, sidecar]
image:
  feature:
date: 2018-02-07T05:52:40-07:00
---
We've [been](http://blog.christianposta.com/microservices/comparing-envoy-and-istio-circuit-breaking-with-netflix-hystrix/) [talking](http://blog.christianposta.com/microservices/deep-dive-envoy-and-istio-workshop/) [about Istio](http://blog.christianposta.com/microservices/low-risk-monolith-to-microservice-evolution-part-iii/) [and service mesh recently](http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/) (follow along [@christianposta](http://twitter.com/christianposta) for the latest) but one aspect of Istio can be glossed over.
One of the most important aspects of [Istio.io][istio-service-mesh] is its ability to [control the routing of traffic between services][istio-control-routing]. With this fine-grained control of application-level traffic, we can do interesting resilience things like routing around failures, routing to different availability zones when necessary etc. IMHO, more importantly, we can also control the flow of traffic for our deployments so we can reduce the risk of change to the system. 

With a services architecture, our goal is to increase our ability to go faster so we do things like implement microservices, automated testing pipelines, CI/CD etc. But what good is any of this if we have bottlenecks getting our code changes into production? Production is where we understand whether our changes have any positive impact to our KPIs, so we should reduce the bottlenecks of getting code into production.

At the typical enterprise customers that I visit regularly (Financial services, Insurance, Retail, Energy, etc) *risk* is such a big part of the equation. *Risk* is used as a reason for why changes to production get blocked. A big part of this risk is a code "deployment" is all or nothing in these environments. What I mean is there is no separation of *deployment* and *release*. This is such a hugely important distinction.

## Deployment vs Release

A __deployment__ brings new code to production but it takes **no production traffic**. Once in the production environment, service teams are free to run smoke tests, integration tests, etc without impacting any users. A service team should feel free to *deploy* as frequently as it wishes. 

A __release__ brings live traffic to a deployment but may require signoff from "the business stakeholders". Ideally, bringing traffic to a deployment can be done in a controlled manner to reduce risk. For example, we may want to bring internal-user traffic to the deployment first. Or we may want to bring a small fraction, say 1%, of traffic to the deployment. If any of these release rollout strategies (internal, non-paying, 1% traffic, etc) exhibit undesirable behavior (thus the need for strong observability) then we can rollback.  

Please go read the [two-part series titled "Deploy != Release"](https://blog.turbinelabs.io/deploy-not-equal-release-part-one-4724bc1e726b) from the good folks at [Turbine.io labs](https://www.turbinelabs.io) for a deeper treatment of this topic.

## Dark traffic 

One strategy we can use to reduce risk for our releases, before we even expose to any type of user, is to shadow traffic live traffic to our deployment. With traffic shadowing, we can take a fraction of traffic and route it to our new deployment and observe how it behaves. We can do things like test for excpetions, performance, and result parity. Projects such as [Twitter Diffy](https://github.com/twitter/diffy) can be used to do comparisons between different released versions and unreleased versions.

With Istio, we can do this kind of traffic control by [Mirroring](https://istio.io/docs/reference/config/istio.routing.v1alpha1.html#RouteRule) traffic from one service to another. Let's take a look at an example.


## Traffic Mirroring with Istio

With the [Istio 0.5.0 release](https://istio.io/about/notes/0.5.html) we have the ability to mirror traffic from one service to another, or from one version to a newer version.

We'll start by creating two deployments of an [httpbin](https://github.com/christian-posta/atlanta-microservices-day-demos/blob/master/istio-demo/httpbin-v1.yaml#L14) service. 

{% highlight bash %}
$  cat httpbin-v1.yaml
{% endhighlight %}

<script src="http://gist-it.appspot.com/https://github.com/christian-posta/atlanta-microservices-day-demos/blob/master/istio-demo/httpbin-v1.yaml#L14?slice=14:32"></script>

We'll inject the istio sidecar with `kube-inject` like this:

{% highlight bash %}
$  kubectl create -f <(istioctl kube-inject -f httpbin-v1.yaml)
{% endhighlight %}


Version 2 of the `httpbin` service is similar except it has labels that denote that it's version 2:

{% highlight bash %}
$  cat httpbin-v2.yaml
{% endhighlight %}


<script src="http://gist-it.appspot.com/https://github.com/christian-posta/atlanta-microservices-day-demos/blob/master/istio-demo/httpbin-v2.yaml"></script>



Let's deploy httpbin-v2 also:

{% highlight bash %}
$  kubectl create -f <(istioctl kube-inject -f httpbin-v2.yaml)
{% endhighlight %}

Lastly, let's deploy the `sleep` demo from [Istio samples](https://github.com/istio/istio/tree/master/samples/sleep) so we can easily call into our `httpbin` service:

{% highlight bash %}
$  kubectl create -f <(istioctl kube-inject -f sleep.yaml)
{% endhighlight %}

You should see three pods like this:

{% highlight bash %}
$  kubectl get pod
NAME                          READY     STATUS    RESTARTS   AGE
httpbin-v1-2113278084-98whj   2/2       Running   0          1d
httpbin-v2-2839546783-2dvhq   2/2       Running   0          1d
sleep-1512692991-txrfn        2/2       Running   0          1d
{% endhighlight %}



If we start sending traffic to the `httpbin` service, we'll see the default Kubernetes behavior to load balance across both `v1` and `v2` since both pods will match the selector for the  `httpbin` [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/). Let's take a look at the default Istio [route rule](https://istio.io/docs/reference/config/istio.routing.v1alpha1.html#RouteRule) to route all traffic to `v1` of our service:


<script src="http://gist-it.appspot.com/https://github.com/christian-posta/atlanta-microservices-day-demos/blob/master/istio-demo/routerules/all-httpbin-v1.yaml"></script>

Let's create this `routerule`:

{% highlight bash %}
$  istioctl create -f routerules/all-httpbin-v1.yaml
{% endhighlight %}


If we start sending traffic into our `httpbin` service, we should only see traffic for the `httpbin-v1` deployment:

{% highlight bash %}
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
kubectl exec -it $SLEEP_POD -c sleep -- sh -c 'curl  http://httpbin:8080/headers'

{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin:8080", 
    "User-Agent": "curl/7.35.0", 
    "X-B3-Sampled": "1", 
    "X-B3-Spanid": "eca3d7ed8f2e6a0a", 
    "X-B3-Traceid": "eca3d7ed8f2e6a0a", 
    "X-Ot-Span-Context": "eca3d7ed8f2e6a0a;eca3d7ed8f2e6a0a;0000000000000000"
  }
}
{% endhighlight %}

If we check the access logs for the `httpbin-v1` service, we should see a single access-log statement:


{% highlight bash %}
$  kubectl logs -f httpbin-v1-2113278084-98whj -c httpbin 
127.0.0.1 - - [07/Feb/2018:00:07:39 +0000] "GET /headers HTTP/1.1" 200 349 "-" "curl/7.35.0"    
{% endhighlight %}

If we check the logs for the `httpbin-v2` service, we should see NO access log statements.

Let's mirror traffic from `v1` to `v2`. Here's the Istio route rule we'll use:

<script src="http://gist-it.appspot.com/https://github.com/christian-posta/atlanta-microservices-day-demos/blob/master/istio-demo/routerules/mirror/mirror-traffic-to-httbin-v2.yaml"></script>

A few things to note:

* We are explicitly telling Istio to weight the traffic between v1 (100%) and v2 (0%)
* We are using labels to specify which version of httpbin service to which we want to mirror

Let's create this `routerule`

{% highlight bash %}
$  istioctl create -f routerules/mirror/mirror-traffic-to-httbin-v2.yaml
{% endhighlight %}

We should see routerules like this:

{% highlight bash %}
$  istioctl get routerules

$  istioctl get routerules
NAME                    KIND                                    NAMESPACE
httpbin-default-v1      RouteRule.v1alpha2.config.istio.io      tutorial
httpbin-mirror-v2       RouteRule.v1alpha2.config.istio.io      tutorial
{% endhighlight %}

Now if we start sending traffic in, we should see requests go to `v1` and requests shadowed to `v2`.

![](/images/httpbindemo.png)

## Video demo

Here's a video showing this:

<iframe src="https://player.vimeo.com/video/254681396" width="640" height="400" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>
<p><a href="https://vimeo.com/254681396">Istio Mirroring Demo</a> from <a href="https://vimeo.com/ceposta">Christian Posta</a> on <a href="https://vimeo.com">Vimeo</a>.</p>


Please see the offical [istio docs](https://istio.io/docs/tasks/traffic-management/mirroring.html) for more details!


[istio-service-mesh]: https://istio.io
[istio-control-routing]: https://istio.io/docs/tasks/traffic-management/request-routing.html