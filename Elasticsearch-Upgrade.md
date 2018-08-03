# Elasticsearch Cluster Rolling Upgrade

## Introduction

This describes the use of the `upgrade-elasticsearch.sh` script to upgrade the
"on-prem" Elasticsearch cluster.  It assumes you have already followed the
instructions in the main README to create the "on-prem" Elasticsearch cluster,
and loaded it with the Shakespeare data set.

## Architecture

The Elasticsearch cluster in this example contains 3 Master Eligible Nodes - one
of which will be elected Master at a time, 3 Data Nodes, and 3 Client Nodes.
Each Node runs in a separate Kubernetes pod. The Data Node pods are controlled
by a StatefulSet and attach a Google Cloud Persistent Disk to each pod for long-
term peristent storage of the index data beyond pod terminations.

The Shakespeare index is split into 5 `primary shards` each with one
corresponding `replica shard`.  To allow the loss of one data node at a time,
Elasticsearch ensures that a `primary shard` and its corresponding replica will
be stored on different data nodes.

The upgrade procedure used is similar to the [Rolling Upgrade](https://www.elastic.co/guide/en/elasticsearch/reference/current/rolling-upgrades.html) procedure
explained in the Elasticsearch documentation.  Each Node is stopped and
replaced with an upgraded version, one at a time.  We wait in between each
upgraded Node to allow the cluster to stabilize before proceeding to the next
Node.

The upgrade demonstrated here diverges from the official recommendation in one
specific regard.  The recommendation to disable shard allocation once at the
beginning of the process must be modified.

At the beginning of the upgrade process, shard allocation is disabled by setting
`cluster.routing.allocation.enable` to `none`.  As each Data Node is deleted,
the shards assigned to it will become `UNASSIGNED`.  If shard allocation was
enabled, the `index.unassigned.node_left.delayed_timeout` default of 60 seconds
would cause shards from an upgrading Data Node to be moved to another active
Data Node.  In practice, shards would have to move from an upgraded node to a
not-yet-upgraded node, which is not supported - Elasticsearch is not backwards
compatible!  This is why the Elasticsearch Rolling Upgrade documentation advises
to disable shard allocation during the upgrade.

Within Kubernetes, a complication appears because we are not simply restarting
Nodes to upgrade to the newer version.  In Kubernetes, you delete the old Node
and a new pod is created with the new version.  New pods look like new servers
to the cluster.  As a new Data Node joins the cluster, its attached volume will
retain the persisted shard data but with shard allocation disabled, the shards
will not initialize.  The shards will remain `UNASSIGNED`, and the cluster
state will not return to `green`.  To overcome this problem, we diverge from
the official recommendation.  The script monitors the New Data Nodes as they
join the cluster, then briefly re-enables shard allocations to allow the
initialization step, and then disables shard allocations again prior to the
next Data Node Upgrade.

The Master Node and Client Node upgrades do not require such special
considerations.

## Prerequisites

### Tools
Make sure that your workstation has the following tools installed:
1.  [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) >= 1.10.4
1.  bash or bash compatible shell
1.  [watch](https://en.wikipedia.org/wiki/Watch_(Unix))
1.  [jq](https://stedolan.github.io/jq/)

`watch` and `jq` can be installed by most package managers, including [Homebrew](https://brew.sh/)
on a Mac workstation.

### Versions

This example was tested using Elasticsearch version `6.2.4` and upgrading to
version `6.3.1`.  If you wish to use different versions, make sure the desired
versions are available in the [Pires docker images](https://quay.io/repository/pires/docker-elasticsearch-kubernetes?tab=tags) listing.

The manifests used to build and upgrade the Elasticsearch cluster are based on
the [Pires docker-elasticsearch-kubernetes repo](https://github.com/pires/docker-elasticsearch-kubernetes) with several improvements
to improve cluster availability.

## Deployment
The `upgrade-elasticsearch.sh` script must interact with the Elasticsearch API
to update cluster configurations and monitor cluster health.  It begins by
creating a port-forward between the Elasticsearch Client service and the
localhost on port 9200.  Prior to upgrading the Client Nodes, the port-forward
process is killed as upgrading the Client Nodes would cause the connection to
fail or reset.  The port forward is re-established at the end of the process
to re-enable shard allocations.

From within this directory execute the following command:
```console
./upgrade-elasticsearch.sh 6.3.1
```
The upgrade will proceed through the Elasticsearch Master Deployment, the Data
StatefulSet, and finally the Client Deployment.  The last few lines of output
will look like this:
```console
deployment "es-client" successfully rolled out
Re-establish port-forward
Re-enabling shard allocation
{"acknowledged":true,"persistent":{"cluster":{"routing":{"allocation":{"enable":"all"}}}},"transient":{}}
Upgrade complete!
```

## Validation

Each of the following commands should be run in a separate dedicated terminal.

**Search API***

Throughout the upgrade, the Elasitcsearch Search API should be available from
the Client service.  In a terminal, create a loop to query something that you
know will return results from the Shakespeare index:

```console
watch curl --max-time 1 'http://localhost:9200/shakespeare/_search?q=happy%20dagger'
```

**Cluster Health**

During a master re-election, cluster level APIs and index metadata reads will
fail.  At all other times, the Cluster Health command should work:

```console
watch 'curl http://localhost:9200/_cluster/health 2>/dev/null | jq .'
```

**Shard Allocations**

You can monitor the shard allocations to ensure that, though shards will switch
from `replica` to `primary` as the data nodes are upgraded and recreated, the
shards will not be relocated to different nodes.  (This command will also fail
during a Master re-election.)

```console
watch curl http://localhost:9200/_cat/shards
```

**Nodes**

You can monitor the cluster membership as Nodes leave and join the cluster.
(This command will also fail during a Master re-election.)

```console
watch curl 'http://localhost:9200/_cat/nodes'

```

## Troubleshooting

* `E0720 12:22:53.871205   37279 portforward.go:331] an error occurred forwarding 9200 -> 9200: error forwarding port 9200 to pod a348720f7d1c5a494a47a084cd94dd4f596f06fbf2180174ac5883f429898a3c, uid : exit status 1: 2018/07/20 16:22:53 socat[1239] E connect(5, AF=2 127.0.0.1:9200, 16): Connection refused`
  Occasionally the port-forward process spawned by `upgrade-elasticsearch.sh`
  will fail.  You will need to find this process and kill it:

  ```console
  kill $(ps aux | grep [p]ort-forward | awk '{print $2}')
  ```

  Once killed, in a new terminal, reconnect with the following command:

  ```console
  kubectl port-forward svc/elasticsearch 9200
  ```

## Relevant links

* [Elasticsearch Shard Allocations](https://www.elastic.co/guide/en/elasticsearch/reference/master/shards-allocation.html)
* [Elasticsearch Rolling Upgrades](https://www.elastic.co/guide/en/elasticsearch/reference/current/rolling-upgrades.html)
* [Pires docker-elasticsearch-kubernetes repo](https://github.com/pires/docker-elasticsearch-kubernetes)
* [Pires docker images](https://quay.io/repository/pires/docker-elasticsearch-kubernetes?tab=tags)
* [StatefulSet Canary Rollout](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/#rolling-out-a-canary)
