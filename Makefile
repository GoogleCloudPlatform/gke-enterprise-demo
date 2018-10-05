# shellcheck disable=SC2148

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
	# --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
	//pyrios/... //pyrios-ui/... //test:verify-all --test_output=errors




# build for your host OS, for local development/testing (not in docker)
# todo: do we want these?? i believe we'd have to set up go_binary targets
# .PHONY: bazel-build-pyrios
# bazel-build-pyrios:
# 	bazel build ${BAZEL_OPTIONS} --features=pure //pyrios/...

# .PHONY: bazel-build-pyrios-ui
# bazel-build-pyrios-ui:
# 	bazel build ${BAZEL_OPTIONS} --features=pure //pyrios-ui/...

# .PHONY: bazel-build
# bazel-build: bazel-build-pyrios bazel-build-pyrios-ui



.PHONY: bazel-build-pyrios-image
bazel-build-pyrios-image:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		//pyrios:app_image

.PHONY: bazel-build-pyrios-ui-image
bazel-build-pyrios-ui-image:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		//pyrios-ui:app_image

.PHONY: bazel-build-images
bazel-build-images: bazel-build-pyrios-image bazel-build-pyrios-ui-image

# todo: we're currently accessing this functionality via rules_k8s
# .PHONY: bazel-push-pyrios
# bazel-push-pyrios:
# 	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
# 		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
# 		//pyrios:staging

# .PHONY: bazel-push-pyrios-ui
# bazel-push-pyrios-ui:
# 	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
# 		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
# 		//pyrios-ui:staging

# .PHONY: bazel-push-images
# bazel-push-images: bazel-push-pyrios bazel-push-pyrios-ui


# this is sort of like a standard kubernetes dry run - except that it pushes
# the image to the repo. it will print out the manifests to the terminal
.PHONY: bazel-publish-pyrios-image
bazel-publish-pyrios-image:
	bazel run //pyrios:staging

.PHONY: bazel-publish-pyrios-ui-image
bazel-publish-pyrios-ui-image:
	bazel run //pyrios-ui:staging

.PHONY: bazel-publish-images
bazel-publish-images: bazel-publish-pyrios-image bazel-publish-pyrios-ui-image


# this is publishing a k8s_object- which allows you to bundle arbitrary
# kube resources together. for example, the sevice with deploymnent
.PHONY: bazel-deploy-pyrios
bazel-deploy-pyrios:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		//pyrios:staging.apply

.PHONY: bazel-deploy-pyrios-ui
bazel-deploy-pyrios-ui:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		//pyrios-ui:staging.apply

.PHONY: bazel-deploy-pyrios-all
bazel-deploy-pyrios-all:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		//pyrios:staging.apply //pyrios-ui:staging.apply

# delete your pyrios resources from kubernetes
.PHONY: bazel-delete-pyrios
bazel-delete-pyrios:
	bazel run ${BAZEL_OPTIONS} //pyrios:staging.delete

.PHONY: bazel-delete-pyrios-ui
bazel-delete-pyrios-ui:
	bazel run ${BAZEL_OPTIONS} //pyrios-ui:staging.delete

.PHONY: bazel-delete-pyrios-all
bazel-delete-pyrios-all:
	bazel run ${BAZEL_OPTIONS} //pyrios:staging.delete 	//pyrios-ui:staging.delete

################################################################################################
#                                 kubernetes helpers                                           #
################################################################################################

# this works off of the old static manifests
.PHONY: deploy
deploy:
	kubectl apply -f pyrios/manifests/
	kubectl apply -f pyrios-ui/manifests/

