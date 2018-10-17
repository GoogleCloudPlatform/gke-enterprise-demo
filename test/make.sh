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

# This function checks to make sure that every
# shebang has a '- e' flag, which causes it
# to exit on error
function check_bash() {
find . -name "*.sh" | while IFS= read -d '' -r file;
do
  if [[ "$file" != *"bash -e"* ]];
  then
    echo "$file is missing shebang with -e";
    exit 1;
  fi;
done;
}

# This function makes sure that the required files for
# releasing to OSS are present
function basefiles() {
  echo "Checking for required files"

  test -f CONTRIBUTING.md || echo "Missing CONTRIBUTING.md"
  test -f LICENSE || echo "Missing LICENSE"
  test -f README.md || echo "Missing README.md"

  if ! [ "$( test -f CONTRIBUTING.md && test -f LICENSE && test -f README.md )" ]; then
    echo " > All Required OSS files were found"
    echo ""
  fi
}

# This function runs the hadolint linter on
# every file named 'Dockerfile'
function docker() {
  echo "Linting Dockerfiles"
  if ! [[ "$( find . -name "Dockerfile" -exec hadolint {} \; )" ]]; then
    echo "dockerfiles conform to spec"
    echo ""
  fi
}

# This function --include=runs 'terraform validate' against all
# files ending in '.tf'
function check_terraform() {
  echo "Running terraform validate"
  #shellcheck disable=SC2156
  if ! [[ "$(find . -name "*.tf" -exec bash -c 'terraform validate --check-variables=false $(dirname "{}")' \;)" ]]; then
    echo " > terraform code conforms to spec"
    echo ""
  fi
}

# This function runs the flake8 linter on every file
# ending in '.py'
function check_python() {
  echo "Running flake8"
  if [[ "$( find . -not -path "bazel-*" -name "*.py" -exec flake8 {} \; )" ]]; then
    echo " > python code conforms to spec"
    echo ""
  fi
}

# This function runs the shellcheck linter on every
# file ending in '.sh'
function check_shell() {
  echo "Running shellcheck"
  if ! [[ "$( grep -rli --exclude=Makefile --exclude-dir=.git --exclude-dir=.terraform --exclude-dir=bazel-*  --exclude-dir=.idea  "/*.sh$/" . | xargs shellcheck -x )" ]]; then
    echo " > Shell files conform to spec"
    echo ""
  else
    grep -rli --exclude-dir=.git --exclude-dir=.terraform --exclude-dir=bazel-*  --exclude-dir=.idea "/*.sh$/" . | xargs shellcheck -x
  fi
}

# This function makes sure that there is no trailing whitespace
# in any files in the project.
# There are some exclusions
function check_trailing_whitespace() {
  echo "The following lines have trailing whitespace"
  grep -r '[[:blank:]]$' --exclude-dir=".terraform" --exclude="*.png" --exclude="tfplan" --exclude-dir=".git" --exclude-dir="bazel-*"  .
  rc=$?
  if [ $rc = 0 ]; then
    exit 1
  fi
}
