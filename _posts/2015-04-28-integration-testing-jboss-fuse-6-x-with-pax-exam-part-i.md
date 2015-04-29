---
layout: post
title: "Integration Testing JBoss Fuse 6.x With Pax Exam, Part I"
modified:
categories: testing
comments: true
tags: [jboss-fuse, pax-exam, integration-testing, fabric8]
image:
  feature:
date: 2015-04-28T22:35:06-07:00
---

[JBoss Fuse][fuse] is a powerful distributed integration platform with built in features for centralized configuration management, service discovery, versioning, API gateway, load balancing, failover, etc for your integration-focused microservice deployments. JBoss Fuse 6.x is built on top of the [Fabric8 1.x](http://fabric8.io/gitbook/index.html) opensource project.  This blog is the first part in a two-part series on integration testing when building integration microservices on top of JBoss Fuse.

![no test, no beer](/images/bobtest.jpg)
 
Honestly, I'm pleasantly surprised these days when people ask about the details of a testing strategy for the software/services they're writing. I figured everyone agrees testing is important but that nobody actually does it. I do a lot of work with customers that use JBoss Fuse to write their integration services, and I often get asked how best to go about testing those services.
  
JBoss Fuse uses [Apache Camel][camel] as its routing and mediation engine, and you end up writing the bulk of your integration logic with Camel. For testing Camel routes, I highly recommend using [the built-in test framework][builtin] that Camel ships with. Moreover, not only do I recommend using the built in test kit, I highly recommend you build the bulk of your tests with it. Being able to run camel and its associated tests outside of a container is a very important distinction with other integration solutions, and testing should take full advantage of that fact.

However, what if you have good Camel route test coverage and now you want to take a step further? You want to deploy your routes/applications into the JBoss Fuse container and verify everything was wired correctly, that OSGI imports/exports/metadata was included correctly, that services attached to the HTTP service, etc. These are legitimate reasons to want to deploy to a container, but doing this manually is error prone and slow. So what options are there for automating this?

I've run across a couple different ways to do this: using [Arquillian][arq] which is a container-agnostic integration testing framework originally developed for JBoss Application Server/Wilfly/EAP. There are some good [modules for integration testing your OSGI deployments][arq-osgi]. However, once you are trying to do more "black box" integration testing, Arquillian is not powerful enough at the moment for JBoss Fuse testing. For this, I'd recommend the [Pax Exam][paxexam] project. Pax Exam has been around for quite a while and has been used to test the various derivatives of ServiceMix/Karaf which are similar enough to JBoss Fuse for testing purposes.

So, in an effort to not only help out others wanting to get started with Pax Exam for integration testing JBoss Fuse 6.x, I've put together a getting started primer...  and more selfishly ... so that I can jot down these notes so that I can come back to them; as I've already done this enough times and forgot it that it's time to write it down.

## itests
I typically build out automated integration tests along with the project I'm going to test in a submodule named __itests__. You can feel free to do the same, or put your integration tests into a separate project. For this guide, I've built the integration tests into the [Rider Auto OSGI][rider] sample project that is adapted from [Claus Ibsen][davsclaus] and [Jon Anstey][janstey]'s book [Camel in Action][cia]. Feel free to browse that project to get a feel for what the modules do. 

To get started, I highly recommend you take a browse of the [Pax Exam][paxexam] documentation and then poke your head into the file named [FuseTestSupport](https://github.com/christian-posta/rider-auto-osgi/blob/master/itests/src/test/java/org/jboss/fuse/example/support/FuseTestSupport.java#L80). In it, you'll see the method that contributes the `@Configuration` of the OSGI container:

<script src="https://gist.github.com/christian-posta/1f4cc982d4ccc4e989eb.js"></script>

Note, that we're using the _actual_ distribution of JBoss Fuse, not some hacked-0together version. For this to work, you need to go to the JBoss.org [website][fuse], download Fuse, and install it into your maven repository corresponding to the coordinates specified in the above code snippet, to wit, something like this: `~/.m2/repository/org/jboss/fuse/jboss-fuse-minimal/6.1.0.redhat-379/<put distro here>` Now when the test runs, it will find the Fuse disto.

You can also take a look at the configuration options, including editing some of the out of the box configuration options, adding features, altering the log level, etc. You can [take a look at the KarafDistributionOption documentation](https://ops4j1.jira.com/wiki/display/PAXEXAM3/Karaf+Test+Container+Reference) or the [CoreOptions](https://ops4j1.jira.com/wiki/display/PAXEXAM3/Configuration+Options) that detail all of the available options.

This part is fairly straight forward. Here's an example of a [simple test that's built on top of that configuration](https://github.com/christian-posta/rider-auto-osgi/blob/master/itests/src/test/java/org/jboss/fuse/example/itests/BootstrapIT.java):

<script src="https://gist.github.com/christian-posta/87f0354a9950a02935c5.js"></script>

This test actually gets injected into the container (see the pax exam docs for more on that) and can access the internals of the container (eg, dependency injection) and run some asserts based on the internals of your deployment.

## black box testing
Being able to run your automated integration tests in such a way that gives complete access to your deployment and to the container runtime is great. You can do sophisticated tests to make sure everything deployed correctly, that configuration was applied the way you thought, and that you can retrieve all of the services you expect. But another type of test is very useful: being able to deploy your integration services and remotely (outside the container) exercise the functionality without knowing much about the details. So for example, interacting with the interfaces exposed by the integration service like JMS, the file system, REST/SOAP endpoints, etc. You can use standard libraries for accessing these interfaces. But how do you expose the Fuse container as a black box for this type of testing? The answer is [Pax Exam allows you to run your container in "server" mode](https://ops4j1.jira.com/wiki/display/PAXEXAM3/Server+Mode). The unfortunate part is that it's exposed as an API that you can use to orchestrate a "server" mode container. But a better way, if you're a maven user, is to attach to the _integration-test_ lifecycle and let maven boot up and tear down the server. 

Luckily, the Pax Exam [project also includes a maven plugin that plugs into the maven lifecycle integration testing phases](https://ops4j1.jira.com/wiki/display/PAXEXAM3/Exam+Maven+Plugin)

For example, [include this in  your pom.xml](https://github.com/christian-posta/rider-auto-osgi/blob/master/itests/pom.xml):

<script src="https://gist.github.com/christian-posta/dc10125904e6cc79b061.js"></script>

Please [take a look at the entire pom.xml](https://github.com/christian-posta/rider-auto-osgi/blob/master/itests/pom.xml) which shows how you can break things up into maven profiles and attach to the [Maven failsafe plugin](https://maven.apache.org/surefire/maven-failsafe-plugin/) for integration testing.

## supporting services
So far, Pax Exam is doing a lot of heavy lifting for running our automated integration tests with JBoss Fuse. However, what if we want to attach additional services to the bootstrap of the container? Maybe we want to initiate an instance of [ActiveMQ](http://activemq.apache.org) before the container comes up (since maybe we have services that will need to attach to an external ActiveMQ... and we can then use the results of messages in the queues/DLQs to assert behavior, etc), and make sure to tear it down at the end of a test. You can [extend one of the different Pax Exam reactors] to do just that:

<script src="https://gist.github.com/christian-posta/e7bae6b68b950f7df235.js"></script>

And then in your test, when you specify a reactor strategy to use, use our custom one:


<script src="https://gist.github.com/christian-posta/e043b01e74b6eed2ea1c.js"></script>


## fuse fabric
This post covers writing integration tests against stand alone versions of Fuse. A lot of the same mechanics will be used to create integration tests against a Fuse Fabric/Fabric8 deployment as well. That will be coming in Part 2 of this post. Stay tuned! Also follow me on twitter @christianposta for tweets about Fuse/Fabric8/Microservices/DevOps, etc and updates on new blog posts!


[fuse]: http://www.jboss.org/products/fuse/overview/
[camel]: http://camel.apache.org
[builtin]: http://camel.apache.org/testing.html
[arq]: http://arquillian.org
[arq-osgi]: http://arquillian.org/modules/arquillian-osgi-karaf-embedded-container-adapter/
[paxexam]: https://ops4j1.jira.com/wiki/display/PAXEXAM3/Pax+Exam
[rider]: https://github.com/christian-posta/rider-auto-osgi
[davsclaus]: http://www.davsclaus.com
[janstey]: http://janstey.blogspot.com
[cia]: http://www.manning.com/ibsen/