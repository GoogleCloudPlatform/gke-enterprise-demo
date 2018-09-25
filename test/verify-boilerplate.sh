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

# This is a wrapper for test/boilerplate/boilerplate.py which has the 
# meat of the logic.

# Wrapper for the meat of the boilerplate code at test/boilerpolate/boilerplate.py
. $(dirname "${BASH_SOURCE}")/common.sh

# grabs only the array of files that need to be updated
boiler=$((python ${PROJECT_ROOT}/test/boilerplate/boilerplate.py || true) | sed -e 1d)

files_need_boilerplate=( $boiler )

if [[ -z ${files_need_boilerplate+x} ]]; then
    exit
fi

# these are INDIVIDUAL files that need to be excluded. a common use is generated code 
TO_REMOVE=()

# The files we actually want to update will get pushed on this array
FINAL_LIST=()


# if there are items in TO_REMOVE, we need to find them and exclude them
if [[ ${#TO_REMOVE[@]} -gt 0 ]]
then
  
  for pkg in "${files_need_boilerplate[@]}"; do
      for remove in "${TO_REMOVE[@]}"; do
          KEEP=true
          if [[ ${pkg} == ${remove} ]]; then
              KEEP=false
              break
          fi
      done
      if ${KEEP}; then
          FINAL_LIST+=(${pkg})
      fi
  done
# if not, then our original list is correct so let's use it for output
else
  FINAL_LIST=$files_need_boilerplate
fi

# if there's something in that list, we'll echo the files that need help and exit with an error code
if [[ ${#FINAL_LIST[@]} -gt 0 ]]; then
  for file in "${FINAL_LIST[@]}"; do
    echo "FAIL: Boilerplate header is wrong for: ${file}"
  done
  echo "FAIL: Please execute ./test/update-header.sh"
  exit 1
fi
