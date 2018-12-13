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

# Applies the given manifest file to the given cluster context.
# Globals:
#   None
# Arguments:
#   MANIFEST_FILE
#   PROJECT_ROOT
#   CONTEXT
# Returns:
#   1
function apply_manifest()
{
  local MANIFEST_FILE="$1"
  local PROJECT_ROOT="$2"
  local CONTEXT="$3"

  kubectl --namespace default --context "$CONTEXT" apply \
    -f "$PROJECT_ROOT"/elasticsearch/manifests/"$MANIFEST_FILE"
}

# Waits for the given rollout to complete for the given timeout period.
# Globals:
#   None
# Arguments:
#   MANIFEST_FILE
#   PROJECT_ROOT
#   CONTEXT
#   TIMEOUT
# Returns:
#   1
function wait_for_rollout()
{
  local MANIFEST_FILE="$1"
  local PROJECT_ROOT="$2"
  local CONTEXT="$3"
  local TIMEOUT="$4"

  kubectl --namespace default --context "$CONTEXT" \
    --request-timeout="$TIMEOUT" rollout status \
    -f "$PROJECT_ROOT"/elasticsearch/manifests/"$MANIFEST_FILE"
}