---
layout: post
title: Understanding Istio Telemetry v2
modified:
categories: 
comments: true
tags: [istio, microservices]
image:
  feature:
date: 2021-04-26T18:08:04-07:00
---

It's been a while since I've blogged, and just like other posts in the past, this one is meant as a way to dig into something and for me to catalog my own thoughts for later. While digging into some issues for some of [our Istio customers](https://solo.io) as well as for a chapter in my [upcoming book, Istio in Action,](https://www.manning.com/books/istio-in-action) I found myself knee-deep in the Istio telemetry v2 functionality. Let's see how it works.

We will use source code from [https://github.com/christian-posta/istio-telemetry-v2](https://github.com/christian-posta/istio-telemetry-v2) for this blog. 

## Istio telemetry v2

Istio telemetry v2 is a combination of data-plane extensions (ie, Envoy extensions) and an programable API to allow operators to tune, customize, and even create "service-level" metrics within the proxy. This "v2" status replaces a previous implementation based on an out-of-band integration engine called Mixer. 

There are three main concepts in the telemetry v2 functionality that you should understand to fully wrap your ahead around what it's doing and how to customize it:

* Metrics
* Dimensions
* Attributes

A metric is a counter, gauge, or histogram/distribution of telemetry signals between service calls (inbound/outbound). For example, some of the [Istio standard metrics](https://istio.io/latest/docs/reference/config/metrics/) are:

* `istio_requests_total` a COUNTER measuring total number of requests
* `istio_request_duration_milliseconds` a DISTRIBUTION measuring latency of requests
* `istio_request_bytes` a DISTRIBUTION which measure http request body sizes
* `istio_response_bytes` a DISTRIBUTION which measures http response body sizes

For the `istio_requests_total` metric, we count the total number of requests that have come through. The interesting bit is that a metric can have various _dimensions_ which are additional properties that give more depth and insight for a particular metric. 

[From the docs](https://istio.io/latest/docs/concepts/observability/#service-level-metrics), you can see for example, the `istio_requests_total` metric has some out of the box dimensions. Here's an example of those dimensions:

```bash
istio_requests_total{
    response_code="200",
    reporter="destination",
    source_workload="web-api",
    source_workload_namespace="istioinaction",
    source_principal="spiffe://cluster.local/ns/istioinaction/sa/default",
    source_app="web-api",
    source_version="unknown",
    source_cluster="Kubernetes",
    destination_workload="recommendation",
    destination_workload_namespace="istioinaction",
    destination_principal="spiffe://cluster.local/ns/istioinaction/sa/default",
    destination_app="recommendation",
    destination_version="unknown",
    destination_service="recommendation.istioinaction.svc.cluster.local",
    destination_service_name="recommendation",
    destination_service_namespace="istioinaction",
    destination_cluster="Kubernetes",
    request_protocol="http",
    response_flags="-",
    grpc_response_status="",
    connection_security_policy="mutual_tls",
    source_canonical_service="web-api",
    destination_canonical_service="recommendation",
    source_canonical_revision="latest",
    destination_canonical_revision="latest"
  } 5
```
This means we've seen `5` requests from the `web-api` app to the `recommendation` app that have a `response_code` of HTTP 200. If any of these dimensions are different, we'll see a new entry for this metric. For example, if there are any HTTP `500` response codes, we'd see this in a different line (some dimensions left out for brevity):

```bash
istio_requests_total{
    response_code="200",
    reporter="destination",
    source_workload="web-api",
    source_workload_namespace="istioinaction",
    destination_workload="recommendation",
    destination_workload_namespace="istioinaction",
    request_protocol="http",
    connection_security_policy="mutual_tls",
  } 5

istio_requests_total{
    response_code="500",
    reporter="destination",
    source_workload="web-api",
    source_workload_namespace="istioinaction",
    destination_workload="recommendation",
    destination_workload_namespace="istioinaction",
    request_protocol="http",
    connection_security_policy="mutual_tls",
  } 3
```  

The last important bit of detail is where these _dimensions_ come from. To answer this, we need to understand `attributes` and `CEL expressions`. In it's simplest form a dimension gets its values at runtime from attributes that come from Envoy's [underlying attributes](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/advanced/attributes) or from [Istio's peer-metadata filter](https://istio.io/latest/docs/tasks/observability/metrics/customize-metrics/#use-expressions-for-values). 

For example, let's see the [Request Attributes that come from Envoy](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/advanced/attributes#request-attributes):

|Attribute | Description|
|----------|------------|
|request.path|The path portion of the URL|
|request.url_path|The path portion of the URL without the query string|
|request.host|The host portion of the URL|
|request.scheme|The scheme portion of the URL e.g. “http”|
|request.method|Request method e.g. “GET”|
|request.headers|All request headers indexed by the lower-cased header name|
|request.referer|Referer request header|
|request.useragent|User agent request header|
|request.time|Time of the first byte received|
|request.id|Request ID corresponding to x-request-id header value|
|request.protocol|Request protocol (“HTTP/1.0”, “HTTP/1.1”, “HTTP/2”, or “HTTP/3”)|

For example, to map an attribute to a dimension, we can configure the metric (we'll see that in the next section) like this:

```yaml
  request_url = request.url
```

As stated earlier, there is a _wealth_ of available attributes out of the box from Envoy as well as from Istio's Peer Metadata plugin. Please check the respective docs. We can even _create our own derivative attributes_ to use for a particular dimension which we'll see in the next section.

## Metrics in Action

Let's see how this all works with an example. You can follow along with the source at [https://github.com/christian-posta/istio-telemetry-v2](https://github.com/christian-posta/istio-telemetry-v2).

First, [set up and deploy the sample applications](https://github.com/christian-posta/istio-telemetry-v2/blob/master/README.md). The sample applications show a call graph between three different services:

`web-api` --> `recommendation` --> `purchase-history`

We have configured the `purchase-history` service to return errors on 50% of the calls (HTTP 500) and for the rest, to return a latency of P50 of 750ms (variance of 100ms). We can easily make some sample calls with the following command (you should try run this a few times):

```bash
$  kubectl -n default exec -it deploy/sleep -- curl -H "Host: istioinaction.io" http://istio-ingressgateway.istio-system/
```

Now, let's evaluate the metrics from the `recommendation` service to see what has been captured and for what dimensions:

```bash
kubectl exec -it -n istioinaction deploy/recommendation -c istio-proxy -- curl localhost:15000/stats/prometheus | grep istio_requests_total
```

We should see something like:

```
istio_requests_total{
response_code="200",reporter="destination",source_workload="web-api", source_workload_namespace="istioinaction",destination_workload="recommendation",    destination_workload_namespace="istioinaction",request_protocol="http",    connection_security_policy="mutual_tls" 
} 5
istio_requests_total{
response_code="500",reporter="destination",source_workload="web-api", source_workload_namespace="istioinaction",destination_workload="recommendation",    destination_workload_namespace="istioinaction",request_protocol="http",    connection_security_policy="mutual_tls" 
} 3
istio_requests_total{
response_code="200",reporter="source",source_workload="recommendation", source_workload_namespace="istioinaction",destination_workload="purchase-history",    destination_workload_namespace="istioinaction",request_protocol="http",    connection_security_policy="mutual_tls" 
} 5
istio_requests_total{
response_code="500",reporter="source",source_workload="recommendation", source_workload_namespace="istioinaction",destination_workload="purchase-history",    destination_workload_namespace="istioinaction",request_protocol="http",    connection_security_policy="mutual_tls" 
} 3
```

We can see four different entries for the `istio_requests_total` along a couple different dimensions (some dimensions removed for brevity). We see differences in the `reporter`, `response_code`, `source_workload`, and `destiation_workload` dimensions. 

We can see a latency distribution for the requests with the `istio_request_duration_milliseconds` metric

```bash
kubectl exec -it -n istioinaction deploy/recommendation -c istio-proxy -- curl localhost:15000/stats/prometheus | grep istio_request_duration_milliseconds
```

## Customizing metrics

We can also customize what dimensions are included in a particular metric. In fact, there is already an out of the box example for how to configure these metrics. When we install Istio, a few `EnvoyFilter`s are installed which configure metrics.

```bash
$  kubectl get EnvoyFilter -A

NAMESPACE      NAME                        AGE
istio-system   metadata-exchange-1.8       51m
istio-system   metadata-exchange-1.9       51m
istio-system   stats-filter-1.8            51m
istio-system   stats-filter-1.9            51m
istio-system   tcp-metadata-exchange-1.8   51m
istio-system   tcp-metadata-exchange-1.9   51m
istio-system   tcp-stats-filter-1.8        51m
istio-system   tcp-stats-filter-1.9        51m
```

The one we're interested in is the `stats-filter-*` EnvoyFilter. If we take a look at the `stats-filter-1.9` we see an EnvoyFilter definition but the salient part is here:

```bash
$   kubectl get EnvoyFilter -n istio-system stats-filter-1.9 -o yaml
```

```yaml
  - applyTo: HTTP_FILTER
    match:                           
      context: SIDECAR_OUTBOUND                                                        
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
      proxy:
        proxyVersion: ^1\.9.*
    patch:
      operation: INSERT_BEFORE
      value:
        name: istio.stats
        typed_config:
          '@type': type.googleapis.com/udpa.type.v1.TypedStruct
          type_url: type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
          value:
            config:
              configuration:
                '@type': type.googleapis.com/google.protobuf.StringValue
                value: |
                  {
                    "debug": "false",
                    "stat_prefix": "istio", 
                    "metrics": [
                      {
                        "dimensions": {
                          "source_cluster": "node.metadata['CLUSTER_ID']",
                          "destination_cluster": "upstream_peer.cluster_id"
                        }
                      }
                    ]
                  }
              root_id: stats_outbound
              vm_config:
                code:
                  local:
                    inline_string: envoy.wasm.stats
                runtime: envoy.wasm.runtime.null
                vm_id: stats_outbound
```

This EnvoyFilter is used to ADD a new configuration to the [Envoy Http Connection Manager](https://www.envoyproxy.io/docs/envoy/latest/api-v2/config/filter/network/http_connection_manager/v2/http_connection_manager.proto) and the chain of filters used to process an HTTP request. Note there are multiple configuration sections in this EnvoyFilter because we configure both the INBOUND as well as OUTBOUND paths. Specifically this is added toward the end of the chain BEFORE the `router` filter (this is important... the router should be the last filter in this chain). The important config bits are the following:

```json
      {
        "debug": "false",
        "stat_prefix": "istio", 
        "metrics": [
          {
            "dimensions": {
              "source_cluster": "node.metadata['CLUSTER_ID']",
              "destination_cluster": "upstream_peer.cluster_id"
            }
          }
        ]
      }
```

This configuration stanza corresponds to the [Istio docs here](https://istio.io/latest/docs/reference/config/proxy_extensions/stats/#PluginConfig) and if you're really interested, corresponds to the proto in the `stats` [extension here](https://github.com/istio/proxy/blob/master/extensions/stats/config.proto). 

Specifically what gets configured here is the `cluster` dimensions for ALL of the standard Istio metrics (it's ALL because we don't explicitly name a metric here). 

Let's change the metrics a bit. We can edit the `stats-filter` directly, or we can create a different EnvoyFilter that augments the `stats-filter` with our new configuration. From the source code for this blog, see the [customize-metric.yaml](https://github.com/christian-posta/istio-telemetry-v2/blob/master/customize-metric.yaml) file for the full contents:

```json
      {
        "debug": "false",
        "stat_prefix": "istio",
        "metrics": [
          {
            "name": "requests_total",
            "dimensions": {
              "posta": "upstream_peer.istio_version",
              "posta_two": "node.metadata['MESH_ID']"
            },
            "tags_to_remove": [
              "request_protocol"
            ]
          },                    
          {
            "dimensions": {
              "source_cluster": "node.metadata['CLUSTER_ID']",
              "destination_cluster": "upstream_peer.cluster_id"
            }
          }
        ]
      } 
```

In this configuration we've added two _new_ dimensions called `posta` and `posta_two` and we use attributes from the previous section to populate them. 

```bash
$  kubectl apply -f customize-metric.yaml
```

If we reviewed our metric at this point, we'd see some discrepancies. The `posta` and `posta_two` dimension _is not known to our proxy_ so before we can use it, we need to expose it. This is because these new dimensions are not in the [default tag list that Istio knows about](https://github.com/istio/istio/blob/master/pkg/bootstrap/config.go#L152). Let's add the following annotation to our `recommendation` Deployment pod spec:

```yaml
  template:
    metadata:
      labels:
        app: recommendation
      annotations:
        sidecar.istio.io/extraStatTags: posta,posta_two
```

This exposes the metric dimensions correctly. 

```bash
$  kubectl apply -f recommendation-tags.yaml -n istioinaction
```

Now let's place a few calls:

```bash
$  kubectl -n default exec -it deploy/sleep -- curl -H "Host: istioinaction.io" http://istio-ingressgateway.istio-system/
```

Now if we review our `istio_requests_total` metric we should see the new dimensions:

```bash
kubectl exec -it -n istioinaction deploy/recommendation -c istio-proxy -- curl localhost:15000/stats/prometheus | grep istio_requests_total
```

```bash
istio_requests_total{
    response_code="200",
    reporter="destination",
    source_workload="web-api",
    source_workload_namespace="istioinaction",
    destination_workload="recommendation",
    destination_workload_namespace="istioinaction",
    request_protocol="http",
    connection_security_policy="mutual_tls",
    posta="1.9.3",
    posta_two="cluster.local"
  } 5

istio_requests_total{
    response_code="500",
    reporter="destination",
    source_workload="web-api",
    source_workload_namespace="istioinaction",
    destination_workload="recommendation",
    destination_workload_namespace="istioinaction",
    request_protocol="http",
    connection_security_policy="mutual_tls",
    posta="1.9.3",
    posta_two="cluster.local"    
  } 3
```  

## Creating new metrics

The last thing we'll look at in this blog is creating a new metric. To do that, we need to [specify a metric definition](https://istio.io/latest/docs/reference/config/proxy_extensions/stats/#MetricDefinition) in the configuration for the stats plugin. Something like this would work to create a new metric called `posta_metric`:


```json
      {
        "debug": "false",
        "stat_prefix": "istio",
        "definitions": [
          {
            "name": "posta_metric",
            "type": "COUNTER",
            "value": "1"                      
          }
        ]
      }
```

This is a very simple metric of type `COUNTER` which just counts requests when they come in (just like `istio_requests_total`). However, the `value` field is actually a `string` where you can place a [CEL expression](https://opensource.google/projects/cel) that evaluates some _attributes_; just note that this expression should evaluate to an integer.

Let's apply the [create-new-metric.yaml](https://github.com/christian-posta/istio-telemetry-v2/blob/master/create-new-metric.yaml) from our source code repo:

```bash
$  kubectl apply -f create-new-metric.yaml
```

Just like we exposed extra dimensions on the `recommendation` deployment in the previous step, we will need to expose this new metric with the `statsInclusionPrefixes` annotation:


```yaml
  template:
    metadata:
      labels:
        app: recommendation
      annotations:
        sidecar.istio.io/extraStatTags: posta,posta_two
        sidecar.istio.io/statsInclusionPrefixes: istio_posta_metric
```

Note that even though we called the metric `posta_metric` it gets a prefix of `istio_` anyway.

```bash
$  kubectl apply -f recommendation-new-metric.yaml -n istioinaction
```

Now let's send some more traffic:

```bash
$  kubectl -n default exec -it deploy/sleep -- curl -H "Host: istioinaction.io" http://istio-ingressgateway.istio-system/
```

Now if we review our `istio_requests_total` metric we should see the new dimensions:

```bash
$  kubectl exec -it -n istioinaction deploy/recommendation -c istio-proxy -- curl localhost:15000/stats/prometheus | grep posta_metric

# TYPE istio_posta_metric counter
istio_posta_metric{} 2
```

Note there are no dimensions for this metric! Just like we customized the dimensions for metrics in the previous section, we could do something like this:

```json
      {
        "debug": "false",
        "stat_prefix": "istio",
        "metrics": [
          {
            "name": "posta_metric",
            "dimensions": {
              "posta": "upstream_peer.istio_version",
              "posta_two": "node.metadata['MESH_ID']"
            }
          }
        ]
      } 
```

Note, when we name the metric explicitly, we DON'T need to use the prefix `istio_` as it will understand it by default. 

## Creating your own attributes

Hopefully this blog as gone into enough detail about understanding metrics and Istio's telemetry v2. Armed with this information, you should now be able to see the Istio docs about [generating your own attributes so you can use those in dimensions](https://istio.io/latest/docs/reference/config/proxy_extensions/attributegen/). 

## For more information

I cover Istio telemetry v2 deeply in chapter 7 of [Istio in Action](https://www.manning.com/books/istio-in-action). Also check the [community Istio docs](https://istio.io/latest/docs/tasks/observability/metrics/customize-metrics/). If you're deploying Istio and need help, please reach out to me ([@christianposta](http://twitter.com/christianposta?lang=en)) or `ceposta` on CNCF/Kubernetes/Istio/Solo.io slack. 