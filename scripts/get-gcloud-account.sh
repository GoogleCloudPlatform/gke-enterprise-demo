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

## This script is used exclusively by terraform to determine the account currently logged in
## This script is called using the external provider from Terraform
## Because a label can only have 63 bytes, truncate to 63 characters

set -e
gcloud_account=$(gcloud config get-value core/account | sed -e 's/[^-_[:alnum:]]/_/g' | cut -c -63 )

## Terraform external provider requires that the output of the script to be a valid JSON string
jq -n --arg name $gcloud_account '{"gcloud_account": $name}'
