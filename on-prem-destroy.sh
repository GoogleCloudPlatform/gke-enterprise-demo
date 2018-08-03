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
# "-  Uninstalls all k8s resources and deletes             -"
# "-  the GKE cluster                                      -"
# "-                                                       -"
# "---------------------------------------------------------"

# Do not set errexit as it makes partial deletes impossible
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1090
source "$ROOT"/k8s.env

kubectl config use-context "${ON_PREM_GKE_CONTEXT}"
# You have to wait the default pod grace period before you can delete the pvcs
grace=$(kubectl --namespace default get sts -l component=elasticsearch,role=data -o jsonpath='{..terminationGracePeriodSeconds}')
kubectl --namespace default delete -f "$ROOT"/manifests/
kubectl --namespace default delete -f "$ROOT"/policy/on-prem-network-policy.yaml

echo "Sleeping ${grace} seconds before deleting PVCs. The default pod grace period."
sleep "${grace}"

# Deleting and/or scaling a StatefulSet down will not delete the volumes associated with the StatefulSet.
# This is done to ensure data safety, which is generally more valuable
# than an automatic purge of all related StatefulSet resources.
kubectl --namespace default delete pvc -l component=elasticsearch,role=data
