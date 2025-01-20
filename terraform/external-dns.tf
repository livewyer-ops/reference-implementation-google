module "external_dns_role" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 35.0.1"

  count = local.dns_count

  project_id = var.project
  name       = "external-dns"
  namespace  = "external-dns"
  roles      = ["roles/dns.admin"]

  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
}

resource "kubectl_manifest" "application_argocd_external_dns" {
  yaml_body = templatefile("${path.module}/templates/argocd-apps/external-dns.yaml", {
    GITHUB_URL  = local.repo_url
    GCP_SA_FQN  = module.external_dns_role[0].gcp_service_account_email
    DOMAIN_NAME = data.google_dns_managed_zone.selected[0].dns_name
    }
  )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy --timeout=300s -n argocd application/external-dns"

    interpreter = ["/bin/bash", "-c"]
  }
}
