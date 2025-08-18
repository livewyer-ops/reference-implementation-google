module "crossplane_gcp_provider_role" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 35.0.1"

  project_id = var.project
  name       = "provider-gcp"
  namespace  = "crossplane-system"
  roles      = ["roles/owner"]

  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
}

resource "kubectl_manifest" "application_argocd_crossplane" {
  yaml_body = templatefile("${path.module}/templates/argocd-apps/crossplane.yaml", {
    GITHUB_URL = local.repo_url
    }
  )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd application/crossplane --timeout=600s &&  kubectl wait --for=jsonpath=.status.sync.status=Synced --timeout=600s -n argocd application/crossplane"

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy

    command     = "./uninstall.sh"
    working_dir = "${path.module}/scripts/crossplane"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "kubectl_manifest" "crossplane_provider_controller_config" {
  depends_on = [
    kubectl_manifest.application_argocd_crossplane,
  ]
  yaml_body = templatefile("${path.module}/templates/manifests/crossplane-gcp-controller-config.yaml", {
    GCP_ROLE = module.crossplane_gcp_provider_role.gcp_service_account_email
    }
  )
}

resource "kubectl_manifest" "application_argocd_crossplane_provider" {
  depends_on = [
    kubectl_manifest.application_argocd_crossplane,
  ]
  yaml_body = templatefile("${path.module}/templates/argocd-apps/crossplane-provider.yaml", {
    GITHUB_URL = local.repo_url
    }
  )
}
