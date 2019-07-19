/*
Copyright 2018 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Required variables
variable "project" {
  type = string
}

// Optional variables
variable "region_cloud" {
  default = "us-central1"
}

variable "region_on_prem" {
  default = "us-central1"
}

variable "zone_on_prem" {
  default = "us-central1-a"
}

variable "zone_on_prem_failover" {
  type    = list(string)
  default = ["us-central1-b", "us-central1-c"]
}

variable "zone_cloud" {
  default = "us-central1-a"
}

variable "cloud" {
  description = "the cloud"
  type        = map(string)

  default = {
    primary_range     = "10.1.0.0/17"
    secondary_range   = "10.1.128.0/17"
    destination_range = "10.2.0.0/16"
    machine_type      = "n1-standard-2"
  }
}

variable "on_prem" {
  description = "the on prem dc"
  type        = map(string)

  default = {
    primary_range     = "10.2.0.0/17"
    secondary_range   = "10.2.128.0/17"
    destination_range = "10.1.0.0/16"
    machine_type      = "n1-standard-4"
  }
}

variable "gke_master_version" {
  default = "latest"
}

// this map should be set should more labels be required to identify the container clusters and node groups
variable "labels" {
  type    = map(string)
  default = {}
}
