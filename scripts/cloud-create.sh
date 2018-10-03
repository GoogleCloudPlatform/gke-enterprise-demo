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
# "-  install pyrios on cloud cluster                     -"
# "-                                                       -"
# "---------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel)

source "$PROJECT_ROOT"/k8s.env

echo "Creating pyrios deployment on ${CLOUD_GKE_CONTEXT}"

# get elasticsearch service's internal load balancer IP
LB_IP=$(kubectl --namespace default --context="${ON_PREM_GKE_CONTEXT}" get svc -l component=elasticsearch,role=client -o jsonpath='{..ip}')
kubectl config use-context "${CLOUD_GKE_CONTEXT}"
echo "LB_IP=$LB_IP"
kubectl --namespace default create configmap esconfig \
		--from-literal=ES_SERVER="${LB_IP}"

kubectl --namespace default apply -f "$PROJECT_ROOT"/policy/cloud-network-policy.yaml

kubectl --namespace default apply -f "$PROJECT_ROOT"/pyrios/manifests
kubectl --namespace default rollout status -f "$PROJECT_ROOT"/pyrios/manifests/deployment.yaml

kubectl --namespace default apply -f "$PROJECT_ROOT"/pyrios-ui/manifests
kubectl --namespace default rollout status -f "$PROJECT_ROOT"/pyrios-ui/manifests/deployment.yaml
