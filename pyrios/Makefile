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


VET_REPORT = vet.report
TEST_REPORT = tests.xml

VERSION?=?
COMMIT=$(shell git rev-parse HEAD)
BRANCH=$(shell git rev-parse --abbrev-ref HEAD)

# This repo's root import path (under GOPATH).

# Setup the -ldflags option for go build here, interpolate the variable values
LDFLAGS = -ldflags "-X main.VERSION=${VERSION} -X main.COMMIT=${COMMIT} -X main.BRANCH=${BRANCH}"


###
### These variables should not need tweaking.
###

# Build the project
all: container  container-pso clean test vet pyrios deps
.PHONY: container  container-pso clean test vet pyrios deps

deps:
	go get -u "cloud.google.com/go/logging" "go.opencensus.io"

pyrios:
	go build ${LDFLAGS} .

vet:
	go vet ./... > ${VET_REPORT} 2>&1

fmt:
	go fmt main.go

container:
	gcloud container builds submit --config=cloudbuild.yaml  .

container-pso:
	gcloud container builds submit --config=cloudbuild-pso.yaml  .


clean:
	-rm -f ${TEST_REPORT}
	-rm -f ${VET_REPORT}
	-rm -f ${BINARY}-*