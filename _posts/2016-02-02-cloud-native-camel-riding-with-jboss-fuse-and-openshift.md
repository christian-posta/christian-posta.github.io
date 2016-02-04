---
layout: post
title: "Cloud Native Camel riding With JBoss Fuse and OpenShift"
modified:
categories: 
comments: true
tags: [apache, camel, activemq, microservices, docker, kubernetes, openshift, cloud]
image:
  feature:
date: 2016-02-02T08:52:57-07:00
---

Red Hat [recently released a Microservices integration toolkit](https://www.openshift.com/enterprise/middleware-services.html) for running our microservices in a Docker and Kubernetes environment on [OpenShift v3][openshift]. To help people understand this a little bit better, I've migrated the [Rider Auto application](https://github.com/RedHatWorkshops/rider-auto-osgi), which has been around for a while for demoing Apache Camel and JBoss Fuse, into a set of microservices that you can run on OpenShift/Kubernetes via Docker containers. This blog details some background on that and points to specific examples of "how-to" for a mostly non-trivial app. I'll also do a set of videos demonstrating this so follow this blog ([http://blog.christianposta.com][blog]) for updates or follow me on twitter [@christianposta][twitter-ceposta].

![openshift](/images/ose.png)

## What is Fuse Integration Services (FIS) for OpenShift?

FIS is a set of developer tools and Docker images from the [fabric8.io][fabric8] upstream community for packaging and deploying our applications that fit a model following a microservices architecture *and* opinionated best practices around application deployment, versioning, and lifecycle management. FIS is a Red Hat supported option for Fuse on OpenShift.

![openshift](/images/fabric8-logo.png)

The two main ways of deploying Fuse Integration Services is via the Karaf, OSGI-based approach that Fuse has traditionally used, as well as a simpler, flat-class loader option that boots Camel from a plain old java main. Both options are packaged and shipped as Docker containers. Both are good options depending on what you're doing, so let's take a look.

### Camel Boot
[Camel Boot][camel-boot] is a JVM bootstrap option that allows us to package our application using the same classpath that our maven project uses and boot our Apache Camel integrations using a Plain Old Java Main. This approach has a number of advantages that simplify building, assembling, distributing, and running our microservices. Foremost, we don't have to guess what our application behavior is based on hierarchies or graphs of complicated classloaders and whether we've included the correct metadata and dependencies so that  classes may or may not resolve/collide/override/dynamically load/etc. We can simplify the model by just using a single, flat classloader to make it easier to reason about apps not only in Dev but throughout the application lifecycle (eg, in IST, UAT, PM, PROD, etc,etc). 


![openshift](/images/camel-boot.png)

Since this option is *not* meant to be deployed in any app-server (Java EE app server, Servlet container, OSGI container, etc), we will rely on our app to provide "just enough" functionality that you'd otherwise expect in a app-server -- stuff like HTTP, JMS, persistence, etc. So you can embed a Jetty or Undertow server inside our app to get HTTP services for REST or SOAP endpoints and can embed JMS clients like Spring-JMS and ActiveMQ libs to get messaging clients. This also makes it easier to unit test our app since all of those dependencies are included as part of the app and can be started, stopped, redeployed, etc independent of any app server.

I would suggest this [Camel Boot][camel-boot] option for most use cases where you've decomposed and modularized your applications and need to run, tune, scale, and reason about them individually. However, there are cases where co-locating services together is necessary and so-long as the application classpath isn't getting too complicated (ie conflicting dependencies), Camel Boot should be a good option. If you're microservice is getting complicated because of cohesive, co-located services, consider the next option with Apache Karaf that allows you to finely control the classloader behavior and isolate modules and APIs within a single app/JVM process. 


### "immutable" Apache Karaf

Fuse Integration Services also offers an option for deploying to Apache Karaf based JVMs, although the model is slightly different because we follow the Docker model of "immutable" deployments. It can get quite difficult to reason about the state of a JVM after hot-deploying/re-deploying applications into/out of a running JVM. In fact, you can [experience nasty, difficult to identify JVM leaks][leaks] as a result of this "dynamic" mutability of the JVM at runtime (especially a bad idea in production). The model encouraged by FIS is one of "shoot the old one and replace it" with a new version (and rely on the cluster manager to orchestrate this for you via [rolling upgrades or blue-green deloyments][rolling-upgrades], etc)

What does this mean for Apache Karaf for FIS? Dynamic loading and unloading of bundles or altering configuration values at runtime to mutate application state is discouraged. Instead we encourage predictable startup ordering, understood configuration values, and pre-baked applications into the JVM. If things need to change, then you go through the application delivery pipeline to change/build/test/deploy a new version (via your CI/CD process ideally) just like you would for the above Camel-Boot option as well. So for Karaf for FIS, your app and all its dependencies get packaged, installed, resolved, and built at build-time into a [Karaf assembly][karaf-assembly] which is a custom distribution of Karaf with your app baked into it. No more guessing about OSGI metadata and class resolution at deploy time; it's all pre-calculated and fails-fast at build time if things don't resolve. You can be much more confident in your OSGI app if things build successfully. 

Although the Camel Boot option is recommended for most use cases, for existing JBoss Fuse deployments outside of OpenShift/Kubernetes/Docker this Karaf-based option may be your best option for migrating existing Fuse workloads to this model (and take advantage of CI/CD, service discovery, cluster management, etc -- already built into OpenShift). Also if you're co-locating many services that end up polluting a flat-classpath the immutable Karaf option is great for providing more granular classpath isolation and API/modularity modeling.


## Deploying to Kubernetes/OpenShift

To deploy to OpenShift, we need to do the following:

* Package our JVM (either camel-boot or immutable karaf)
* Build our Docker containers
* Generate and apply our OpenShift/Kubernetes config


### Packaging Camel Boot apps
 
To package our Camel Boot apps, all we need to do is include a maven `<build/>` plugin that handles all of it for us.
 
 
{% highlight xml %}
<plugin>
  <groupId>io.fabric8</groupId>
  <artifactId>hawt-app-maven-plugin</artifactId>
  <version>${fabric8.version}</version>
  <executions>
    <execution>
      <id>hawt-app</id>
      <goals>
        <goal>build</goal>
      </goals>
      <configuration>
        <javaMainClass>org.apache.camel.spring.Main</javaMainClass>
      </configuration>
    </execution>
  </executions>
</plugin>
{% endhighlight %}

 
 
In the above configuration for the `hawt-app-maven-plugin` we can see that we just specify a plain old Java Main which will boot camel into the dependency injection context or your choice (Spring, CDI, etc) and discover all of your Spring/CDI resources as well as discover and start your Camel routes. The different types of Main.java files you can use are:
 
* `org.apache.camel.spring.Main` - discover your Spring context files (default location META-INF/spring/*.xml
* `org.apache.camel.cdi.Main`  - Loads the CDI container and the Camel route beans
* `org.apache.camel.main.Main` - no dependency injection container; default SimpleRegistry implementation
* `org.apache.camel.spring.javaconfig.Main` - Spring config using java config 
* `org.apache.camel.guice.Main` - Guice dependency injection container

It is probably worth adding the `exec-maven-plugin` to your `pom.xml` as well so you can experiment and try out the bootstrapping via Java Main's above:

{% highlight xml %}
<plugin>
  <groupId>org.codehaus.mojo</groupId>
  <artifactId>exec-maven-plugin</artifactId>
  <version>1.4.0</version>
  <configuration>
    <mainClass>org.apache.camel.spring.Main</mainClass>
  </configuration>
</plugin>
{% endhighlight %}

Then if you type `mvn exec:java` you will get the same behavior as an app that's packaged with `hawt-app-maven-plugin` which preserves the ordering and behavior of the Maven class path for our standalone Camel Boot microservice.


When you do a maven build you should see your app packaged up with it's Maven dependencies in a zip/tar.gz file. If you unpack that file, there's a `bin/run.sh` file that can be used to boot up your camel microservice.


To conver this into a Docker image, add the following `docker-maven-plugin` to your `pom.xml`


{% highlight xml %}
<plugin>
  <groupId>org.jolokia</groupId>
  <artifactId>docker-maven-plugin</artifactId>
  <version>${docker.maven.plugin.version}</version>
  <configuration>
    <images>
      <image>
        <name>our-company/app-name:1.0</name>
        <build>
          <from>jboss-fuse-6/fis-java-openshift:1.0</from>
          <assembly>
            <basedir>/deployments</basedir>
            <descriptorRef>hawt-app</descriptorRef>
          </assembly>
          <env>
            <JAVA_LIB_DIR>/deployments/lib</JAVA_LIB_DIR>
            <JAVA_MAIN_CLASS>org.apache.camel.spring.Main</JAVA_MAIN_CLASS>
          </env>
        </build>
      </image>
    </images>
  </configuration>
</plugin>
{% endhighlight %}


For more detailed instructions for setting this up and running it, please see the [Rider Auto OpenShift documentation][rider-auto-docs]


### Packaging immutable Karaf apps

If you're doing Karaf-based microservices, we will follow an analogous path as for Camel Boot. We'll package our Karaf app into an immutable Karaf assembly with the `karaf-maven-plugin` by adding the plugin to our maven build:

{% highlight xml %}
<plugin>
  <groupId>org.apache.karaf.tooling</groupId>
  <artifactId>karaf-maven-plugin</artifactId>
  <version>${karaf.plugin.version}</version>
  <extensions>true</extensions>
  <executions>
    <execution>
      <id>karaf-assembly</id>
      <goals>
        <goal>assembly</goal>
      </goals>
      <phase>install</phase>
    </execution>
    <execution>
      <id>karaf-archive</id>
      <goals>
        <goal>archive</goal>
      </goals>
      <phase>install</phase>
    </execution>
  </executions>
  <configuration>
    <karafVersion>v24</karafVersion>
    <javase>1.8</javase>
    <useReferenceUrls>true</useReferenceUrls>
    <!-- do not include build output directory -->
    <includeBuildOutputDirectory>false</includeBuildOutputDirectory>
    <!-- no startupFeatures -->
    <startupFeatures>
      <feature>karaf-framework</feature>
      <feature>shell</feature>
      <feature>jaas</feature>
      <feature>spring</feature>
      <feature>camel-spring</feature>
      <feature>camel-jaxb</feature>
      <feature>camel-cxf</feature>
      <feature>camel-bindy</feature>
      <feature>cxf-http-jetty</feature>
      <feature>activemq-client</feature>
      <feature>activemq-camel</feature>
    </startupFeatures>
    <startupBundles>
      <!--  this needs to be here for spring-dm to resolve properly!!-->
      <bundle>mvn:org.apache.karaf.bundle/org.apache.karaf.bundle.core/3.0.4</bundle>
      <bundle>mvn:io.fabric8.mq/mq-client/2.2.0.redhat-079</bundle>
      <bundle>mvn:io.fabric8/fabric8-utils/2.2.0.redhat-079</bundle>
      <bundle>mvn:${project.groupId}/${project.artifactId}/${project.version}</bundle>
    </startupBundles>
  </configuration>
</plugin>
{% endhighlight %}

Note, the example above builds a full distro of Karaf with our microservice modules/APIs and all dependencies baked into the distro. You can see in the config that we can control exactly what features, bundles, JRE, etc that we want pre-baked into the distro. 

The `docker-maven-plugin` should also be used to build the Docker image for this module. Again, check  the [Rider Auto OpenShift documentation][rider-auto-docs] for a full-blown, running example.


### Generate OpenShift/Kubernetes component manifest

At the moment, FIS has a couple options for generating the OpenShift/Kubernetes manifest files (json/yaml -- though at the moment only the JSON option is supported. In the [upstream community][fabric8] we support the yaml option too). To generate the Replication Controllers/Pods/Services we need to add the [fabric8-maven-plugin][fabric8-maven] and a few maven `<properties/>`:

{% highlight xml %}
<plugin>
  <groupId>io.fabric8</groupId>
  <artifactId>fabric8-maven-plugin</artifactId>
  <version>${fabric8.version}</version>
  <executions>
    <execution>
      <id>json</id>
      <phase>generate-resources</phase>
      <goals>
        <goal>json</goal>
      </goals>
    </execution>
    <execution>
      <id>attach</id>
      <phase>package</phase>
      <goals>
        <goal>attach</goal>
      </goals>
    </execution>
  </executions>
</plugin>
{% endhighlight %}

{% highlight xml %}
        <fabric8.service.name>${project.artifactId}</fabric8.service.name>
        <fabric8.service.headless>true</fabric8.service.headless>

        <fabric8.metrics.scrape>true</fabric8.metrics.scrape>
        <fabric8.metrics.port>9779</fabric8.metrics.port>
        <docker.port.container.soap>8183</docker.port.container.soap>

        <fabric8.service.name>${project.artifactId}</fabric8.service.name>
        <fabric8.service.port>80</fabric8.service.port>
        <fabric8.service.containerPort>8183</fabric8.service.containerPort>
{% endhighlight %}


With these pom.xml entries, we can do `mvn fabric8:json` and generate the kubernetes.json file to `target/classes/kubernetes.json`

We can also generate more advanced Kubernetes manifest objects like PersistentVolumes, Secrets, multiple services, etc using a type-safe DSL for augmenting or generating the kubernetes.json file. See the [rider-auto-file][rider-auto-file] module for some examples and explanations of that.


## Features Demonstrated in the Rider Auto microservices repo

Please take a look at the [Rider Auto][rider-auto-docs] project to see more detail about these features:

* Generating the kubrenetes.json file with the fabric8 maven plugin
* Adding PersistentVolumes to the kubernetes.json file with a type-safe DSL
* Building Camel Boot apps
* Building immutable Karaf apps
* Discovering JBoss AMQ in a kubernetes environment
* Building Docker images for Camel Boot and immutable Karaf
* Deploying apps to OpenShift
* How to merge multiple kubernets.json files into a single kubernetes.json file for "all in one" deployment
* Connecting to local/remote docker daemon/openshift installations
* Exposing SOAP and REST HTTP services via Kubernetes Services
* Using Spring inside Karaf
* Integration testing on Kubernetes with fabric8-arquillian


[camel-boot]: http://camel.apache.org/camel-boot.html
[leaks]: http://blog.christianposta.com/immutable/immutable-infrastructure-and-the-jvm-part-i/
[rolling-upgrades]: http://blog.christianposta.com/deploy/blue-green-deployments-a-b-testing-and-canary-releases/
[karaf-assembly]: https://karaf.apache.org/manual/latest/developers-guide/custom-distribution.html
[openshift]: https://www.openshift.com/enterprise/features.html
[rider-auto-docs]: https://github.com/RedHatWorkshops/rider-auto-openshift
[fabric8]: http://fabric8.io
[fabric8-maven]: http://fabric8.io/guide/mavenFabric8Json.html
[rider-auto-file]: https://github.com/RedHatWorkshops/rider-auto-openshift/tree/master/rider-auto-file
[blog]: http://blog.christianposta.com
[twitter-ceposta]: http://www.twitter.com/christianposta