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

// Provisions an elasticsearch cluster in GKE (simulates on prem) and cloud GKE cluster

// https://cloud.google.com/vpn/docs/concepts/choosing-networks-routing
// Policy based routing is chosen for the demo

// https://cloud.google.com/vpn/docs/how-to/creating-policy-based-vpns
// Reserve regional external (static) IP addresses
resource "google_compute_address" "public_ip_1" {
  name   = "public-ip-1"
  region = "${var.region_cloud}"
}

resource "google_compute_address" "public_ip_2" {
  name   = "public-ip-2"
  region = "${var.region_on_prem}"
}

// invokes a module to create a policy based VPN, custom network/subnet, firewall rules as Cloud
module "cloud" {
  source            = "modules/datacenter"
  network_name      = "cloud"
  subnet_region     = "${var.region_cloud}"
  primary_range     = "${lookup(var.cloud, "primary_range")}"
  secondary_range   = "${lookup(var.cloud, "secondary_range")}"
  vpn_ip            = "${google_compute_address.public_ip_1.address}"
  peer_ip           = "${google_compute_address.public_ip_2.address}"
  destination_range = "${lookup(var.cloud, "destination_range")}"
  shared_secret     = "${var.shared_secret}"
}

// invokes a module to create policy based VPN, custom network/subnet, firewall rules as
// on prem data center
module "on-prem" {
  source            = "modules/datacenter"
  network_name      = "on-prem"
  subnet_region     = "${var.region_on_prem}"
  primary_range     = "${lookup(var.on_prem, "primary_range")}"
  secondary_range   = "${lookup(var.on_prem, "secondary_range")}"
  vpn_ip            = "${google_compute_address.public_ip_2.address}"
  peer_ip           = "${google_compute_address.public_ip_1.address}"
  destination_range = "${lookup(var.on_prem, "destination_range")}"
  shared_secret     = "${var.shared_secret}"
}

// Provides access to available Google Container Engine versions in a zone for a given project.
// https://www.terraform.io/docs/providers/google/d/google_container_engine_versions.html
data "google_container_engine_versions" "on-prem" {
  zone    = "${var.zone_on_prem}"
  project = "${var.project}"
}

// Creates a Google Kubernetes Engine (GKE) cluster for the on premise data center
// https://www.terraform.io/docs/providers/google/r/container_cluster.html
resource "google_container_cluster" "on-prem-cluster" {
  name = "on-prem-cluster"

  zone             = "${var.zone_on_prem}"
  additional_zones = "${var.zone_on_prem_failover}"

  network = "${module.on-prem.network}"

  subnetwork         = "${module.on-prem.subnetwork}"
  initial_node_count = 1

  min_master_version = "${data.google_container_engine_versions.on-prem.latest_master_version}"

  ip_allocation_policy {
    cluster_secondary_range_name = "${module.on-prem.secondary_range_name}"
  }

  node_config {
    machine_type = "${lookup(var.on_prem, "machine_type")}"

    // https://cloud.google.com/kubernetes-engine/docs/how-to/access-scopes
    // Enable private gcr.io read access for the same project
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO" // CALICO is currently the only supported provider
  }

  // Lifecycle is used for preventing destruction of the following resources when the terraform apply again
  lifecycle {
    ignore_changes = ["network", "subnetwork", "ip_allocation_policy.0.services_secondary_range_name"]
  }
}

data "google_container_engine_versions" "cloud" {
  zone    = "${var.zone_cloud}"
  project = "${var.project}"
}

// Creates a Google Kubernetes Engine (GKE) cluster for the cloud
// https://www.terraform.io/docs/providers/google/r/container_cluster.html
resource "google_container_cluster" "cloud-cluster" {
  name               = "cloud-cluster"
  zone               = "${var.zone_cloud}"
  network            = "${module.cloud.network}"
  subnetwork         = "${module.cloud.subnetwork}"
  initial_node_count = 1

  min_master_version = "${data.google_container_engine_versions.cloud.latest_master_version}"

  ip_allocation_policy {
    cluster_secondary_range_name = "${module.cloud.secondary_range_name}"
  }

  node_config {
    machine_type = "${lookup(var.cloud, "machine_type")}"

    // https://cloud.google.com/kubernetes-engine/docs/how-to/access-scopes
    // Enable private gcr.io read access for the same project
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO" // CALICO is currently the only supported provider
  }

  lifecycle {
    ignore_changes = ["network", "subnetwork", "ip_allocation_policy.0.services_secondary_range_name"]
  }
}

resource "google_bigquery_dataset" "log-sink-dataset" {
  dataset_id                  = "gke_elasticsearch_log_dataset"
  location                    = "US"
  default_table_expiration_ms = "3600000"

  labels {
    env = "default"
  }
}

resource "google_logging_project_sink" "bigquery-sink" {
  name                   = "gke-elasticsearch-log-sink"
  destination            = "bigquery.googleapis.com/projects/${var.project}/datasets/${google_bigquery_dataset.log-sink-dataset.dataset_id}"
  filter                 = "resource.type=container"
  unique_writer_identity = true
}

resource "google_project_iam_binding" "bigquery-sink-permissions" {
  role = "roles/bigquery.dataEditor"

  members = [
    "${google_logging_project_sink.bigquery-sink.writer_identity}",
  ]
}
