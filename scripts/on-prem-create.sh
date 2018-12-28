#!/bin/bash

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

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Install ElasticSearch Cluster on GKE                 -"
# "-                                                       -"
# "---------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail
set -x

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# shellcheck source=k8s.env
source "$PROJECT_ROOT"/k8s.env
source "$PROJECT_ROOT"/scripts/common-functions.sh

CONTEXT="${STAGING_ON_PREM_GKE_CONTEXT}"

echo "install elasticsearch on $CONTEXT cluster"
TIMEOUT="5m"

echo "Set up RBAC for on-prem-cluster"
# Set up RBAC for on-prem-cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control#prerequisites_for_using_role-based_access_control
# You must grant your user the ability to create roles in Kubernetes
# by running the following command
# create cluster-admin-binding if hasn't been done
if ! kubectl --namespace default --context "$CONTEXT" get clusterrolebinding cluster-admin-binding >/dev/null 2>&1; then
  echo "create admin cluster role binding"
  kubectl --namespace default \
    --context "$CONTEXT" \
    create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user="$(gcloud config get-value core/account)"
fi

apply_manifest es-discovery-svc.yaml $PROJECT_ROOT $CONTEXT
apply_manifest es-svc.yaml $PROJECT_ROOT $CONTEXT

apply_manifest es-master-svc.yaml $PROJECT_ROOT $CONTEXT
apply_manifest es-master-stateful.yaml $PROJECT_ROOT $CONTEXT

wait_for_rollout es-master-stateful.yaml $PROJECT_ROOT $CONTEXT $TIMEOUT

apply_manifest es-ingest-svc.yaml $PROJECT_ROOT $CONTEXT
apply_manifest es-ingest.yaml $PROJECT_ROOT $CONTEXT

wait_for_rollout es-ingest.yaml $PROJECT_ROOT $CONTEXT $TIMEOUT

apply_manifest service-account.yaml $PROJECT_ROOT $CONTEXT
apply_manifest clusterrole.yaml $PROJECT_ROOT $CONTEXT
apply_manifest clusterrolebinding.yaml $PROJECT_ROOT $CONTEXT

apply_manifest es-data-svc.yaml $PROJECT_ROOT $CONTEXT
apply_manifest es-data-sc.yaml $PROJECT_ROOT $CONTEXT
apply_manifest configmap.yaml $PROJECT_ROOT $CONTEXT
apply_manifest es-data-stateful.yaml $PROJECT_ROOT $CONTEXT

wait_for_rollout es-data-stateful.yaml $PROJECT_ROOT $CONTEXT $TIMEOUT

apply_manifest es-master-pdb.yaml $PROJECT_ROOT $CONTEXT
apply_manifest es-data-pdb.yaml $PROJECT_ROOT $CONTEXT

kubectl --namespace default --context "$CONTEXT" \
  apply -f "$PROJECT_ROOT"/policy/on-prem-network-policy.yaml
