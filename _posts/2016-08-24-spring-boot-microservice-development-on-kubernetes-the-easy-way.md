---
layout: post
title: "Spring Boot Microservice Development on Kubernetes: The Easy Way"
modified:
categories: microservices
comments: true
tags: [microservices, spring boot, kubernetes, fabric8, cloud, docker]
image:
  feature:
date: 2016-08-24T08:20:25-07:00
---

Ever wondered how to create, build, deploy new [Spring Boot](http://projects.spring.io/spring-boot/) microservices on [Kubernetes](http://kubernetes.io) What if you had integrated tooling in whatever IDE you used (IntelliJ, Eclipse, NetBeans, CLI, web, whatever) that can bootstrap a Spring Boot microservice app for you. What if you could easily build a docker image out of it and deploy to Kubernetes or [OpenShift](https://www.openshift.org)?

With the awesome work in the [Fabric8.io](https://fabric8.io) community, you now can.

Here are 4 demos that might be interesting to you:

* IDE based development
* CI/CD based development (this is spring boot made easy!)
* Hystrix/Dashboards in Kubernetes
* Zipkin

Take a look at this demo for using your IDE to create a Spring Boot microservice and run it on Kubernetes (complete with [spring-cloud-kubernetes](https://github.com/fabric8io/spring-cloud-kubernetes) integration for config-management, et. al.):

<iframe src="https://player.vimeo.com/video/180053437" width="640" height="360" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>
<p><a href="https://vimeo.com/180053437">Spring Boot, Spring Cloud with Kubernetes and Fabric8</a> from <a href="https://vimeo.com/ceposta">Christian Posta</a> on <a href="https://vimeo.com">Vimeo</a>.</p>

Take a look at this demo if you just want a single, one-stop-shop for creating your Spring Boot app, check it into Git, attach it to a complex CI/CD pipeline (based on [Jenkins Pipelines](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)) and get you off and running QUICKLY:

<iframe src="https://player.vimeo.com/video/180052838" width="640" height="360" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>
<p><a href="https://vimeo.com/180052838">Spring Boot the easy way with Fabric8.io</a> from <a href="https://vimeo.com/ceposta">Christian Posta</a> on <a href="https://vimeo.com">Vimeo</a>.</p>


Maybe you'd also like to see how Hystrix plays in a Kubernetes world? Take a look at this:

<iframe src="https://player.vimeo.com/video/177320966" width="640" height="360" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>
<p><a href="https://vimeo.com/177320966">Spring Cloud Kubernetes / Fabric8 Part II</a> from <a href="https://vimeo.com/ceposta">Christian Posta</a> on <a href="https://vimeo.com">Vimeo</a>.</p>


Or Zipkin?

<iframe src="https://player.vimeo.com/video/177416632" width="640" height="360" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>
<p><a href="https://vimeo.com/177416632">Spring Cloud Kubernetes / Fabric 8 Part III</a> from <a href="https://vimeo.com/ceposta">Christian Posta</a> on <a href="https://vimeo.com">Vimeo</a>.</p>



Stay tuned (@christianposta) because there's more to come!



