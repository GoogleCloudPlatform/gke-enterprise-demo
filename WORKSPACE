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
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "35c585261362a96b1fe777a7c4c41252b22fd404f24483e1c48b15d7eb2b55a5",
    strip_prefix = "rules_docker-4282829a554058401f7ff63004c8870c8d35e29c",
    urls = ["https://github.com/bazelbuild/rules_docker/archive/4282829a554058401f7ff63004c8870c8d35e29c.tar.gz"],
)

load(
    "@io_bazel_rules_docker//docker:docker.bzl",
    "docker_repositories",
)

docker_repositories()

git_repository(
    name = "io_bazel_rules_k8s",
    commit = "62ae7911ef60f91ed32fdd48a6b837287a626a80",
    remote = "https://github.com/bazelbuild/rules_k8s.git",
)

load("@io_bazel_rules_k8s//k8s:k8s.bzl", "k8s_repositories", "k8s_defaults")

k8s_repositories()

_CLUSTER = "gke_pso-helmsman-cicd-infra_us-west1-b_cloud-cluster"
_CONTEXT = _CLUSTER
_NAMESPACE = "{BUILD_USER}"

k8s_defaults(
    name = "k8s_object",
    cluster = _CLUSTER,
    context = _CONTEXT,
    # image_chroot = "us.gcr.io/pso-helmsman-cicd-infra/",
    # namespace = _NAMESPACE,
)

k8s_defaults(
    name = "k8s_deploy",
    cluster = _CLUSTER,
    context = _CONTEXT,
    # image_chroot = "us.gcr.io/pso-helmsman-cicd-infra/",
    kind = "deployment",
    # namespace = _NAMESPACE,
)

k8s_defaults(
    name = "k8s_service",
    cluster = _CLUSTER,
    context = _CONTEXT,
    # image_chroot = "us.gcr.io/pso-helmsman-cicd-infra/",
    kind = "deployment",
    # namespace = _NAMESPACE,
)

# Standard bazel golang support
http_archive(
    name = "io_bazel_rules_go",
    url = "https://github.com/bazelbuild/rules_go/releases/download/0.15.3/rules_go-0.15.3.tar.gz",
    sha256 = "97cf62bdef33519412167fd1e4b0810a318a7c234f5f8dc4f53e2da86241c492",
)
load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
go_rules_dependencies()
go_register_toolchains()

# gazelle rules
http_archive(
    name = "bazel_gazelle",
    url = "https://github.com/bazelbuild/bazel-gazelle/releases/download/0.14.0/bazel-gazelle-0.14.0.tar.gz",
    sha256 = "c0a5739d12c6d05b6c1ad56f2200cb0b57c5a70e03ebd2f7b87ce88cabf09c7b",
)

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")
gazelle_dependencies()

# bazel rules for docker
http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "29d109605e0d6f9c892584f07275b8c9260803bf0c6fcb7de2623b2bedc910bd",
    strip_prefix = "rules_docker-0.5.1",
    urls = ["https://github.com/bazelbuild/rules_docker/archive/v0.5.1.tar.gz"],
)

load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_pull",
    container_repositories = "repositories",
)

container_repositories()

# bazel go image rules
load(
    "@io_bazel_rules_docker//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()

# external dependencies
go_repository(
    name = "com_google_cloud_go",
    importpath = "cloud.google.com/go",
    tag = "v0.25.0",
)

go_repository(
    name = "io_opencensus_go",
    importpath = "go.opencensus.io",
    tag = "v0.17.0",
)

go_repository(
    name = "com_github_tidwall_gjson",
    importpath = "github.com/tidwall/gjson",
    tag = "v1.1.3",
)

go_repository(
    name = "io_opencensus_go_contrib_exporter_stackdriver",
    importpath = "contrib.go.opencensus.io/exporter/stackdriver",
    tag = "v0.6.0",
)

go_repository(
    name = "org_golang_google_api",
    importpath = "google.golang.org/api",
    commit = "e5ba110cb6cd042d05ea6ea2ce9dd13198c6387a",
)

go_repository(
    name = "org_golang_x_oauth2",
    importpath = "golang.org/x/oauth2",
    commit = "d2e6202438beef2727060aa7cabdd924d92ebfd9",
)

go_repository(
    name = "com_github_tidwall_match",
    importpath = "github.com/tidwall/match",
    commit = "1731857f09b1f38450e2c12409748407822dc6be",
)

go_repository(
    name = "com_github_googleapis_gax_go",
    importpath = "github.com/googleapis/gax-go",
    commit = "1ef592c90f479e3ab30c6c2312e20e13881b7ea6",
)

go_repository(
    name = "com_github_aws_aws_sdk_go",
    importpath = "github.com/aws/aws-sdk-go",
    tag = "v1.15.42",
)

go_repository(
    name = "org_golang_x_sync",
    importpath = "golang.org/x/sync",
    commit = "1d60e4601c6fd243af51cc01ddf169918a5407ca",
)

go_repository(
    name = "org_golang_x_sys_unix",
    importpath = "golang.org/x/sys/unix",
    commit = "af653ce8b74f808d092db8ca9741fbb63d2a469d",
    )

go_repository(
    name = "org_golang_google_grpc",
    importpath = "google.golang.org/grpc",
    tag = "v1.15.1",
)
