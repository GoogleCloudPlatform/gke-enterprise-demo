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

# This is a wrapper for test/boilerplate/boilerplate.py which has the meat of the matching logic

set -o errexit
set -o nounset

echo "Checking boilerplate"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" 2>&1 >/dev/null && pwd )"
boiler="$( (python "$DIR"/verify_boilerplate.py "$@" / || true) | sed -e 1d)"


if ! [[ $boiler -gt 0 ]]; then
  echo " > boilerplate headers conform to spec"
  echo ""
  exit 0
fi

files_need_boilerplate=( "$boiler" )

# these are INDIVIDUAL files that need to be excluded. a common use is generated code
TO_REMOVE=()

# The files we actually want to update will get pushed on this array
FINAL_LIST=()
for pkg in "${files_need_boilerplate[@]}"; do
    KEEP=true
    # if there are no items in TO_REMOVE, we have to skip this loop
    if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
      for remove in "${TO_REMOVE[@]}"; do
          if [[ "${pkg}" == "${remove}" ]]; then
              KEEP=false
              break
          fi
      done
    fi
    # if the file was not on the remove list, we'll add it to final_list
    if ${KEEP}; then
        FINAL_LIST+=("${pkg}")
    fi
done


# if there's something in that list, we'll echo the files that need help and exit with an error code
if [[ ${#FINAL_LIST[@]} -gt 0 ]]; then

  echo "${#FINAL_LIST[@]}: ${FINAL_LIST[0]}"
  for file in "${FINAL_LIST[@]}"; do
    echo "FAIL: Boilerplate header is wrong for: ${file}"
  done
  echo "FAIL: Please execute ./test/update-header.sh"
  exit 1
fi
