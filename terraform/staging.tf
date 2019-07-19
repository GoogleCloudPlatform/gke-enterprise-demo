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

locals {
  resource_labels = merge(
    var.labels,
    {
      "owner" = data.external.account.result.gcloud_account
    },
  )
}

resource "google_compute_address" "staging_public_ip_1" {
  name   = "gke-enterprise-demo-cloud-public-ip-1"
  region = var.region_cloud
}

resource "google_compute_address" "staging_public_ip_2" {
  name   = "gke-enterprise-demo-cloud-public-ip-2"
  region = var.region_on_prem
}

// STAGING: invokes a module to create a policy based VPN, custom network/subnet, firewall rules as Cloud
module "staging_cloud" {
  source            = "./modules/datacenter"
  project           = var.project
  network_name      = "gke-enterprise-demo-staging-cloud"
  subnet_region     = var.region_cloud
  primary_range     = var.cloud["primary_range"]
  secondary_range   = var.cloud["secondary_range"]
  vpn_ip            = google_compute_address.staging_public_ip_1.address
  peer_ip           = google_compute_address.staging_public_ip_2.address
  destination_range = var.cloud["destination_range"]
  shared_secret     = random_string.staging_shared_secret.result
}

// invokes a module to create policy based VPN, custom network/subnet, firewall rules as
// STAGING: on prem data center
module "staging_on_prem" {
  source            = "./modules/datacenter"
  project           = var.project
  network_name      = "gke-enterprise-demo-staging-on-prem"
  subnet_region     = var.region_on_prem
  primary_range     = var.on_prem["primary_range"]
  secondary_range   = var.on_prem["secondary_range"]
  vpn_ip            = google_compute_address.staging_public_ip_2.address
  peer_ip           = google_compute_address.staging_public_ip_1.address
  destination_range = var.on_prem["destination_range"]
  shared_secret     = random_string.staging_shared_secret.result
}

// Creates a Google Kubernetes Engine (GKE) cluster for the on premise data center
// https://www.terraform.io/docs/providers/google/r/container_cluster.html
resource "google_container_cluster" "staging_on_prem_cluster" {
  name    = "gke-enterprise-staging-on-prem-cluster"
  project = var.project

  zone             = var.zone_on_prem
  additional_zones = var.zone_on_prem_failover

  network = module.staging_on_prem.network

  subnetwork         = module.staging_on_prem.subnetwork
  initial_node_count = 1

  min_master_version = var.gke_master_version

  resource_labels = local.resource_labels

  ip_allocation_policy {
    cluster_secondary_range_name = module.staging_on_prem.secondary_range_name
  }

  remove_default_node_pool = true

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
    ignore_changes = [
      network,
      subnetwork,
      "ip_allocation_policy[0].services_secondary_range_name",
    ]
  }

  timeouts {
    create = "30m"
    update = "40m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "staging_on_prem_cluster" {
  name    = "gke-enterprise-staging-on-prem-node-pool"
  project = var.project

  cluster    = google_container_cluster.staging_on_prem_cluster.name
  zone       = var.zone_on_prem
  node_count = 1

  node_config {
    machine_type = var.on_prem["machine_type"]

    // https://cloud.google.com/kubernetes-engine/docs/how-to/access-scopes
    // Enable private gcr.io read access for the same project
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  lifecycle {
    ignore_changes = [
      id,
      "node_config[0].metadata",
    ]
  }
}

// Creates a Google Kubernetes Engine (GKE) cluster for the cloud
// https://www.terraform.io/docs/providers/google/r/container_cluster.html
resource "google_container_cluster" "staging_cloud_cluster" {
  name               = "gke-enterprise-staging-cloud-cluster"
  zone               = var.zone_cloud
  network            = module.staging_cloud.network
  subnetwork         = module.staging_cloud.subnetwork
  initial_node_count = 1

  min_master_version = var.gke_master_version

  resource_labels = local.resource_labels

  ip_allocation_policy {
    cluster_secondary_range_name = module.staging_cloud.secondary_range_name
  }

  remove_default_node_pool = true
  /* initial_node_count       = 1 */

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
    ignore_changes = [
      network,
      subnetwork,
      "ip_allocation_policy[0].services_secondary_range_name",
    ]
  }

  timeouts {
    create = "30m"
    update = "40m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "staging_cloud_cluster" {
  name       = "gke-enterprise-staging-cloud-node-pool"
  project    = var.project
  cluster    = google_container_cluster.staging_cloud_cluster.name
  zone       = var.zone_cloud
  node_count = 1

  node_config {
    machine_type = var.cloud["machine_type"]

    // https://cloud.google.com/kubernetes-engine/docs/how-to/access-scopes
    // Enable private gcr.io read access for the same project
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    ignore_changes = [
      id,
      "node_config[0].metadata",
    ]
  }
}

resource "google_bigquery_dataset" "staging-log-sink-dataset" {
  dataset_id                  = "staging_gke_elasticsearch_log_dataset"
  project                     = var.project
  location                    = "US"
  default_table_expiration_ms = "3600000"

  labels = {
    env = "default"
  }
}

resource "google_logging_project_sink" "staging-bigquery-sink" {
  name                   = "gke-enterprise-demo-staging-gke-elasticsearch-log-sink"
  project                = var.project
  destination            = "bigquery.googleapis.com/projects/${var.project}/datasets/${google_bigquery_dataset.staging-log-sink-dataset.dataset_id}"
  filter                 = "resource.type=container"
  unique_writer_identity = true
}

resource "google_project_iam_binding" "staging_bigquery-sink-permissions" {
  project = var.project
  role    = "roles/bigquery.dataEditor"

  members = [
    google_logging_project_sink.staging-bigquery-sink.writer_identity,
  ]
}

resource "random_string" "staging_shared_secret" {
  length      = 32
  special     = true
  min_special = 6
  min_upper   = 8
}
