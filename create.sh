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
# "=" installs ElasticSerach Cluster  on GKE               -"
# "=" installs pyrios on GKE                              -"
# "-                                                       -"
# "---------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

echo "Installing k8s resources"
ROOT=$(dirname "${BASH_SOURCE[0]}")
# create on prem k8s resouces
"$ROOT"/on-prem-create.sh
# create cloud k8s resouces
"$ROOT"/cloud-create.sh
# TODO: fix network policy. As it stands now pyrios can't reach ES.
# apply network policy
# "$ROOT"/policy.sh
