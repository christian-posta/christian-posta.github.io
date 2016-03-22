---
layout: post
title: "Java Remote Debug for Applications Running in Kubernetes"
modified:
categories: [kubernetes]
comments: true
tags: [Kubernetes, debugging, docker]
image:
  feature:
date: 2016-03-22T06:09:42-07:00
---


[Kubernetes 1.2 was just released](http://blog.kubernetes.io/2016/03/Kubernetes-1.2-even-more-performance-upgrades-plus-easier-application-deployment-and-management-.html) and is quickly becooming the defacto cluster management solution for containers (Docker, Rocket, Hyper, etc). Check it out if you haven't already -- here are some interesting tidbits about the 1.2 release:

* Cluster can now scale to 30,000 containers per cluster
* Graceful shutdown of nodes, transitioning to other running nodes in the cluster
* Custom defined metrics as the basis for autoscaling
* Dynamic configuration management



![kube](/images/kube.png)


When you're developing microservices on your local laptop, you can use something like Kubernetes to run you docker containers locally and get developer/QA/production likeness in how you deploy your applications. For example, you get process isolation, port-space isolation, network/storage, etc so things don't collide on your local developer laptop. 


One thing for Java Developers that comes up is how do you view logs, do remote debug, and take stack traces.

Here are a few tips:


## Tailing logs for your pod

On some cluster management systems, you have to basically look up the local IP of your application (if running in a container), ssh into it somehow, and then find the log and tail it. With Kubernetes, you don't have to do any of that. Regardless of which machine you're running on (ie, where you run the kubernetes client), you can do the following:

#### List the pods in your cluster

{% highlight shell %}
ceposta@postamac(~) $ kubectl get pod
NAME                        READY     STATUS    RESTARTS   AGE
broker-amq-1-hjbeh          1/1       Running   1          15h
file-ingress-events-3artj   1/1       Running   1          13h
{% endhighlight %}



#### Tail the logs
Now pick the pod you want to stream the logs from and go! 

{% highlight shell %}
ceposta@postamac(~) $ kubectl logs -f file-ingress-events-3artj
{% endhighlight %}

#### Connect via Shell if you must
If you must log into the pod for some reason (poke around the file system, grok other config files, etc):

{% highlight shell %}
ceposta@postamac(~) $ kubectl exec -it file-ingress-events-3artj bash
{% endhighlight %}


## JVM Remote debug your application

This becomes really handy to see exactly what's going on in your application. To do this, you don't really do anything different from what you do today. When you bootstrap your JVM, you should have a way to enable JVM debug. For example, for the [HawtApp Maven plugin](https://github.com/fabric8io/fabric8/tree/master/hawt-app-maven-plugin) which is a simple mvn plugin that assigns a Java Main as the executable and a simple, flexible bootstrap `bin/run.sh` script (or batch file for windows) [that allows you to control classpath and debugging via environment variables](https://github.com/fabric8io/fabric8/blob/master/hawt-app-maven-plugin/src/main/resources/io/fabric8/maven/hawt/app/bin/run.sh). 

#### Bootstrap Java app to be able to expose remote debug port
Example:

{% highlight shell %}
# Set debug options if required
if [ x"${JAVA_ENABLE_DEBUG}" != x ] && [ "${JAVA_ENABLE_DEBUG}" != "false" ]; then
    java_debug_args="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=${JAVA_DEBUG_PORT:-5005}"
fi
{% endhighlight %}

#### Define debug port in docker container via kubernetes manifest
Now you need to expose port `5005` (in this example) in your Docker containers via your Kubernetes manifest (json/yaml) file:

{% highlight yaml %}

    spec:
        containers:
        - args: []
          command: []
          env:
          - name: "JAVA_ENABLE_DEBUG"
            value: "true"
          - name: "OUTGOING_FILE_PATH"
            value: "/deployments/camel/outgoing"
          - name: "INCOMING_FILE_PATH"
            value: "/deployments/camel/incoming"
          - name: "KUBERNETES_NAMESPACE"
            valueFrom:
              fieldRef:
                fieldPath: "metadata.namespace"
          image: "fabric8/file-ingress-events:1.0-SNAPSHOT"
          name: "file-ingress-events"
          ports:
          - containerPort: 5005
            name: "jvm-debug"
          - containerPort: 8778
            name: "jolokia"
{% endhighlight %}

Note, we've also added an env variable in the kubernetes manifest file to be able to control whether we want remote debugging on or off (true/false). The bootstrap scripts (above) will check that env variable and you can control it via the kube manifest (now with [ConfigMap](http://kubernetes.io/docs/user-guide/configmap/) in Kube 1.2, or [OpenShift templates](https://docs.openshift.org/latest/dev_guide/templates.html)).

The last step is to proxy the debug port to your local machine. If you run the `kubectl` client locally, this is easy:

#### List the pods in your cluster

{% highlight shell %}
ceposta@postamac(~) $ kubectl get pod
NAME                        READY     STATUS    RESTARTS   AGE
broker-amq-1-hjbeh          1/1       Running   1          15h
file-ingress-events-3artj   1/1       Running   1          13h
{% endhighlight %}

#### Proxy the pod to a specific port

{% highlight shell %}
ceposta@postamac(~) $ kubectl port-forward file-ingress-events-3artj  5005:5005
{% endhighlight %}

The above will port-forward from your local environment (5005) to the pod's port 5005. Now you can just attach your remote debugger to `localhost:5005`.


Hope this helps you debug your Java apps!