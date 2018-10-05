#!/usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# update-elasticsearch.sh - Rolling update of the Elasticsearch cluster, for
# more information see:
# https://www.elastic.co/guide/en/elasticsearch/reference/current/rolling-updates.html

# Stop immediately if something goes wrong
set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT=..

fail() {
  echo "ERROR: ${*}"
  exit 2
}

usage() {
  cat <<-EOM
USAGE: $(basename "$0") <new-elasticsearch-version>

Where <new-elasticsearch-version> is a tag available in this
Docker repository:
https://quay.io/repository/pires/docker-elasticsearch-kubernetes?tab=tags
EOM
  exit 1
}

# Validate the number of command line arguments
if [[ $# -lt 1 ]]; then
  usage
fi

# Validate that this workstation has access to the required executables
command -v kubectl >/dev/null || fail "kubectl is not installed!"
command -v jq >/dev/null || fail "jq is not installed!"

# shellcheck source=./k8s.env
source "$PROJECT_ROOT"/k8s.env

# disable_shard_allocation() - Sets the cluster.routing.allocation.enable
# setting to "none".  Prevents shards from being migrated from an upgrading
# Data Node to another active Data Node.
disable_shard_allocation() {
  echo "Disable shard allocation..."
  curl -X PUT \
    -H "Content-Type: application/json" \
    -d '{"persistent":{"cluster.routing.allocation.enable":"none"}}' \
    'http://localhost:9200/_cluster/settings'
  echo ""
}

# Disable cluster processes as recommended by the Elasticsearch documentation
prep_for_update() {
  disable_shard_allocation

  echo "Stop non-essential indexing and perform a sync flush..."
  curl -X POST 'http://localhost:9200/_flush/synced'
  echo ""
}

# enable_shard_allocation() - sets the cluster.routing.allocation.enable to the
# default value ("all")
enable_shard_allocation() {
  echo "Re-enabling shard allocation"
  curl -X PUT \
    -H "Content-Type: application/json" \
    -d '{"persistent":{"cluster.routing.allocation.enable":"all"}}' \
    'http://localhost:9200/_cluster/settings'
  echo ""
}

# update_deployment() - Apply a patch to upgrade a Deployment's image tag.
# Usage:
# update_controller <workload-type> <name> <version>
# Where:
# <workload-type> - 'deployment' or 'statefulset'
# <name> - workload name, i.e. 'es-master', or 'es-data'
# <version> - the tag version to update to
update_deployment() {
  NAME=$1
  VERSION=$2
  echo "Updgrading the ${NAME} Deployment to version ${VERSION}..."
  # kubectl patch can be used to update resource objects
  # https://kubernetes.io/docs/tasks/run-application/update-api-object-kubectl-patch/
  kubectl patch deployment "${NAME}" \
    -p '{"spec":{"template":{"spec":{"containers":[{"name":"'"${NAME}"'","image":"quay.io/pires/docker-elasticsearch-kubernetes:'"${VERSION}"'"}]}}}}'
  # Monitor the upgrade as it progresses
  kubectl rollout status deployment "${NAME}"
}

# wait_for_allocations() - Checks cluster health in a loop waiting for
# unassianged_shards to return to 0.
wait_for_allocations() {
  echo "Checking shard allocations"
  while true; do
    UNASSIGNED=$(curl 'http://localhost:9200/_cluster/health' 2>/dev/null \
      | jq -r '.unassigned_shards')
    if [[ "${UNASSIGNED}" == "0" ]]; then
      echo "All shards-reallocated"
      return 0
    else
      echo "Number of unassigned shards: ${UNASSIGNED}"
      sleep 3
    fi
  done
}

# wait_for_green() - checks the cluster health endpoint and looks for a 'green'
# status response in a loop.
# Usage:
# wait_for_green <data-nodes>
# Where:
# <data-nodes> is the number of replicas defined in the Data Node StatefulSet
wait_for_green() {
  DATA_NODES=$1
  echo "Checking cluster status"
  # First, wait for the new data node to join the cluster, wait and loop.
  while true; do
    NODES=$(curl 'http://localhost:9200/_cluster/health' 2>/dev/null \
      | jq -r '.number_of_data_nodes')
    if [[ ${NODES} == "${DATA_NODES}" ]]; then
      # Now that the data node is back, we can re-enable shard allocations
      echo "Elasticsearch cluster status has stabilized"
      enable_shard_allocation
      # Wait for the shards to re-initialize
      wait_for_allocations
      break
    fi
    echo "Data nodes available: ${NODES}, waiting..."
    sleep 20
  done
  # Now that the data node is joined, wait for its shards to complete
  # initialization
  while true; do
    STATUS=$(curl 'http://localhost:9200/_cluster/health' 2>/dev/null \
      | jq -r '.status')
    if [[ "${STATUS}" == "green" ]]; then
      echo "Cluster health is now ${STATUS}, continuing upgrade..."
      disable_shard_allocation
      return 0
    fi
    echo "Cluster status: ${STATUS}"
    sleep 5
  done

}

# update_statefulset() - Update a Statefulset's image tag then upgrade one pod
# at a time, waiting for the cluster health to return to 'green' before
# proceeding to the next pod.
# Usage:
# update_statefulset <name> <version>
# Where:
# <name> - the name of the statefulset
# <version> - the tag version to update to
update_statefulset() {
  NAME=$1
  VERSION=$2

  echo "Setting updateStrategy to OnDelete"
  # Patch updateStrategy to 'OnDelete'.  We can't use 'OnDelete' initially
  # because this bug breaks our on-prem-create.sh script:
  # https://github.com/kubernetes/kubernetes/issues/64500√
  kubectl patch statefulset "${NAME}" -p \
    '{"spec":{"updateStrategy":{"type":"OnDelete"}}}' || true

  echo "Updating the ${NAME} Statefulset to Elasticsearch version ${VERSION}..."
  kubectl patch statefulset "${NAME}" -p \
    '{"spec":{"template":{"spec":{"containers":[{"name":"'"${NAME}"'","image":"quay.io/pires/docker-elasticsearch-kubernetes:'"${VERSION}"'"}]}}}}' || true

  # For a statefulset with 3 replicas, this will loop three times wth the
  # 'ORDINAL' values 2, 1, and 0
  REPLICAS=$(kubectl get statefulset "${NAME}" -o jsonpath='{.spec.replicas}')
  MAX_ORDINAL=$(( REPLICAS - 1 ))
  for ORDINAL in $(seq "${MAX_ORDINAL}" 0); do

    CURRENT_POD="${NAME}-${ORDINAL}"
    echo "Updating ${CURRENT_POD}"

    kubectl delete pod "${CURRENT_POD}"

    # Give some time for the es java process to terminate and the cluster state
    # to turn 'yellow'
    sleep 3

    # Now wait for the cluster health to return to 'green'
    wait_for_green "${REPLICAS}"
  done
}

# port_update_cleanup() - Re-enable any services disabled prior to the upgrade.
post_update_cleanup() {
  enable_shard_allocation
}

# update() - The update procedure.
update() {
  # Make sure kubectl is configured with the correct context
  kubectl config set-context "${ON_PREM_GKE_CONTEXT}"
  NEW_VERSION=$1

  echo "Setting up the port forward to Elasticsearch client..."
  kubectl port-forward svc/elasticsearch 9200 1>&2 >/dev/null &
  # The port-forward is non-blocking, so wait a few seconds
  sleep 5

  prep_for_update

  update_deployment "es-master" "${NEW_VERSION}"
  update_statefulset "es-data" "${NEW_VERSION}"

  # Terminate the port-forward process because it will fail when the clients
  # are updated
  pkill -P $$

  update_deployment "es-client" "${NEW_VERSION}"

  # Post update cleanup
  echo "Re-establish port-forward"
  kubectl port-forward svc/elasticsearch 9200 1>&2 >/dev/null &
  # The port-forward is non-blocking, so wait a few seconds
  sleep 5

  post_update_cleanup

  pkill -P $$

  echo "Upgrade complete!"

}

# There is only one task, perform the update
update "$1"
