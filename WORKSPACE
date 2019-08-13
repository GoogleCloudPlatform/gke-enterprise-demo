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

# java
http_archive(
    name = "rules_java",
    url = "https://github.com/bazelbuild/rules_java/releases/download/0.1.0/rules_java-0.1.0.tar.gz",
    sha256 = "52423cb07384572ab60ef1132b0c7ded3a25c421036176c0273873ec82f5d2b2",
)
load("@rules_java//java:repositories.bzl", "rules_java_dependencies", "rules_java_toolchains")

rules_java_dependencies()
rules_java_toolchains()

# skylib
http_archive(
    name = "bazel_skylib",
    url = "https://github.com/bazelbuild/bazel-skylib/releases/download/0.8.0/bazel-skylib.0.8.0.tar.gz",
    sha256 = "2ef429f5d7ce7111263289644d233707dba35e39696377ebab8b0bc701f7818e",
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
bazel_skylib_workspace()

# docker
http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "e513c0ac6534810eb7a14bf025a0f159726753f97f74ab7863c650d26e01d677",
    strip_prefix = "rules_docker-0.9.0",
    urls = ["https://github.com/bazelbuild/rules_docker/archive/v0.9.0.tar.gz"],
)

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)
container_repositories()

## 54e9742bd2b75facdcf30fe3a1307ca0fad17385 is master@latest
git_repository(
    name = "io_bazel_rules_k8s",
    commit = "57e764abebb36a0f3fe0bb8d8d1a89bc489665cf",
    remote = "https://github.com/bazelbuild/rules_k8s.git",
    shallow_since = "1565634587 -0400",
)

load("@io_bazel_rules_k8s//k8s:k8s.bzl", "k8s_repositories", "k8s_defaults")
load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")

k8s_repositories()

k8s_defaults(
    name = "k8s_object",
)

k8s_defaults(
    name = "k8s_deploy",
    kind = "deployment",
    namespace = "default",
)

[k8s_defaults(
    name = "k8s_" + kind,
    namespace = "default",
    kind = kind,
) for kind in [
    "service",
    "configmap",
]]

# Override protbuf version to bypass compilation error
# cf. https://github.com/bazelbuild/rules_k8s/issues/240
http_archive(
    name = "com_google_protobuf",
    #strip_prefix = "protobuf-3.9.1",
    #urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.9.1.tar.gz"],
    #sha256 = "98e615d592d237f94db8bf033fba78cd404d979b0b70351a9e5aaff725398357",
    #sha256 = "",
    strip_prefix = "protobuf-3.6.1.3",
    urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.6.1.3.tar.gz"],
    sha256 = "73fdad358857e120fd0fa19e071a96e15c0f23bb25f85d3f7009abfd4f264a2a",
)

# Standard bazel golang support
http_archive(
    name = "io_bazel_rules_go",
    url = "https://github.com/bazelbuild/rules_go/releases/download/0.19.1/rules_go-0.19.1.tar.gz",
    sha256 = "8df59f11fb697743cbb3f26cfb8750395f30471e9eabde0d174c3aebc7a1cd39",
)
load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")
go_rules_dependencies()
go_register_toolchains()



# gazelle rules
http_archive(
    name = "bazel_gazelle",
    sha256 = "be9296bfd64882e3c08e3283c58fcb461fa6dd3c171764fcc4cf322f60615a9b",
    urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.18.1/bazel-gazelle-0.18.1.tar.gz"],
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
    tag = "v0.44.3",
)

go_repository(
    name = "io_opencensus_go",
    importpath = "go.opencensus.io",
    tag = "v0.22.0",
)

go_repository(
    name = "com_github_census_instrumentation_opencensus_proto",
    importpath = "github.com/census-instrumentation/opencensus-proto",
    commit = "d89fa54de508111353cb0b06403c00569be780d8", # v0.2.1
)

go_repository(
    name = "com_github_google_go_cmp",
    importpath = "github.com/google/go-cmp",
    commit = "2d0692c2e9617365a95b295612ac0d4415ba4627", # v0.3.1
)

go_repository(
   name = "org_golang_x_net",
   importpath = "golang.org/x/net", 
   commit = "b3c676e531a6dc479fa1b35ac961c13f5e2b4d2e", #
)

go_repository(
   name = "org_golang_x_unix",
   importpath = "golang.org/x/unix", 
)

go_repository(
    name = "org_golang_x_text",
    importpath = "github.com/golang/text",
    commit = "342b2e1fbaa52c93f31447ad2c6abc048c63e475",
)
#go_repository(
#   name = "org_golang_x_text",
#   importpath = "github.com/golang/text",
#   commit = "f21a4dfb5e38f5895301dc265a8def02365cc3d0", # v0.3.0
#   #commit = "c4d099d611ac3ded35360abf03581e13d91c828f", # v0.2.0
#   #commit = "ab5ac5f9a8deb4855a60fab02bc61a4ec770bd49", # v0.1.0
#)

go_repository(
   name = "org_golang_x_sys",
   importpath = "github.com/golang/sys", 
   commit = "fde4db37ae7ad8191b03d30d27f258b5291ae4e3", #
)

go_repository(
    name = "com_github_tidwall_gjson",
    importpath = "github.com/tidwall/gjson",
    tag = "v1.3.0",
)

go_repository(
    name = "io_opencensus_go_contrib_exporter_stackdriver",
    importpath = "contrib.go.opencensus.io/exporter/stackdriver",
    tag = "v0.12.5",
)

go_repository(
    name = "org_golang_google_api",
    importpath = "google.golang.org/api",
    commit = "dec2ee309f5b09fc59bc40676447c15736284d78",  # v0.8.0
)

go_repository(
    name = "org_golang_x_oauth2",
    importpath = "golang.org/x/oauth2",
    commit = "d2e6202438beef2727060aa7cabdd924d92ebfd9",
)

go_repository(
    name = "com_github_tidwall_match",
    importpath = "github.com/tidwall/match",
    commit = "33827db735fff6510490d69a8622612558a557ed",  # v1.0.1
)

go_repository(
    name = "com_github_tidwall_pretty",
    importpath = "github.com/tidwall/pretty",
    commit = "1166b9ac2b65e46a43d8618d30d1554f4652d49b", # v1.0.0
)

go_repository(
    name = "com_github_hashicorp_golang_lru",
    importpath = "github.com/hashicorp/golang-lru",
    commit = "7f827b33c0f158ec5dfbba01bb0b14a4541fd81d", # v0.5.3
)

go_repository(
    name = "com_github_googleapis_gax_go",
    importpath = "github.com/googleapis/gax-go",
    commit = "bd5b16380fd03dc758d11cef74ba2e3bc8b0e8c2",  # v2.0.5
)

go_repository(
    name = "com_github_aws_aws_sdk_go",
    importpath = "github.com/aws/aws-sdk-go",
    tag = "v1.23.0",
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
    tag = "v1.23.0",
)
