---
layout: post
title: "Logging Into a Kubernetes Cluster With Kubectl"
modified:
categories: kubernetes
comments: true
tags: [docker, kubernetes, how-to, openshift, containers, cloud, PaaS, CaaS]
image:
  feature:
date: 2015-10-29T16:27:56-07:00
---

The `kubectl` command line client is a versatile way to interact with a [Kubernetes](http://kubernetes.io) cluster, including managing multiple clusters. I've not found a good way to login to multiple Kubernetes clusters (well, actually I have: using the [OpenShift oc command-line client, which has a login command](https://docs.openshift.com/enterprise/3.0/cli_reference/get_started_cli.html#basic-setup-and-login) which basically automates all of the below) out of the box, so here's a quick intro to the `kubectl` command-line `config` commands that let us configure our different cluster credentials, users, and namespaces to quickly switch between clusters or namespaces within a cluster:
 
![kube](/images/kube.png)

The [kubernetes docs on the subject](http://kubernetes.io/v1.0/docs/user-guide/kubeconfig-file.html) cover most of this, but I'm hoping to add a little more detail.

Basically, `kubectl` doesn't have a 'login' command. So we need to use the `kubectl` cli to manipulate the configuration file that `kubectl` uses. You could theoretically edit this by hand as well, but the tool will keep things formatted properly, and disallow characters and names that cannot be used. Nevertheless, it helps to have a convention to follow when adding to this file which we'll cover here.

First, if you run the following, you'll see an example kube-config file (~/.kube/config)

{% highlight css %}
kubectl config view
{% endhighlight %}

To add a new cluster, we need to add a user/principal that will be used when connecting to the cluster. To do this, we run `set-credentials` command:

{% highlight css %}
kubectl config set-credentials kubeuser/foo.kubernetes.com --username=kubeuser --password=kubepassword
{% endhighlight %}

We name the "credential" following a specific pattern (though this is a good convention, not mandatory -- the credential name can be anything) -- we may have a many-to-many relationship between user names and clusters, so following a pattern that allows you to differentiate a `kubeuser` from one cluster and a different one is useful. So we named this credential `kubeuser/foo.kubernetes.com` where `kubeuser` is the user and `foo.kubernetes.com` is a cluster URI. 

Next we need to point to a cluster:

{% highlight css %}
kubectl config set-cluster foo.kubernetes.com --insecure-skip-tls-verify=true --server=https://foo.kubernetes.com
{% endhighlight %}

Here we've configured a URI that points to a kubernetes master and given it a name that matches what we used when we created the user credentials `foo.kubernetes.com`. If you have a [highly available master](http://kubernetes.io/v1.0/docs/admin/high-availability.html) then point to the load-balanced cluster of masters.

Now we need to create a "context." This context basically points to the cluster with a specific user. Using (and properly organizing) our different contexts, we can quickly switch across multiple clusters:

{% highlight css %}
kubectl config set-context default/foo.kubernetes.com/kubeuser --user=kubeuser/foo.kubernetes.com --namespace=default --cluster=foo.kubernetes.com
{% endhighlight %}

Note again the conventions here. We're naming our context `default/foo.kubernetes.com/kubeuser` which designates namespace/cluster-name/cluster-user.  

Now to use this specific context (of which there may be many), we can tell kubectl to use it:

{% highlight css %}
kubectl config use-context default/foo.kubernetes.com/kubeuser
{% endhighlight %}

Now all commands will be sent within this context and to this cluster that we've configured. To change the context it's as simple as `kubectl config use-context <name>` again. 


If you run the [local Kubernetes set up using Vagrant](http://kubernetes.io/v1.0/docs/getting-started-guides/vagrant.html) you'll notice that the ~/.kube/config file gets set up automatically after the clusters comes up; you'll also feel comforted that  [the scripts which provision kubernetes inside vagrant also use these commands to set up your ~/.kube/config](https://github.com/christian-posta/kubernetes/blob/master/cluster/common.sh#L49-49)