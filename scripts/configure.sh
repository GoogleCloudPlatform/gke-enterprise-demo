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
# "=" configure the demo                                   -"
# "-                                                       -"
# "---------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT=$(dirname "${BASH_SOURCE[0]}")/../

# gcloud and kubectl are required
command -v gcloud >/dev/null 2>&1 || { \
 echo >&2 "I require gcloud but it's not installed.  Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { \
 echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }

PROJECT=$(gcloud config get-value core/project)
if [[ -z "$PROJECT" ]]; then
  echo "No default project set. Please set one with gcloud config"
  exit 1
fi
# generate all k8s contexts for the current project in ~/.kube/config
CLUSTER_NAME_ZONE=$(gcloud container clusters list --format="value(name,zone)" --project "$PROJECT")
echo "$CLUSTER_NAME_ZONE" | xargs -n 2 | while read -r name zone
do
   gcloud container clusters get-credentials "$name" --zone "$zone"
done

# delete k8s.env
if [ -f "$PROJECT_ROOT"k8s.env ]; then
  rm -f "$PROJECT_ROOT"k8s.env
fi

# write out the k8s.env
cat > "$PROJECT_ROOT"k8s.env <<EOF
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

# gcloud and kubectl are required
command -v gcloud >/dev/null 2>&1 || { \
 echo >&2 "I require gcloud but it's not installed.  Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { \
 echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }

STAGING_CLOUD_GKE_CONTEXT=$(kubectl config get-contexts -o=name | grep "$(gcloud config get-value project).*staging-cloud-cluster")
STAGING_ON_PREM_GKE_CONTEXT=$(kubectl config get-contexts -o=name | grep "$(gcloud config get-value project).*staging-on-prem-cluster")

EOF
