#!/usr/bin/env bash

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



# grep the commited .go files.
# ignore anything vendored (probably will go away someday, but for reuse)
# advise which are broken and tell user how to fix it!
bad_files=$(git ls-files "*.go" | grep -v vendor | xargs gofmt -d )
if [[ -n "${bad_files}" ]]; then
  echo "FAIL: '$GOFMT' needs to be run on the following files: "
  echo "${bad_files}"
  echo "FAIL: please execute make gofmt"
  exit 1
fi
