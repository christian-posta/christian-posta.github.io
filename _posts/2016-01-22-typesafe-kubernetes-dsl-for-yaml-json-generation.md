---
layout: post
title: "Typesafe Kubernetes-manifest DSL for JVM-based apps"
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2016-01-22T06:01:29-07:00
---

Managing a cluster of Docker/Rocket containers (or anything) in a production environment is rife with distributed-systems challenges. Luckily, a compelling and very vibrant community around the [Kubernetes](http://kubernetes.io) project is working on those challenges, using years of experience at Google, Red Hat, and startups to guide the way for others. If you haven't tried [Kubernetes](http://kubernetes.io) for managing your Docker containers, you should get on it!
 

In the [Fabric8](http://fabric8.io) community, we're working on developer experience around and on top of the Kubernetes and enterprise Kubernetes/OpenShift platforms. We've got an awesome [web console](http://fabric8.io/guide/console.html) for managing a Kubernetes cluster, sets of [libraries](http://fabric8.io/guide/javaLibraries.html) for interacting with the cluster including a [kubernetes-client](https://github.com/fabric8io/kubernetes-client) with a type-safe DSL, [out of the box one-click CI/CD](http://fabric8.io/guide/cdelivery.html) support with [Jenkins Workflow](https://wiki.jenkins-ci.org/display/JENKINS/Workflow+Plugin), [Helm.sh](http://helm.sh) packaging of apps, API Management, Chaos monkey, and many other goodies. Check the [fabric8.io](http://fabric8.io) website for more. Fabric8 may appear to have a JVM slant from a high level, but it's not Java-specific and can be applied to golang/node/python/any Language. Please feel free to hop in and contribute!


One challenge I've run into working with customers that adopt Kubernetes/OpenShift is that there isn't any good tooling at the moment around generating the Kubernetes JSON/YAML manifest files or customizing existing manifest files. JSON (and even YAML) are very error prone for hand-editing adventures, so we need something better.

If you're a Java/JVM developer, you're in luck. The fabric8 community has an awesome [typesafe DSL for automatically generating the Kubernetes manifest files](http://fabric8.io/guide/annotationProcessors.html).

Here's an example of what the fluent API builder looks like:

{% highlight java %}
	
@KubernetesProvider
public KubernetesList create() {
  return new KubernetesListBuilder()
    .addNewReplicationControllerItem()
      .withNewMetadata()
        .withName("Hello-Controller")
      .endMetadata()
      .withNewSpec()
        .withReplicas(1)
        .addToSelector("component", "my-component")
        .withNewTemplate()
          .withNewSpec()
            .addNewContainer()
              .withName("my-container")
              .withImage("my/image")
            .endContainer()
          .endSpec()
        .endTemplate()
      .endSpec()
    .endReplicationControllerItem()
    .build();
	
{% endhighlight %}
 
In this blog, we'll explore its power -- and how coupled with the fabric8 maven plugin -- makes managing and interacting with the Kubernetes API via Kubernetes manifest files much nicer. The intent is to be hands-on, so feel free to follow along, or if you're in a hurry to see examples, find the [sample github repo](https://github.com/christian-posta/typesafe-kubernetes-dsl)

## Create a new project

Fabric8 [has a nunch of quickstarts and mvn archetypes](http://fabric8.io/guide/quickstarts/index.html) to get you started. We'll start by creating a project from a maven project from which we can demostrate the kubernetes typesafe dsl:

> mvn archetype:generate -DarchetypeGroupId=io.fabric8.archetypes -DarchetypeArtifactId=vertx-simplest-archetype -DarchetypeVersion=2.2.93  

Follow the interactive prompt to fill in groupId/artifactId, etc. Then make sure the project can build with a `mvn clean install`

After you've done a mvn build, you should see in the `target/classes` directory that a `kubernetes.json` and `kubernetes.yml` file have been generated. Take a look at the kubernetes.json file:
 
{% highlight json %}
 
  {
    "apiVersion" : "v1",
    "items" : [ {
      "apiVersion" : "v1",
      "kind" : "Service",
      "metadata" : {
        "annotations" : { },
        "labels" : {
          "container" : "java",
          "component" : "typesafe-kubernetes-dsl",
          "provider" : "fabric8",
          "project" : "typesafe-kubernetes-dsl",
          "version" : "1.0-SNAPSHOT",
          "group" : "quickstarts"
        },
        "name" : "typesafe-kubernetes-dsl"
      },
      "spec" : {
        "deprecatedPublicIPs" : [ ],
        "externalIPs" : [ ],
        "ports" : [ {
          "port" : 80,
          "protocol" : "TCP",
          "targetPort" : 8080
        } ],
        "selector" : {
          "container" : "java",
          "project" : "typesafe-kubernetes-dsl",
          "component" : "typesafe-kubernetes-dsl",
          "provider" : "fabric8",
          "group" : "quickstarts"
        },
        "type" : "LoadBalancer"
      }
    }, {
      "apiVersion" : "v1",
      "kind" : "ReplicationController",
      "metadata" : {
        "annotations" : { },
        "labels" : {
          "container" : "java",
          "component" : "typesafe-kubernetes-dsl",
          "provider" : "fabric8",
          "project" : "typesafe-kubernetes-dsl",
          "version" : "1.0-SNAPSHOT",
          "group" : "quickstarts"
        },
        "name" : "typesafe-kubernetes-dsl"
      },
      "spec" : {
        "replicas" : 1,
        "selector" : {
          "container" : "java",
          "component" : "typesafe-kubernetes-dsl",
          "provider" : "fabric8",
          "project" : "typesafe-kubernetes-dsl",
          "version" : "1.0-SNAPSHOT",
          "group" : "quickstarts"
        },
        "template" : {
          "metadata" : {
            "annotations" : { },
            "labels" : {
              "container" : "java",
              "component" : "typesafe-kubernetes-dsl",
              "provider" : "fabric8",
              "project" : "typesafe-kubernetes-dsl",
              "version" : "1.0-SNAPSHOT",
              "group" : "quickstarts"
            }
          },
          "spec" : {
            "containers" : [ {
              "args" : [ ],
              "command" : [ ],
              "env" : [ {
                "name" : "KUBERNETES_NAMESPACE",
                "valueFrom" : {
                  "fieldRef" : {
                    "fieldPath" : "metadata.namespace"
                  }
                }
              } ],
              "image" : "fabric8/typesafe-kubernetes-dsl:1.0-SNAPSHOT",
              "name" : "typesafe-kubernetes-dsl",
              "ports" : [ ],
              "securityContext" : { },
              "volumeMounts" : [ ]
            } ],
            "imagePullSecrets" : [ ],
            "nodeSelector" : { },
            "volumes" : [ ]
          }
        }
      }
    } ],
    "kind" : "List"
  }
  
{% endhighlight %}
  
  
How did this come to be?

## fabric8-maven-plugin

The first option for a type-safe, json-less declaration of your Kubernetes objects is using configuration for the
[fabric8-maven-plugin](http://fabric8.io/guide/mavenFabric8Json.html) via mvn properties. If you look at the `<properties/>`
section of the maven pom.xml, you'll see some configuration that the fabric8-maven-plugin uses to help auto-generate
the kubernetes.json:

      <!-- Docker & Fabric8 Configs -->
      <docker.from>fabric8/java-jboss-openjdk8-jdk:1.0.10</docker.from>
      <fabric8.dockerUser>fabric8/</fabric8.dockerUser>
      <docker.image>${fabric8.dockerUser}${project.artifactId}:${project.version}</docker.image>
  
      <fabric8.label.component>${project.artifactId}</fabric8.label.component>
      <fabric8.label.container>java</fabric8.label.container>
      <fabric8.label.group>quickstarts</fabric8.label.group>
      <fabric8.iconRef>vertx</fabric8.iconRef>
  
  
      <fabric8.service.name>${project.artifactId}</fabric8.service.name>
      <fabric8.service.port>80</fabric8.service.port>
      <fabric8.service.containerPort>8080</fabric8.service.containerPort>
      <fabric8.service.type>LoadBalancer</fabric8.service.type>
      
Yay! Simple properties to fill in to get our kubernetes manfiest, and it (and all values) are part of the manfiest!
You can also specify enviornment variables and OpenShift template properties to the maven plugin via properties. 
[Take a look at the docs](http://fabric8.io/guide/mavenFabric8Json.html) for more about that and the specific properties
you can use to configure the generation of the manifest files.


You may notice, however, that only the most commonly used constructs (services, replication controller, ... and 
service accounts) have useful properties within the maven plugin. This should get us about 80% there. But what if 
we want to add/customze the kubernetes.json file that's generated as part of this mvn plugin? Or what if we have our own 
kubernetes.json file we hand-crafted but want type-safe editing? Or what if we just want to generate it 100% from 
scratch using a typesafe manner?

## Type-safe DSL

We can do that with the `kubernetes-generator` implementation from fabric8.io which is basically a Java annotation
processor factory that we use to generate/augment the kubernetes.json/yml files. (Note, for the yml generation and
specify explicit filenames, you'll need to use fabric8 version 2.2.89 or higher, otherwise the assumption of json and
the filename of kubernetes.json are enforced).
 
Add the following to your maven `pom.xml`

{% highlight xml %}
  <dependency>
    <groupId>io.fabric8</groupId>
    <artifactId>kubernetes-generator</artifactId>
  </dependency>
{% endhighlight %}  
  
For this example, let's say we want to add Persistent Volume details to our Kubernetes.json/yml files. The key to this
is simple create a POJO and annotate it with `@KubernetesModelProcessor` like this:

{% highlight java %}

@KubernetesModelProcessor
public class PersistentVolumeKubernetesModelProcessor {
    
}

{% endhighlight %}


Now in that new class, we can modify or add new components to the kubernetes.json/yml files. We do this by following
the "visitor" pattern. Think if it as we loop through the objects in the Kubernetes manfiest file and offer them 
to your methods for you to operate on as desired. Actually, although that's what happens in the background, you're
not forged to deal with every object in the Kubernetes manifest if you don't want; you just work on/extend/augment the
objects you're interested. You do this by specifying the parameters of your methods to take certain types of objects
(ie, the objects your interested in). For example, if your List of resources has a ReplicationController and you want
 to add more Pods to its template spec, you would declare your method like this:
 
{% highlight java %}
 
  public void on(ReplicationControllerSpecBuilder builder) {
          
  }

{% endhighlight %}

Note the parameter type. In this way, we can pick out only specific parts of the model we want to operate on.
Similarly if you only wanted to PodSpec:

{% highlight java %}
 
  public void on(PodSpecBuilder builder) {

  }

{% endhighlight %}

Some useful builder objects:

* KubernetesListBuilder
* ReplicationControllerBuilder
* ReplicationControllerSpecBuilder
* PodSpecBuilder
* ServiceSpecBuilder
* IngressRuleBuilder
* PersistentVolumeBuilder
* DaemonSetBuilder

Some useful builder objects for OpenShift:

* TemplateBuilder
* RouteBuilder
* OAuthAccessTaskBuilder
* OAuthClientBuilder
* ProjectBuilder
* DeploymentStrategyBuilder

In our sample project, we'll use the following implementation to add a set of persistent volumes, claims, and mounts
to our exiting kubernetes manifest resource:

{% highlight java %}
 
  public void on(KubernetesListBuilder builder){
        builder.addNewPersistentVolumeClaimItem()
                .withNewMetadata()
                  .withName("typesafe-dsl-pv")
                  .addToLabels("provider", "fabric8")
                  .addToLabels("project", "typesafe-dsl")
                  .addToLabels("group", "demo")
                .endMetadata()
                .withNewSpec()
                  .withAccessModes("ReadWriteOnce")
                  .withResources(getResourceRequirement())
                .endSpec()
                .endPersistentVolumeClaimItem()
                .build();
  }
{% endhighlight %}


Take a note how the fluent DSL is chained together using a sentence-structure (domain specific language). In the
above snippe we "visit the KubernetesListBuilder and add a new PersistentVolumeClaim object and specify labels,
access modes, and resources (see the full source code for how we compute the resource).

Now we need to add volume/volume mount configs to our kubernetes manifest. For existing resources, we'll edit the
existing resource descriptions like this (and we'll also pick out a specific ContainerBuilder by name!)

{% highlight java %}
 
    public void withPodTemplate(PodTemplateSpecBuilder builder) {
        builder.withSpec(builder.getSpec())
                .editSpec()
                  .addNewVolume()
                    .withName("typesafe-kubernetes-dsl-volume")
                    .withPersistentVolumeClaim(getPersistentVolumeClaimSource())
                   .endVolume()
               .endSpec()
               .build();
    }

    private PersistentVolumeClaimVolumeSource getPersistentVolumeClaimSource() {
        PersistentVolumeClaimVolumeSource rc = new PersistentVolumeClaimVolumeSource("typesafe-kubernetes-dsl-pvc", false);
        return rc;
    }

    @Named("typesafe-kubernetes-dsl")
    public void withVolumeMounts(ContainerBuilder builder) {
        builder.withVolumeMounts(new VolumeMount("/deployments/target/placeorder", "typesafe-kubernetes-dsl-volume", false))
                .build();
    }
    }

{% endhighlight %}


Now when you do a mvn clean install, you should see the kubernetes.json/yml has been correctly modified with the additions
of the Persistent Volume, volume mounts etc. Pretty slick DSL, yah?


## Generate Kubernetes DSL from scratch

You can also use this typesafe DSL to generate a kubernetes JSON/YML. This would be useful if you don't want to use the mvn
plugins (ie you're using gradle, sbt, or something). To do this, we annotate *methods* with `@KubernetesProvider` and
use the same builder objects as before. For example, in our above project we created the persistent volume claims and 
added them to our kubernetes manifest files. Users would be able to apply those to their projects, but users usually don't
administer the backing PersistentVolumes, that's something an build/release or cluster/prject admin might do. So it 
could make sense to separate out the PersistentVolume metadata into its own manifest file and deliver it separately.


{% highlight java %}
    @KubernetesProvider("typesafe-kubernetes-dsl-pv.yml")
    public KubernetesList buildList() {
        return new KubernetesListBuilder().addNewPersistentVolumeItem()
                .withNewMetadata()
                    .withName("typesafe-kubernetes-dsl-pv")
                    .addToLabels("provider", "fabric8")
                    .addToLabels("project", "typesafe-kubernetes-dsl")
                    .addToLabels("group", "demo")
                .endMetadata()
                .withNewSpec()
                    .addToCapacity("storage", new Quantity("100Ki"))
                    .addToAccessModes("ReadWriteOnce")
                    .withHostPath(new HostPathVolumeSource("/home/vagrant/camel"))
                .endSpec()
                .endPersistentVolumeItem()
                .build();
    }
{% endhighlight %}

Now when you run a maven build, you should see the kubernetes.json/yaml as well as a typesafe-kubernetes-dsl-pv.yml
which would have our YAML file for the PersistentVolume.


Please checkout the [Fabric8 typesafe DSL annotation processing](http://fabric8.io/guide/annotationProcessors.html) and the [sample project to go along with this blog post](https://github.com/christian-posta/typesafe-kubernetes-dsl). Would love to have your feedback @fabric8io or @christianposta
