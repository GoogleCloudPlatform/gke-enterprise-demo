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

set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT=..

# creates a trimmed list of the files that need updates based on the boilerplate.py
BAD_HEADERS=$( ( python test/verify_boilerplate.py || true ) | sed -e 1d )

# we're only going to auto-update certain filetypes. include any filetype that you need to update in this list
FORMATS="sh go Makefile Dockerfile py tf yaml yml bazel"

YEAR=$(date +%Y)

for i in ${FORMATS}
do
	:
	for j in ${BAD_HEADERS}
	do
		:
		# these are what our headers should look like. we'll update the year to reflect today
		HEADER=$(< "${PROJECT_ROOT}"/test/boilerplate/boilerplate."${i}".txt sed "s/YEAR/${YEAR}/")

		# read the actual header/top of of the file, it will be needed to substitute
		value=$(<"${j}")

		# since we iterate over the formats, we need to skip updates during incorrect formats
		if [[ "$j" != *$i ]]
		then
			continue
		fi

		# check the contents of the file and update if needed
		if [[ ${value} == *"# Copyright"* ]]
		then
			echo "Bad header in ${j} ${i}"
		else
			text="$HEADER
$value"
				echo "${j}"
				echo "$text" > "${j}"
			fi
	done
done
