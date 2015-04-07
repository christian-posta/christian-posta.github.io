---
layout: post
title: "Fuse Fabric Profile Migration for Continuous Delivery"
modified:
categories: fabric8
comments: true
tags: [fabric8, continuous delivery, maven, jboss fuse]
image:
  feature:
date: 2015-04-07T11:50:28-07:00
---


JBoss Fuse is a powerful distributed integration platform with built in features for centralized configuration management, service discovery, versioning, API gateway, load balancing, failover, etc for your integration-focused microservice deployments. JBoss Fuse 6.x is built on top of the [Fabric8 1.x](http://fabric8.io/gitbook/index.html) opensource project.  This blog post shows how to use the powerful automation already built into Fuse to build up a migration path for you applications to achieve continuous delivery if so desired. 

> There is a sample project that this blog refers to [https://github.com/christian-posta/fuse-fabric-promotion-build](https://github.com/christian-posta/fuse-fabric-promotion-build)

## What Fabric8 brings to the automation process
Fabric8 1.x brings a simple runtime grouping and provisioning model to allow you to quickly deploy and upgrade/downgrade your applications from a central dashboard/console across a fleet of machines. For this, you don't need to have any custom scripting/ansible/chef/puppet automation as the automation comes out of the box with Fuse/Fabric8. 

The central concept is a set of text-based properties files called **profiles** that declaratively describe the end-state of a deployment -- i.e., they describe what binaries, features, configurations, dependencies, etc that need to be deployed together. Profiles are versioned (to allow for rolling upgrades) and can have hierarchy relationships to cut down on duplication of configurations.  

## The Problem
In a shared environment where you have multiple teams working on different integrations/microservices/applications that each have their own timelines, deployment cycle, or pre-existing continuous integration cycles, deploying into a shared environment can result in collisions. We have to establish a convention for how applications make it into this environment, and be able to automate it/version it. One of the tenants of Continuous Delivery is to version everything, including application configuration, environment configuration, automation scripts, etc. so that environments can be recreated on the fly if necessary and avoid highly manually tailored environments which end up becoming very brittle and risky. 
 
With Fuse/Fabric8 profiles, **everything** is versioned in the built-in configuration management backend of Fuse/Fabric8, but how can those be recreated or how can those **profiles** be deployed into Fuse when applications change? And how can we do this within the constraints of applications deploying at different rates, different versions, different cycles, etc? 
  
## The Solution
A lot of automation is built into Fabric8 and this guide will attempt to show you how to best leverage it. Once you see what can be automated you'll say "ah, so I don't need all of these other scripts/tools to do this"? Let's take a step-by-step look. The focus of this guide will be fabric8 1.x, but more specifically JBoss Fuse Fabric 6.1 or 6.2. Some of the out-of-the-box features (I'll point them out along the way) are only available in the Fuse 6.2 versions, but can still be accomplished with the Fuse 6.1 environment (although, with some scripting)

### fabric8-maven-plugin

__Fuse 6.1/6.2__

The **fabric8-maven-plugin** [comes out of the box with Fuse 6.1](https://access.redhat.com/documentation/en-US/Red_Hat_JBoss_Fuse/6.1/html/Fabric_Guide/F8Plugin.html). It plugins into your maven maven lifecycle with a few configuration lines in your project's pom.xml. It provides a single goal (next section) in Fuse 6.1 and adds additional goals in Fuse 6.2.   

### Automate creating profiles

__Fuse 6.1/6.2__

If you take a look at the example projects/modules in this repo ([the EIP module](https://github.com/christian-posta/fuse-fabric-promotion-build/tree/master/eip) or the [REST module](https://github.com/christian-posta/fuse-fabric-promotion-build/tree/master/rest)) you'll see that the pom.xml has a `<build>` section that configures the **fabric8-maven-plugin**. For example, in the REST module:

    <plugin>
        <groupId>io.fabric8</groupId>
        <artifactId>fabric8-maven-plugin</artifactId>
        <version>${fabric8.maven.plugin.version}</version>
        <configuration>
            <profile>my-rest</profile>
            <features>fabric-cxf-registry fabric-cxf cxf war swagger</features>
            <featureRepos>mvn:org.apache.cxf.karaf/apache-cxf/${version:cxf}/xml/features</featureRepos>
        </configuration>
    </plugin>
            
This will automatically create the fabric8 profiles for this project. If you run `mvn fabric8:deploy` it will install the profiles into a locally running fabric8. This is a very useful development-time goal to test that profiles get created correctly. (Note, you have to have your ~/.m2/settings.xml file set up correctly to have the un/pw for your fabric server. by default the server id it will look for is _fabric8.upload.repo_) 

### Automatically archiving your profiles

__Fuse 6.2__

    <plugin>
        <groupId>io.fabric8</groupId>
        <artifactId>fabric8-maven-plugin</artifactId>
        <version>${fabric8.maven.plugin.version}</version>
        <configuration>
            <profile>my-rest</profile>
            <features>fabric-cxf-registry fabric-cxf cxf war swagger</features>
            <featureRepos>mvn:org.apache.cxf.karaf/apache-cxf/${version:cxf}/xml/features</featureRepos>
        </configuration>
            <executions>
                <execution>
                    <id>fabric8-zip</id>
                    <phase>
                        package
                    </phase>
                    <goals>
                        <goal>zip</goal>
                    </goals>
                </execution>
            </executions>
    </plugin>


With this configuration, you will also notice that by default the `zip` goal will be attached to the `package` phase of the build. This is only available in Fuse 6.2 version of the plugin (see the versions used in this project). The `zip` goal will produce the profiles and zip them up into a single distribution that can be uploaded to a maven repository. So for example, as part of a a step in your Continuous Integration processes, you can have this `zip` created and pushed into your maven repository along with the binaries for your project. So this way you have both the binaries and the Fabric profiles deployed into on single artifact repository. For example, if you run `mvn clean install` from the root of the REST module in this project, you can see the profile zips in the __./target__ folder as well as the corresponding location under __~/.m2/repository__

### Independent versioning
In your environment you may have multiple applications and deployments. Each will have its own version number and lifecycle. Fuse also has versioning built around profiles for deploying updated applications or downgrading applications. Fuse Fabric has these two concepts for versioning of profiles:

* Version sets
* Git backed change management

When we deploy our applications, we need to line up the various independent application versions with a Fuse Fabric version set. So for example, in our project, we have the EIP project and the REST project. The EIP project is versioned with `2.0` and the REST project is versioned with `1.5`. So how do we bring in these two versions of the applications and their profiles into Fabric?

### Environment build

__Fuse 6.2__

We use a single environment build to aggregate the separate projects that will have profiles that need to be added to the Fuse Fabric registry. If you look at the environment-build project's pom.xml file you'll see something like this:

    <dependency>
        <groupId>com.redhat.demo.promotion</groupId>
        <artifactId>eip</artifactId>
        <version>2.0</version>
        <type>zip</type>
        <classifier>profile</classifier>
    </dependency>
    <dependency>
        <groupId>com.redhat.demo.promotion</groupId>
        <artifactId>rest</artifactId>
        <version>1.5</version>
        <type>zip</type>
        <classifier>profile</classifier>
    </dependency>
    
    
You can see the different profiles that make up the disparate applications are added as dependencies and they're zip files that are classified as "profile" which will be looked up in the maven repository. So if you used the `zip` goal from above, and installed the profiles into your maven repository, you can then refer to them in the environment build like above. 

The key here is that the fabric8-maven-plugin has a goal called `branch` that will do the following:

* Connect to an existing Fuse Fabric git repo and clone the existing branch into a new branch
* Grab the above zip dependencies from maven
* Unzip and merge the new profiles into the fabric git repo 
* Commit the changes
* Optionally push the new branch back up to Fabric

This requires Fuse 6.2 fabric8-maven-plugin, but works against an existing Fuse 6.1 or Fuse 6.2 installation.

The configuration for the `branch` goal looks like this:

    <plugin>
        <groupId>io.fabric8</groupId>
        <artifactId>fabric8-maven-plugin</artifactId>
        <version>${fabric8.maven.plugin.version}</version>
        <executions>
            <execution>
                <id>branch</id>
                <phase>compile</phase>
                <goals>
                    <goal>branch</goal>
                </goals>
                <configuration>
                    <!-- lets choose the name of the version in the git repository where we will create the branch -->
                    <branchName>1.0.1</branchName>
                    <gitUrl>http://admin:admin@postamac.local:8181/git/fabric</gitUrl>
                    <oldBranchName>1.0</oldBranchName>
                    <pushOnSuccess>true</pushOnSuccess>
                </configuration>
            </execution>
        </executions>
    </plugin>
            
You specify in the pom.xml (or on the command line) what the `branchName` (new branch) and whether to `pushOnSuccess`. If you point to an existing running fuse, and run:

    mvn compile
    
Fuse should automatically do the above steps and push the profiles as expected.

> NOTE:
> I've just recently committed some fixes to fabric8 to allow things to work as described as there were a few bugs previously. Please wait for next early releases of Fuse 6.2 to take advantage of these features as described here
 
For more Fabric8, JBoss Fuse, ActiveMQ, Camel, Microservices, Cloud, etc follow me on twitter [@christianposta](https://twitter.com/christianposta) or my blog [http://blog.christianposta.com](http://blog.christianposta.com)