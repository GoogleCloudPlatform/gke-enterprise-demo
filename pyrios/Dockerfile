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

FROM golang:1.10.1 AS build
WORKDIR /go/src/app
COPY . .
RUN go get -d && CGO_ENABLE=0 GOOS=linux GOARCH=amd64 go build -o pyrios -v .

FROM debian:stretch-slim
# hadolint ignore=DL3008
RUN \
    apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates \
    && useradd -ms /bin/bash -U app \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER app
WORKDIR /home/app
COPY --chown=app --from=build /go/src/app/pyrios .
EXPOSE  9200
ENTRYPOINT ["/home/app/pyrios"]