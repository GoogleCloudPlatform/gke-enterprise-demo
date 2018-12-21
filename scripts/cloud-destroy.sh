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

set -o errexit

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# shellcheck source=k8s.env
source "$PROJECT_ROOT"/k8s.env

CONTEXT="${STAGING_CLOUD_GKE_CONTEXT}"
# try to set context to cloud cluster. if we can't set that context, we can't do anything else
# in this file, so we can exit
if [[ ! $(kubectl config use-context "$CONTEXT") ]]; then
	echo "cloud cluster was not found; skipping cluster teardown"
	exit 1
fi

# delete k8s resources
bazel run \
  --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
  --define cluster="${CONTEXT}" \
  --define repo="${REPO}" \
  //pyrios-ui:k8s.delete
  
bazel run \
  --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
  --define cluster="${CONTEXT}" \
  --define repo="${REPO}" \
  //pyrios:k8s.delete

# delete config map
kubectl --namespace default delete configmap esconfig
# delete network policy
kubectl --namespace default delete -f policy/cloud-network-policy.yaml