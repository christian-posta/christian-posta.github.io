---
layout: post
title: Guidance for Building a Control Plane for Envoy - Testing Your Control Plane
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-02-18T13:41:25-07:00
hidden: 1
---

## Testing your control plane

* Build tests
    * Gloo does e2e testing OUTSIDE of k8s cluster
        * If you can, you can run tests more frequently
    * Also in k8s

### Takeaway