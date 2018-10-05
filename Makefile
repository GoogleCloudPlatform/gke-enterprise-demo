#!/usr/bin/env bash
# set -o errexit
# set -o nounset

PROJECT:=$(shell gcloud config get-value core/project)
ROOT:=.

# we're building images based on [distroless](https://github.com/GoogleContainerTools/distroless) are so minimal
# that they don't have a shell to exec into which makes it difficult to do traditional k8s debugging
# this option includes busybox but should be omitted for production
DEBUG?=-c dbg

# add any bazel build options here
BAZEL_OPTIONS?=

################################################################################################
#                      Verification/testing helpers                                            #
################################################################################################

# All is the first target in the file so it will get picked up when you just run 'make' on its own
.PHONY: lint
lint: check_shell check_python check_gofmt check_terraform check_docker check_base_files check_trailing_whitespace check_headers

# The .PHONY directive tells make that this isn't a real target and so
# the presence of a file named 'check_shell' won't cause this target to stop
# working
.PHONY: check_shell
check_shell:
	@source test/make.sh && check_shell

.PHONY: check_python
check_python:
	@source test/make.sh && check_python

.PHONY: check_gofmt
check_gofmt:
	@test/verify-gofmt.sh

.PHONY: gofmt
gofmt:
	gofmt -s -w pyrios-ui/
	gofmt -s -w pyrios/


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
	python test/verify_boilerplate.py


################################################################################################
#             Infrastructure bootstrapping and mgmt helpers                                    #
################################################################################################

# 1: Sets up some of the prerequisite APIs that will be needed to interact with GCP in this demo
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

# 2: Terraform is used to manage the larger infrastructure components
.PHONY: terraform
terraform:
	terraform init terraform/
	terraform validate -check-variables=false terraform/
	terraform plan -var "project=$(PROJECT)" -out=tfplan terraform/
	terraform apply tfplan

# 3. We will not be checking secrets into version control. This helps manage that process
.PHONY: config
config:
	$(ROOT)/scripts/configure.sh

# 4: Deploys kubernetes resources. ie: elasticsearch, pyrios and pyrios-ui
# todo: migrate this to bazel. (pyrios and ui)
.PHONY: create
create:
	$(ROOT)/scripts/create.sh


# 5: Exposes the elasticsearch endpoint to your workstation so that you can seed the demo data
.PHONY: expose
expose:
	$(ROOT)/scripts/expose.sh

# 6: Seeds the demo data via the proxy exposed in 5
.PHONY: load
load:
	$(ROOT)/scripts/load-shakespeare.sh

# 7: Validate that the data was properly seeded into ES
.PHONY: validate
validate:
	$(ROOT)/scripts/validate.sh

# 7: Disconnect proxy. You'll have to run this in a separate window/terminal. Alternatively, press control-C
.PHONY: close-expose
close-expose:
	killall kubectl

# 8: Expose the pyrios UI so that you can navigate to the site on localhost:8080
.PHONY: expose-ui
expose-ui:
	$(ROOT)/scripts/expose-ui.sh

# The elasticsearch portion of the demo is complete. You're welcome to tear
# down your infrastructure right now, or if you skip the teardown, you can
# start experimenting with bazel!

# 9: (OPTIONAL) Delete k8s clusters and associated infrastructure and go back to a blank slate.
.PHONY: teardown
teardown:
	$(ROOT)/scripts/teardown.sh

################################################################################################
#                      pyrios/pyrios-ui                                                        #
################################################################################################

.PHONY: bazel-clean
bazel-clean:
	bazel clean --expunge

.PHONY: bazel-test
bazel-test:
	bazel ${BAZEL_OPTIONS} test \
	--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
			--define REGISTRY=gcr.io \
		--define REPOSITORY=pyrios \
		--define TAG=latest \
	//pyrios/... //pyrios-ui/... //test:verify-all --test_output=errors

# build for your host OS, for local development/testing (not in docker)
.PHONY: bazel-build-pyrios
bazel-build-pyrios:
	bazel build ${BAZEL_OPTIONS} --features=pure //pyrios/...

.PHONY: bazel-build-pyrios-ui
bazel-build-pyrios-ui:
	bazel build ${BAZEL_OPTIONS} --features=pure //pyrios-ui/...

.PHONY: bazel-build
bazel-build: bazel-build-pyrios bazel-build-pyrios-ui

.PHONY: bazel-build-pyrios-image
bazel-build-pyrios-image:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
		--define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_REPO} \
		--define TAG=${PYRIOS_TAG} \
		//pyrios:

.PHONY: bazel-build-pyrios-ui-image
bazel-build-pyrios-ui-image:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
		--define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_UI_REPO} \
		--define TAG=${PYRIOS_UI_TAG} \
		//pyrios-ui:go_image

.PHONY: bazel-build-images
bazel-build-images: bazel-build-pyrios-image bazel-build-pyrios-ui-image

.PHONY: bazel-push-pyrios
bazel-push-pyrios:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
		--define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_REPO} \
		--define TAG=${PYRIOS_TAG} \
		//pyrios:push

.PHONY: bazel-push-pyrios-ui
bazel-push-pyrios-ui:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
        --define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_UI_REPO} \
		--define TAG=${PYRIOS_UI_TAG} \
		//pyrios-ui:push

.PHONY: bazel-push-images
bazel-push-images: bazel-push-pyrios bazel-push-pyrios-ui
