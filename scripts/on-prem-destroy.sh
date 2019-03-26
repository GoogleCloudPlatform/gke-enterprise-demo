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
set -o errexit

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# shellcheck source=k8s.env
source "$PROJECT_ROOT"/k8s.env

context="${STAGING_ON_PREM_GKE_CONTEXT}"
# try to set context to on-prem cluster. if we can't set that context, we can't do anything else
# in this file, so we can exit

if [[ ! $(kubectl config use-context "$context") ]]; then
	echo "on-prem cluster was not found; skipping cluster teardown"
	exit 1
fi

# You have to wait the default pod grace period before you can delete the pvcs
GRACE=$(kubectl --namespace default get sts -l component=elasticsearch,role=data -o jsonpath='{..terminationGracePeriodSeconds}')
PADDING=30

kubectl --namespace default delete -f "$PROJECT_ROOT"/elasticsearch/manifests/ || true
kubectl --namespace default delete -f "$PROJECT_ROOT"/policy/on-prem-network-policy.yaml || true

echo "Sleeping $(( GRACE + PADDING )) seconds before deleting PVCs. The default pod grace period."
sleep "$(( GRACE + PADDING ))"

# Deleting and/or scaling a StatefulSet down will not delete the volumes associated with the StatefulSet.
# This is done to ensure data safety, which is generally more valuable
# than an automatic purge of all related StatefulSet resources.
kubectl --namespace default delete pvc -l component=elasticsearch,role=data || true
kubectl --namespace default delete pvc -l component=elasticsearch,role=master || true

timeout=100

# PV's are not deleted immediately with stateful sets. Therefore clean up and wait for PV's to be completely removed before
# proceeding with rest of teardown of the GKE clusters (in the terraform code) in order to avoid orphaned disks
while [ $(kubectl get pvc --all-namespaces | wc -l)  -gt 0 ]  &&  [ $(kubectl get pv --all-namespaces | wc -l ) -gt 0 ] && [ $timeout -gt 0 ]; do
	echo "kubectl get pvc --all-namespaces"
	kubectl get pvc --all-namespaces
	echo "kubectl get pv --all-namespaces"
	kubectl get pv --all-namespaces
	sleep 10
	timeout=$((timeout - 10))
done
