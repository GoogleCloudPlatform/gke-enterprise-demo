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
  type = "string"
}

// Optional variables
variable "region_cloud" {
  default = "us-west1"
}

variable "region_on_prem" {
  default = "us-west1"
}

variable "zone_on_prem" {
  default = "us-west1-a"
}

variable "zone_on_prem_failover" {
  default = ["us-west1-b", "us-west1-c"]
}

variable "zone_cloud" {
  default = "us-west1-b"
}

variable "cloud" {
  description = "the cloud"
  type        = "map"

  default = {
    primary_range     = "10.1.0.0/17"
    secondary_range   = "10.1.128.0/17"
    destination_range = "10.2.0.0/16"
    machine_type      = "n1-standard-2"
  }
}

variable "on_prem" {
  description = "the on prem dc"
  type        = "map"

  default = {
    primary_range     = "10.2.0.0/17"
    secondary_range   = "10.2.128.0/17"
    destination_range = "10.1.0.0/16"
    machine_type      = "n1-standard-2"
  }
}

variable "gke_master_version" {
  default = "1.9.7-gke.7"
}
