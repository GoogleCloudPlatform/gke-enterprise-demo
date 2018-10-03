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

variable "network_name" {
  type = "string"
}

variable "subnet_region" {
  type = "string"
}

variable "primary_range" {
  type = "string"
}

variable "secondary_range" {
  type = "string"
}

// regional external (static) IP address:
// https://cloud.google.com/vpn/docs/how-to/creating-policy-based-vpns
variable "vpn_ip" {
  type = "string"
}

variable "peer_ip" {
  type = "string"
}

variable "destination_range" {
  type = "string"
}

variable "shared_secret" {
  type = "string"
}
