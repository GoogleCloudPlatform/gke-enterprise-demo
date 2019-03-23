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
# set -o nounset
set -o pipefail
set -x

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# shellcheck source=k8s.env
source "$PROJECT_ROOT"/k8s.env

echo ""
echo "---------------------------------------------------------"
echo "-                                                       -"
echo "-          tear down project infrastructure             -"
echo "-                                                       -"
echo "-                                                       -"
echo "---------------------------------------------------------"
echo ""

PROJECT=$(gcloud config get-value core/project)

# tear down cloud GKE objects, i.e. pyrios deployment, service and configmap
"$PROJECT_ROOT"/scripts/cloud-destroy.sh || true
# tear down on prem GKE objects, i.e. the Elasticsearch cluster

"$PROJECT_ROOT"/scripts/on-prem-destroy.sh || true
# bq is the 'big query' utility build into the GCP SDK.
# Here we use it to remove all the log tables from the BQ dataset
# otherwise Terraform can't delete the dataset

# todo: this seems to get hung up if the log sink export isn't deleted yet.
# we need to be able to robustly delete all resources

bq rm -r -f "${PROJECT}":staging_gke_elasticsearch_log_dataset
# destroy the rest of GCP infrastructure via Terraform
# such as GKE clusters,

terraform destroy -var project="$PROJECT" -input=false -auto-approve terraform/
