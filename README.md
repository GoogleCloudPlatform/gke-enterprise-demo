# Connecting to an on-prem Elasticsearch cluster from an application in Google Kubernetes Engine

<!-- TOC -->
- [Introduction](#introduction)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
    - [Tools](#tools)
- [Configure gcloud](#configure-gcloud)
- [Enable the GCP services](#enable-the-gcp-services)
- [Run Terraform for Infrastructure Provisioning](#run-terraform-for-infrastructure-provisioning)
- [Configure](#configure)
- [Infrastructure design highlights](#infrastructure-design-highlights)
    - [Elasticsearch API exposed via ILB (Internal Load Balancer)](#elasticsearch-api-exposed-via-ilb-internal-load-balancer)
    - [Elasticsearch Cluster HA set up with regional PD](#elasticsearch-cluster-ha-set-up-with-regional-pd)
    - [RBAC set up in the demo](#rbac-set-up-in-the-demo)
    - [What is pyrios?](#what-is-pyrios)
        - [Build and push pyrios docker image](#build-and-push-pyrios-docker-image)
- [Deploy Kubernetes Resources](#deploy-kubernetes-resources)
- [Expose the `pyrios` pod](#expose-the-pyrios-pod)
    - [Load sample data to the Elasticsearch Cluster](#load-sample-data-to-the-elasticsearch-cluster)
    - [Validation](#validation)
- [Teardown](#teardown)
- [Troubleshooting](#troubleshooting)
- [Relevant Material](#relevant-material)

<!-- /TOC -->

## Introduction

This demo illustrates best practices and considerations when connecting
to your existing on-prem database from a [Kubernetes
Engine](https://cloud.google.com/kubernetes-engine/) cluster.


The key takeaway for this demo is the usage of [Cloud
VPN](https://cloud.google.com/vpn/docs/) to connect to your datacenter
from your GCP network. Cloud VPN can be used to connect GCP networks to
on-prem datacenters or even other GCP networks.


## Architecture

The demo can't contain its own on-prem data center so we have to emulate
an on-prem data center by creating a separate VPC network. That on-prem
network contains a Kubernetes Engine cluster with a multi-pod Elasticsearch cluster in
it. We then build another separate VPC network, the cloud network, that
contains an application running in Kubernetes Engine.

The data centers are connected via [Cloud VPN](https://cloud.google.com/vpn/docs/). It's common practice to
connect remote data centers together with VPNs and the cloud is no
exception. You can setup a Cloud VPN to connect your cloud VPC to your
on-prem data center. In this demo both of our data centers are in the
cloud so each data center has its own Cloud VPN gateway with a public IP
address. We use [forwarding rules](https://cloud.google.com/compute/docs/load-balancing/network/forwarding-rules)
to direct traffic sent to the public IP addresses to the gateways. We
create an [IPSec tunnel](https://en.wikipedia.org/wiki/IPsec#Tunnel_mode) between the
gateways using a shared secret. We ensure the data center traffic leaves
via the VPN gateway with subnet routes and [traffic
selectors](https://cloud.google.com/vpn/docs/concepts/choosing-networks-routing#static-routing-networks).
All of this configuration can be found in the ['datacenter'
module](modules/datacenter/main.tf) of this demo.

The Elasticsearch pods are accessed via their Cluster IPs which is within the [Alias IP range](https://cloud.google.com/vpc/docs/alias-ip) of the VPC.
Once the networks are connected the application is able to connect to
the 'on-prem' Elasticsearch cluster.

![Connecting Pyrios to on-prem Elasticsearch cluster via Cloud
VPN](docs/gcp-on-prem.png)

The 'on-prem' datacenter has an eight pod Elasticsearch cluster running client, master, and data pods. The data pods are
deployed as a StatefulSet. The nodes in the GKE cluster are type
n1-standard-4. The manifests were used from the [pires Elasticsearch
project](https://github.com/pires/kubernetes-elasticsearch-cluster) with
some tuning on memory.

The cloud datacenter contains another Kubernetes Engine cluster running a single node
with a single pod in it. The pod is running a custom application called
'pyrios' (NOT related to
[google/pyrios](https://github.com/google/pyrios)). It acts as a proxy
to the on-prem Elasticsearch cluster. Any application with network
access can talk to the Elasticsearch cluster via the pyrios container.
In this demo that application is the **validate.sh** script, which loads
the collected works of Shakespeare into the cluster and then queries the
cluster to show that the data was loaded correctly.


## Prerequisites

### Tools

1. Terraform >= 0.11.7
2. gcloud (Google Cloud SDK version >= 204.0.0)
3. kubectl >= 1.9.7
4. bash or bash compatible shell
5. jq (very common, can be found in any package manager)
5. A Google Cloud Platform project where you have permission to create
   networks

## Configure gcloud

Before running any commands, configure gcloud with the project you wish
to use for this demo:

```console
gcloud config set project <PROJECT_ID>
```

## Enable the GCP services

Please enable the GCP services by running `make bootstrap`. The command
runs like the following:

```console
$ make bootstrap
gcloud services enable \
	  cloudresourcemanager.googleapis.com \
	  compute.googleapis.com \
	  container.googleapis.com \
	  cloudbuild.googleapis.com \
	  containerregistry.googleapis.com
Waiting for async operation operations/tmo-acf.e898de22-74cb-4f9c-9811-fd66c0f57173 to complete...
Operation finished successfully. The following command can describe the Operation details:
 gcloud services operations describe operations/tmo-acf.e898de22-74cb-4f9c-9811-fd66c0f57173
Waiting for async operation operations/tmo-acf.33b02d7e-6e5f-489f-a764-083faa63c367 to complete...
Operation finished successfully. The following command can describe the Operation details:
 gcloud services operations describe operations/tmo-acf.33b02d7e-6e5f-489f-a764-083faa63c367
Waiting for async operation operations/tmo-acf.99f6f42d-b98a-4ea2-a924-db6e219d3b62 to complete...
Operation finished successfully. The following command can describe the Operation details:
 gcloud services operations describe operations/tmo-acf.99f6f42d-b98a-4ea2-a924-db6e219d3b62
Waiting for async operation operations/tmo-acf.d46ed8d8-9c98-4e42-a931-56376d788104 to complete...
Operation finished successfully. The following command can describe the Operation details:
 gcloud services operations describe operations/tmo-acf.d46ed8d8-9c98-4e42-a931-56376d788104
Waiting for async operation operations/tmo-acf.a720d526-cec8-4b29-b38c-b197b9597de4 to complete...
Operation finished successfully. The following command can describe the Operation details:
 gcloud services operations describe operations/tmo-acf.a720d526-cec8-4b29-b38c-b197b9597de4
```

## Run Terraform for Infrastructure Provisioning

Please run `make terraform` to provisions the infrastructure. The first
time you run this code, make will initialize terraform in the project
directory:
```console
$ make terraform
terraform fmt
terraform validate -check-variables=false
terraform init
Initializing modules...
- module.cloud
  Getting source "modules/datacenter"
- module.on-prem
  Getting source "modules/datacenter"

Initializing provider plugins...
- Checking for available provider plugins on https://releases.hashicorp.com...
- Downloading plugin for provider "google" (1.14.0)...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Then it prompts you for a shared secret for VPN:
```console
var.shared_secret
  Enter a value:
```
Finally it asks for confirmation
to go ahead with the deployment and build out the two networks,
each with a GKE cluster.



After the steps finished successfully, there will be one multi zone Kubernetes Engine
cluster to simulate an on-prem data center, as well one zonal Kubernetes Engine
cluster for cloud.

## Configure

Run `make config`, which will generate an environment specific `k8s.env` to be
shared among the shell scripts.

```console
$ make config
Fetching cluster endpoint and auth data.
kubeconfig entry generated for on-prem-cluster.
Fetching cluster endpoint and auth data.
kubeconfig entry generated for cloud-cluster.
```


## Infrastructure design highlights

### Elasticsearch API exposed via ILB (Internal Load Balancer)

In order to expose the on premise Elasticsearch as a *service* to the
cloud Kubernetes Engine cluster, we need to expose it via an Internal Load
Balancer(ILB).  By doing so, the Elasticsearch cluster can be accessed
by any application running in the cloud. The traffic will be travel
through the VPN between the cloud Kubernetes Engine and the on prem Kubernetes Engine clusters.
`es-svc.yaml` shows how it is implemented by a kubernetes annotation,
`cloud.google.com/load-balancer-type: "Internal"`, which specifies that
an internal load balancer is to be configured. Please refer to [Creating
an internal load
balancer](https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing#create)
for details.



### RBAC set up in the demo

[ Role-Based Access Control](https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control)
is used for authenticating Elasticsearch data node's graceful shutdown script.
During the shutdown, the shutdown script (`pre-stop-hook.sh` in
manifests/configmap.yaml) needs to access the stateful set's status in
the on-prem Kubernetes Engine cluster. Hence, we need to create a service
account,cluster role and cluster role binding for this to work.
Under `manifests` folder
* `clusterrole.yaml`: a ClusterRole `elasticsearch-data` for reading statefulset
* `service-account.yaml`: a ServiceAccount `elasticsearch-data`
* `clusterrolebinding.yaml`: a ClusterRoleBinding `elasticsearch-data` to bind
the cluster role and service account declared in the above.

### What is pyrios?

`pyrios` is a minimalist proxy server for Elasticsearch. The key idea is
to proxy the REST request from the cloud Kubernetes Engine cluster to the on -premises
Elasticsearch cluster.

#### Build and push pyrios docker image

This step is only necessary if you are interested in building & pushing
your own `pyrios` docker image onto your own project's gcr.io image
repository.
* The demo itself uses a public image lives at
  gcr.io/pso-example/pyrios.
* `cd pyrios && make container` uses the GCB(Google Container Builder)
  for building and pushing docker image to gcr.io/${PROJECT_ID}, i.e.
  your own project's gcr.io image repository.

## Deploy Kubernetes Resources

Please run `make create`, which invokes the scripts to create all
Kubernetes objects.

### Elasticsearch Cluster HA set up with regional PD

The Elasticsearch cluster uses [regional persistent disks](https://cloud.google.com/compute/docs/disks/#repds) to improve
its availability. These disks are replicated across multiple zones in a
region. The Elasticsearch cluster in the demo uses the 'regional-pd'
volume type for its data nodes. Once the clusters are setup you can see
for yourself with the following command. Note that the LOCATION_SCOPE
says 'region'.

```console
gcloud beta compute disks list --filter="region:us-west1"
NAME                                                             LOCATION     LOCATION_SCOPE  SIZE_GB  TYPE         STATUS
gke-on-prem-cluster-f1-pvc-9cf7b9b3-6472-11e8-a9b6-42010a800140  us-west1  region          13       pd-standard  READY
gke-on-prem-cluster-f1-pvc-b169f561-6472-11e8-a9b6-42010a800140  us-west1  region          13       pd-standard  READY
gke-on-prem-cluster-f1-pvc-bcc115d6-6472-11e8-a9b6-42010a800140  us-west1  region          13       pd-standard  READY
```

## Expose the `pyrios` pod

We need to make the `pyrios` pod accessible so that we can load sample
Shakespeare data and validate the Elasticsearch API via `pyrios`. Run
`make expose` in a separate terminal. `make expose` will cause kubectl to use SSH to create a tunnel that forwards local traffic on port 9200 to the remote node running the pyrios pod on port 9200. The pyrios pod
forwards the API request to the on prem Elasticsearch cluster and passes
the results back.

```console
$ make expose
Forwarding from 127.0.0.1:9200 -> 9200
Handling connection for 9200
```

kubectl will not return on its own. The tunnel remains open until you end the process with Ctrl+C.

### Load sample data to the Elasticsearch Cluster

Run `make load` loads the sample *shakespeare.json* into the
Elasticsearch cluster via Elasticsearch Bulk API.

```console
make load
Loading the index into the Elasticsearch cluster
{"acknowledged":true,"shards_acknowledged":true,"index":"shakespeare"}
Loading data into the Elasticsearch cluster
```

### Validation

Run `make validate` validates the Elasticsearch cluster by invoking its
REST API. The scripts checks cluster version, health, sample data as well as a
couple of types of queries (called query DSL in Elasticsearch term)
on the sample data.

```console
make validate
Elasticsearch version matched
Elasticsearch cluster status is green
Shakespeare data has the expected number of shards
Shakespeare match_all query has the expected numbers of hits
Shakespeare match query on speaker LEONATO has the expected numbers of hits
```

### UI

There is a UI that demonstrates usage of Stackdriver Tracing and custom
Stackdriver metrics. You can view the UI by running `make expose-ui`.
In your browser visit [localhost:8080](http://localhost:8080). Each
time the UI page is refreshed it creates traces and metrics.

The custom metric is called `custom/pyrios-ui/numberOfLeonatoHits` and can
be found in the global resource.

There are two traces:
1. pyrios-request - this is an actual Elasticsearch call through the pyrios
proxy
2. pyrios-ui-request - this is the UI being loaded and making numerous calls
to pyrios


## Teardown

Teardown is fully automated. The teardown script deletes every resource
created in the deployment script. In order to teardown, run `make
teardown`.

It will run the following commands:
1. cloud-destroy.sh - destroys the pyrios deployment
2. on-prem-destroy.sh - destroys the Elasticsearch deployments
3. terraform destroy - it prompts you for a shared secret for VPN and
   then destroys the all the project infrastructure


## Troubleshooting

1. `default credentials` Error:

    ```console
    * provider.google: google: could not find default credentials. See https://developers.google.com/accounts/docs/application-default-credentials for more information.
    ```

    Set your
    [credentials](https://www.terraform.io/docs/providers/google/index.html#configuration-reference)
    through any of the available methods. The quickest being:

    ```console
    gcloud auth application-default login
    ```

## Relevant Material

* [Creating an internal load
  balancer](https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing#create)
* [Get higher availability with Regional Persistent Disks on Google
  Kubernetes
  Engine](https://cloudplatform.googleblog.com/2018/05/Get-higher-availability-with-Regional-Persistent-Disks-on-Google-Kubernetes-Engine.html?m=1)
* [pires Elasticsearch
  project](https://github.com/pires/kubernetes-elasticsearch-cluster)
* [ElasticSearch Cluster Sample
  data](https://www.elastic.co/guide/en/kibana/current/tutorial-load-dataset.html)
* [ElasticSearch bulk load
  API](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html)
* [ElasticSearch Query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/query-dsl-match-query.html)