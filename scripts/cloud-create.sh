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

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
DEFAULT_REPO=gcr.io/$(gcloud config get-value project)
REPO=${CONTAINER_REPO:-$DEFAULT_REPO}

# shellcheck source=k8s.env
source "$PROJECT_ROOT"/k8s.env

CONTEXT="${STAGING_ON_PREM_GKE_CONTEXT}"
LB_IP=$(kubectl --namespace default --context="${CONTEXT}" get svc -l component=elasticsearch,role=client -o jsonpath='{..ip}')
kubectl config use-context "${CONTEXT}"

# applying network policy to cloud cluster to help keep traffic going where it should
kubectl  \
  --namespace default \
  --context="${CONTEXT}" \
  apply -f \
  "$PROJECT_ROOT/"policy/cloud-network-policy.yaml

echo "configuring cloud cluster staging environment to communicate with on-prem ES with pyrios"

CONTEXT="${STAGING_CLOUD_GKE_CONTEXT}"
# todo: (i think we need to move this configmap into bazel. possibly template with {j,k}sonnet but not require)
kubectl  \
  --namespace default \
  --context="${CONTEXT}" \
  create configmap esconfig \
  --from-literal=ES_SERVER="$LB_IP" || true

if [[ "$(command -v bazel >/dev/null 2>&1 )" ]] ; then
    echo >&2 "pyrios is currently built and managed via bazel which is not installed."
    echo >&2 "in the future, we will try to provide fall back options using kubectl (boring!)"
    echo "we are not deploying pyrios right now. get your bazel on first!"
    exit 1
else
    echo "building and deploying pyrios and pyrios-ui"
    bazel run \
      --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
      --define cluster="${CONTEXT}" \
      --define repo="${REPO}" \
         //pyrios-ui:k8s.apply
    bazel run \
      --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
      --define cluster="${CONTEXT}" \
      --define repo="${REPO}" \
        //pyrios:k8s.apply
fi
