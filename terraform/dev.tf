// DEV_CLOUD: invokes a module to create a policy based VPN, custom network/subnet, firewall rules as Cloud
module "dev_cloud" {
  source            = "modules/datacenter"
  project           = "${var.project}"
  network_name      = "dev-cloud"
  subnet_region     = "${var.region_cloud}"
  primary_range     = "${lookup(var.cloud, "primary_range")}"
  secondary_range   = "${lookup(var.cloud, "secondary_range")}"
  vpn_ip            = "${google_compute_address.dev_public_ip_1.address}"
  peer_ip           = "${google_compute_address.dev_public_ip_2.address}"
  destination_range = "${lookup(var.cloud, "destination_range")}"
  shared_secret     = "${random_string.dev_shared_secret.result}"
}

// invokes a module to create policy based VPN, custom network/subnet, firewall rules as
// DEV_CLOUD: on prem data center
module "dev_on_prem" {
  source            = "modules/datacenter"
  project           = "${var.project}"
  network_name      = "dev-on-prem"
  subnet_region     = "${var.region_on_prem}"
  primary_range     = "${lookup(var.on_prem, "primary_range")}"
  secondary_range   = "${lookup(var.on_prem, "secondary_range")}"
  vpn_ip            = "${google_compute_address.dev_public_ip_2.address}"
  peer_ip           = "${google_compute_address.dev_public_ip_1.address}"
  destination_range = "${lookup(var.on_prem, "destination_range")}"
  shared_secret     = "${random_string.dev_shared_secret.result}"
}

resource "google_compute_address" "dev_public_ip_1" {
  name   = "dev-public-ip-1"
  region = "${var.region_cloud}"
}

resource "google_compute_address" "dev_public_ip_2" {
  name   = "dev-public-ip-2"
  region = "${var.region_on_prem}"
}

// Creates a Google Kubernetes Engine (GKE) cluster for the on premise data center
// https://www.terraform.io/docs/providers/google/r/container_cluster.html
resource "google_container_cluster" "dev_on_prem_cluster" {
  name    = "dev-on-prem-cluster"
  project = "${var.project}"

  zone             = "${var.zone_on_prem}"
  additional_zones = "${var.zone_on_prem_failover}"

  network = "${module.dev_on_prem.network}"

  subnetwork         = "${module.dev_on_prem.subnetwork}"
  initial_node_count = 1

  min_master_version = "${data.google_container_engine_versions.gke_version.latest_master_version}"

  ip_allocation_policy {
    cluster_secondary_range_name = "${module.dev_on_prem.secondary_range_name}"
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

resource "google_container_cluster" "dev_cloud_cluster" {
  name               = "dev-cloud-cluster"
  zone               = "${var.zone_cloud}"
  network            = "${module.dev_cloud.network}"
  subnetwork         = "${module.dev_cloud.subnetwork}"
  initial_node_count = 1

  min_master_version = "${data.google_container_engine_versions.gke_version.latest_master_version}"

  ip_allocation_policy {
    cluster_secondary_range_name = "${module.dev_cloud.secondary_range_name}"
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

resource "google_bigquery_dataset" "dev-log-sink-dataset" {
  dataset_id                  = "dev_gke_elasticsearch_log_dataset"
  project                     = "${var.project}"
  location                    = "US"
  default_table_expiration_ms = "3600000"

  labels {
    env = "default"
  }
}

resource "google_logging_project_sink" "dev-bigquery-sink" {
  name                   = "dev-gke-elasticsearch-log-sink"
  project                = "${var.project}"
  destination            = "bigquery.googleapis.com/projects/${var.project}/datasets/${google_bigquery_dataset.dev-log-sink-dataset.dataset_id}"
  filter                 = "resource.type=container"
  unique_writer_identity = true
}

resource "google_project_iam_binding" "dev_bigquery-sink-permissions" {
  project = "${var.project}"
  role    = "roles/bigquery.dataEditor"

  members = [
    "${google_logging_project_sink.dev-bigquery-sink.writer_identity}",
  ]
}

resource "random_string" "dev_shared_secret" {
  length      = 32
  special     = true
  min_special = 6
  min_upper   = 8
}
