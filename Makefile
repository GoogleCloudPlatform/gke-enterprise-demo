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

PROJECT := $(shell gcloud config get-value core/project)
ROOT := ${CURDIR}
SHELL := /usr/bin/env bash

# All is the first target in the file so it will get picked up when you just run 'make' on its own
linting: check_shell check_python check_golang check_terraform check_docker check_base_files check_headers check_trailing_whitespace

# The .PHONY directive tells make that this isn't a real target and so
# the presence of a file named 'check_shell' won't cause this target to stop
# working
.PHONY: check_shell
check_shell:
	@source test/make.sh && check_shell

.PHONY: check_python
check_python:
	@source test/make.sh && check_python

.PHONY: check_golang
check_golang:
	@source test/make.sh && golang

.PHONY: check_terraform
check_terraform:
	@source test/make.sh && check_terraform

.PHONY: check_docker
check_docker:
	@source test/make.sh && docker

.PHONY: check_base_files
check_base_files:
	@source test/make.sh && basefiles

.PHONY: check_shebangs
check_shebangs:
	@source test/make.sh && check_bash

.PHONY: check_trailing_whitespace
check_trailing_whitespace:
	@source test/make.sh && check_trailing_whitespace

.PHONY: check_headers
check_headers:
	@echo "Checking file headers"
	@python test/verify_boilerplate.py
# Step 1: bootstrap is used to make sure all the GCP service below are enabled
# prior to the terraform step
.PHONY: bootstrap
bootstrap:
	gcloud services enable \
	  cloudresourcemanager.googleapis.com \
	  compute.googleapis.com \
	  container.googleapis.com \
	  cloudbuild.googleapis.com \
	  containerregistry.googleapis.com \
	  logging.googleapis.com \
	  bigquery-json.googleapis.com

# Step 2: terraform is used to automate the terraform workflow
.PHONY: terraform
terraform:
	terraform fmt
	terraform validate -check-variables=false
	terraform init
	terraform apply -var "project=$(PROJECT)" -auto-approve

# Step 3: configure the k8s context by generateing a k8s.env, decoupling the
# k8s configurations from the scripts
.PHONY: config
config:
	$(ROOT)/configure.sh

# Step 4: create kubernetes objects
.PHONY: create
create:
	$(ROOT)/create.sh

# Step 5: Expose the elasticsearch API endpoint localhost:9200 via the laptop/desktop
.PHONY: expose
expose:
	$(ROOT)/expose.sh

.PHONY: close-expose
close-expose:
	killall kubectl

# Step 6: load the shakespeare data via the elasticsearch API endpoint
.PHONY: load
load:
	$(ROOT)/load-shakespeare.sh

# Step 7: Valide the data via the elasticsearch API endpoint
.PHONY: validate
validate:
	$(ROOT)/validate.sh

# Step 8: Expose the UI on localhost:8080 via the laptop/desktop
.PHONY: expose-ui
expose-ui:
	$(ROOT)/expose-ui.sh

# Step 9: tear down kubernetes and the rest of GCP infrastructure used
.PHONY: teardown
teardown:
	$(ROOT)/teardown.sh
