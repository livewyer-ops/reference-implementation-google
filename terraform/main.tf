
locals {
  repo_url       = trimsuffix(var.repo_url, "/")
  project        = var.project
  region         = var.region
  tags           = var.tags
  cluster_name   = var.cluster_name
  hosted_zone_id = var.hosted_zone_id
  dns_count      = var.enable_dns_management ? 1 : 0
  secret_count   = var.enable_external_secret ? 1 : 0

  domain_name           = var.enable_dns_management ? "${trimsuffix(data.google_dns_managed_zone.selected[0].dns_name, ".")}" : "${var.domain_name}"
  kc_domain_name        = "keycloak.${local.domain_name}"
  kc_cnoe_url           = "https://${local.kc_domain_name}/realms/cnoe"
  argo_domain_name      = "argo.${local.domain_name}"
  argo_redirect_url     = "https://${local.argo_domain_name}/oauth2/callback"
  argocd_domain_name    = "argocd.${local.domain_name}"
  backstage_domain_name = "backstage.${local.domain_name}"
}


provider "google" {
  project = local.project
  region  = local.region

  default_labels = local.tags
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
