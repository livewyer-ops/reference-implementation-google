data "google_container_cluster" "target" {
  name = var.cluster_name
}

data "google_dns_managed_zone" "selected" {
  count = local.dns_count
  name  = local.hosted_zone_id
}

data "google_organization" "current" {
  organization = var.org_id
}

data "google_project" "current" {
  project_id = var.project
}
