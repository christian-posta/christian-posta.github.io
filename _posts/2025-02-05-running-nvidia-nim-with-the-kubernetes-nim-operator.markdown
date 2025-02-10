---
layout: post
title: Running NVIDIA NIM on GKE With the Kubernetes NIM Operator
modified:
categories: 
comments: true
tags: [ai, inference, kubernetes, nvidia, nim, LLM]
image:
  feature:
date: 2025-02-05T15:26:56-05:00
---

[NVIDIA NIM](https://docs.nvidia.com/nim/index.html) is a great way to run [AI inference](https://www.cloudflare.com/learning/ai/inference-vs-training/) workloads in containers. I deploy primarily to Kubernetes, so I wanted to dig into deploying NIM using the [Kubernetes NIM Operator](https://github.com/NVIDIA/k8s-nim-operator) and use [GPUs in Google Cloud](https://cloud.google.com/gpu). I actually started by going to ChatGPT and asked it to give me a step by step guide for doing this on GKE. The results it gave seemed impressive, until I started following the steps. ChatGPT is good at a lot of things, but in this case it gave me [complete and utter nonsense](https://gist.github.com/christian-posta/a3024eaabec39c754d0dc91d8bdaa946). So I thought I'd write up a guide for others who want to deploy NIM on GKE using the NIM operator with some learnings along the way.

## Deploy the GKE Cluster

The first step is to deploy the GKE cluster. I'm going to use the [Google Cloud CLI](https://cloud.google.com/sdk) to do this. I will spin up the cluster with CPU nodes first and then add the GPU nodes later. This way I can separate the management of the GPU nodes (ie, scale them down since they are expensive!)

```bash
gcloud container clusters create $CLUSTER_NAME \
    --zone $ZONE \
    --node-locations $ZONE \
    --release-channel "regular" \
    --machine-type "n1-standard-8" \
    --image-type "UBUNTU_CONTAINERD" \
    --disk-type "pd-standard" \
    --disk-size "100" \
    --no-enable-intra-node-visibility \
    --metadata disable-legacy-endpoints=true \
    --max-pods-per-node "110" \
    --num-nodes "2" \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM \
    --enable-ip-alias \
    --default-max-pods-per-node "110" \
    --no-enable-master-authorized-networks
```

Next we deploy the GPU nodes:

```bash
gcloud container node-pools create gpu-pool \
    --cluster $CLUSTER_NAME \
    --zone $ZONE \
    --node-locations $ZONE \
    --machine-type "g2-standard-16" \
    --image-type "UBUNTU_CONTAINERD" \
    --node-labels="gke-no-default-nvidia-gpu-device-plugin=true" \
    --metadata disable-legacy-endpoints=true \
    --disk-size "100" \
    --num-nodes "1" \
    --tags=nvidia-ingress-all
```

#### Things to Note

* I picked the `g2-standard-16` [machine type]((https://cloud.google.com/compute/docs/gpus)) because it has a single GPU (don't want to be too expensive for the demo I was working on), because it has 24GB GPU memory (the model i'll run is 8B parameters with float16 precision which requires about 16BG of memory). I also need a decent amount of main memory on the VM and this machine type has 64GB. The model will struggle to startup without enough memory. 
* When deploying the GPU nodes, we will pick GPU accelerators that can successfully run a LLM model. For example, a lot of guides install the [Tesla T4 GPU](https://www.nvidia.com/en-us/data-center/tesla-t4/) and this does not work well for the LLM model I wanted to use (ie, LLama 3.1 8B)
* We disable the default NVIDIA GPU drivers by setting the `gke-no-default-nvidia-gpu-device-plugin` node label. We do this because we want to manage the GPU drivers and underlying container runtime using NVIDIA GPU Operator (which we'll do next)
* For the `g2-standard-16` machine type which runs an [NVIDIA L4 GPU](https://www.nvidia.com/en-us/data-center/l4/), we can expect to spend around $600 a month on the GPU node. We could use a more powerful GPU (A100) but those are a lot more expensive (around $2200 a month)
* Check the [GPU machine types](https://cloud.google.com/compute/docs/gpus) that might be appropriate for your workloads
* Use the [GCP Price Calculator](https://cloud.google.com/products/calculator) to estimate your costs for different GPU machine types



## Deploy the NVIDIA GPU Operator

I wanted to use the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) to manage the GPU drivers and underlying container runtime. The NVIDIA GPU Operator makes it easier to configure and manage multiple software components on the nodes that support GPU workloads. I use [Helm for this deployment](https://github.com/NVIDIA/gpu-operator).

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
```

When installing the GPU Operator, prepare yourself that it may take a little while (a few minutes... if it's taking longer than 5-10 minutes, something may have gone wrong). 

For the operator to install correctly (it's going to install itself into GKE as a `system-node-critical` pod), we need to create a [ResourceQuota resource](https://cloud.google.com/kubernetes-engine/quotas). It should look similar this:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gcp-critical-pods
  namespace: gpu-operator
spec:
  hard:
    pods: 100
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
      - system-node-critical
      - system-cluster-critical

```

If we save that into a file called `gke-resourcequota.yaml`, we can apply it to the GKE cluster:

```bash
export GPU_OPERATOR_VERSION=v24.9.1

kubectl create namespace gpu-operator

kubectl apply -f ./gke-resourcequota.yaml

helm upgrade --install gpu-operator nvidia/gpu-operator --wait  \
    -n gpu-operator \
    --version=$GPU_OPERATOR_VERSION \
    -f ./nim/gpu-operator-values.yaml \
    --timeout 2m
```

As I mentioned this may take a few minutes to install.

#### Verify the installation
We should verify the device drivers were installed correctly and that the GPU nodes are correctly recognized.

Check all GPU operator pods are running

```bash
kubectl get pods -n gpu-operator
```

Debugging events

Verify GPU nodes are properly recognized
```bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"
```

Verify with nvidia-smi
```bash
POD=$(kubectl get pods -n gpu-operator -l app=nvidia-driver-daemonset -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -n gpu-operator -- nvidia-smi
```

The output should look like this:

```bash
$ kubectl exec -it $POD -n gpu-operator -- nvidia-smi
Wed Feb  5 21:13:19 2025       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.127.08             Driver Version: 550.127.08     CUDA Version: 12.4     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA L4                      On  |   00000000:00:03.0 Off |                    0 |
| N/A   73C    P0             41W /   72W |      23MiB /  23034MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
+-----------------------------------------------------------------------------------------+
```

## Install the NIM Operator

The [NIM Operator is a Kubernetes operator](https://github.com/NVIDIA/k8s-nim-operator) that manages the deployment and lifecycle of NVIDIA NIM. It's a great way to deploy NIM in a Kubernetes cluster. You can take advantage of things like automatically downloading/caching NIM models and then running them in containers and scaling them as needed. We will also use Helm for this deployment.

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
```

You'll need to create Kubernete secrets to access the NGC container registry which hosts the model catalog. In this example I create a secret for the NGC Docker API key and a secret for the NGC API key. They are slightly different. The first one is for accessing the container registry (ie, such as a docker registry). The second is a generic API key for accessing the NGC servce APIs. It was a little confusing at first, but you get to the API keys by clicking "Setup" under your profile in the top right corner of the NGC website.

![](/images/nim-operator/setup.png)

Create the keys using the the `kubectl create secret` command. Note the username for the docker-username is `$oauthtoken`.

```bash
kubectl create secret docker-registry ngc-secret \
    --docker-server=nvcr.io \
    --docker-username='$oauthtoken' \
    --docker-password="$NGC_DOCKER_API_KEY" \
    --docker-email='your.email@solo.io' 

kubectl create secret generic ngc-api-secret \
    --from-literal=NGC_API_KEY="$NGC_API_KEY" 
```

Install the operator 

Now we can install the operator. I'm using version `v1.0.1` of the operator.

```bash
export NIM_OPERATOR_VERSION=v1.0.1
helm upgrade --install nim-operator nvidia/k8s-nim-operator --wait  \
    -n nvidia-nim \
    --version=$NIM_OPERATOR_VERSION \
    --set global.registry.secretName=ngc-secret
```

Refer to the [docs](https://docs.nvidia.com/nim-operator/latest/index.html) if you have other questions about the installation options.

## Deploy a NIM Model

Now we can deploy a NIM inferencing model. I'm going to deploy the Llama 3.1 8B model. 

```yaml
apiVersion: apps.nvidia.com/v1alpha1
kind: NIMCache
metadata:
  name: meta-llama3-8b-instruct
spec:
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Exists"
      effect: "NoSchedule"
  source:
    ngc:
      modelPuller: nvcr.io/nim/meta/llama-3.1-8b-instruct:1.3.3
      pullSecret: ngc-secret
      authSecret: ngc-api-secret
      model:
        engine: tensorrt_llm
        tensorParallelism: "1"
        qosProfile: "throughput"
        profiles:
        - 193649a2eb95e821309d6023a2cabb31489d3b690a9973c7ab5d1ff58b0aa7eb
        - 7cc8597690a35aba19a3636f35e7f1c7e7dbc005fe88ce9394cad4a4adeed414
  storage:
    pvc:
      create: true
      storageClass: standard-rwo
      size: "50Gi"
      volumeAccessMode: ReadWriteOnce
  resources: {}
```

Things to Note:
* You may need to add the `tolerations` section to the NIMCache as the Operator fails to do this correctly. 
* Storage options may not suppor the "ReadWriteMany" option, so check your storage class options. I changed to use `ReadWriteOnce` to work with the default storage class and storage options that get installed on the GKE nodes I've picked
* You may need to specify "profiles" which are the GPU profiles that NVIDIA NIM supports. Which profiles should you pick? The best way is to run a test on your nodes to see. I'll show that next.

#### Choosing the right NIM model profiles

NIM [model profiles](https://docs.nvidia.com/nim/large-language-models/latest/profiles.html) configure the model engine to take advantage of specific features in the hardware and software of the machine to improve performance. You can run this simple job to determine what profiles are supported on your nodes:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: nim-profile-job
spec:
  template:
    metadata:
      name: nim-profile-pod
    spec:
      tolerations:
        - key: "nvidia.com/gpu"
          operator: "Equal"
          value: "present"
          effect: "NoSchedule"
      containers:
        - name: nim-profile
          image: nvcr.io/nim/meta/llama-3.1-8b-instruct:1.3.3
          args: ["list-model-profiles"]
          resources:
            limits:
              nvidia.com/gpu: 1  # Request 1 GPU
          env:
            - name: NIM_CACHE_PATH
              value: /tmp
            - name: NGC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: ngc-api-secret
                  key: NGC_API_KEY
      imagePullSecrets:
        - name: ngc-secret
      restartPolicy: Never
```

This Job will output something similar to this:

```bash
MODEL PROFILES
- Compatible with system and runnable:
  - 193649a2eb95e821309d6023a2cabb31489d3b690a9973c7ab5d1ff58b0aa7eb (vllm-bf16-tp1)
  - With LoRA support:
    - 3ad27031e57506f12b47d3cd74d045fe05977f0bb92e2f8c80a3240748482578 (vllm-bf16-tp1-lora)
- Compilable to TRT-LLM using just-in-time compilation of HF models to TRTLLM engines:
  - 7cc8597690a35aba19a3636f35e7f1c7e7dbc005fe88ce9394cad4a4adeed414 (tensorrt_llm-trtllm_buildable-bf16-tp1)
  - With LoRA support:
    - df4113435195daa68b56c83741d66b422c463c556fc1669f39f923427c1c57c5 (tensorrt_llm-trtllm_buildable-bf16-tp1-lora)
- Incompatible with system:
  - fa55c825306dfc09c9d0e7ef423e897d91fe8334a3da87d284f45f45cbd4c1b0 (tensorrt_llm-h100-fp8-tp2-pp1-latency)
  - 33e38db03bb29d47b6c6e604c5e3686f224a1f88e97cd3e0e18cf83e71a949fb (tensorrt_llm-h100_nvl-fp8-tp2-pp1-latency)
  - f8b5f71dd66c36c70deac7927cbd98b1c4f78caf1abf01f768be7118e1daa278 (tensorrt_llm-h100-fp8-tp1-pp1-throughput)
  ...
```

From this output you can specify the model profiles to cache in your `NIMCache` resource. The NIM Cache will download the model and profiles and be prepared for when a NIMService is deployed and refers to the model that is in the cache. 

## Deploy the NIMService

Our last step is to deploy the NIMService resource. This will instantiate the NIM model on Kubernetes and available to serve inference requests.

```yaml
apiVersion: apps.nvidia.com/v1alpha1
kind: NIMService
metadata:
  name: meta-llama3-8b-instruct
spec:
  image:
    repository: nvcr.io/nim/meta/llama-3.1-8b-instruct
    tag: 1.3.3
    pullPolicy: IfNotPresent
    pullSecrets:
      - ngc-secret
  authSecret: ngc-api-secret
  storage:
    nimCache:
      name: meta-llama3-8b-instruct
  replicas: 1
  resources:
    limits:
      nvidia.com/gpu: 1
  expose:
    service:
      type: ClusterIP
      port: 8000
```

Now if you login to the GKE cluster and find a simple client pod, you can test the NIMService with the following command:

```bash
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- curl "http://meta-llama3-8b-instruct.default:8000/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta/llama-3.1-8b-instruct",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

You should see output like this:

```bash
{"id":"chat-ed3d7d2a37de47e4aa62116a6af64b13","object":"chat.completion","created":1739155307,"model":"meta/llama-3.1-8b-instruct","choices":[{"index":0,"message":{"role":"assistant","content":"Hello! How can I assist you today?"},"logprobs":null,"finish_reason":"stop","stop_reason":null}],"usage":{"prompt_tokens":12,"total_tokens":21,"completion_tokens":9},"prompt_logprobs":null}pod "curl-test" deleted
```

## Wrapping Up

Running your own LLM inferencing service on Kubernetes is a great way to get started with AI. If you're looking to run NIM microservices on Kubernetes, and especially GKE, I hope this guide helps you out. If you have any questions, please 

- reach out to the [community on GitHub](https://github.com/NVIDIA/k8s-nim-operator/issues)
- check the [docs](https://docs.nvidia.com/nim-operator/latest/index.html)
- I'm happy to help out with any questions you have [@christianposta](https://x.com/christianposta) or [in/ceposta](https://www.linkedin.com/in/ceposta).

