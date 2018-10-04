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

PROJECT_ROOT=$(git rev-parse --show-toplevel)

source "$PROJECT_ROOT"/k8s.env


echo "install elasticsearch on ${ON_PREM_GKE_CONTEXT}"

kubectl config use-context "${ON_PREM_GKE_CONTEXT}"

# Set up RBAC for on-prem-cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control#prerequisites_for_using_role-based_access_control
# You must grant your user the ability to create roles in Kubernetes
# by running the following command
# create cluster-admin-binding if hasn't been done
if ! kubectl get clusterrolebinding cluster-admin-binding >/dev/null 2>&1; then
  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user="$(gcloud config get-value core/account)"
fi

# roll out the master,client and data manifest in order due to dependencies
# roll out master nodes related objects
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-discovery-svc.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-svc.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-master.yaml
kubectl --namespace default rollout status -f "$PROJECT_ROOT"/elasticsearch/manifests/es-master.yaml

# roll out client nodes related objects, client depends on the master nodes
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-client.yaml
kubectl --namespace default rollout status -f "$PROJECT_ROOT"/elasticsearch/manifests/es-client.yaml

# roll out rbac for data nodes
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/service-account.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/clusterrole.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/clusterrolebinding.yaml

# roll out data nodes
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-data-svc.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-data-sc.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/configmap.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-data-stateful.yaml
kubectl --namespace default rollout status -f elasticsearch/manifests/es-data-stateful.yaml

# roll out pdb for master and data nodes
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-master-pdb.yaml
kubectl --namespace default apply -f "$PROJECT_ROOT"/elasticsearch/manifests/es-data-pdb.yaml

kubectl --namespace default apply -f "$PROJECT_ROOT"/policy/on-prem-network-policy.yaml