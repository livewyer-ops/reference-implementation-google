
#---------------------------------------------------------------
# External Secrets for Keycloak if enabled
#---------------------------------------------------------------

module "external_secrets_role_keycloak" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 35.0.1"

  count = local.secret_count

  project_id = var.project
  name       = "external-secret-keycloak"
  namespace  = "keycloak"
  roles      = ["roles/secretmanager.secretAccessor"]

  use_existing_k8s_sa = true
  annotate_k8s_sa     = false

  module_depends_on = [kubernetes_manifest.namespace_keycloak[0]]
}

# should use gitops really.
resource "kubernetes_manifest" "namespace_keycloak" {
  count = local.secret_count

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Namespace"
    "metadata" = {
      "name" = "keycloak"
    }
  }
}

resource "kubernetes_manifest" "serviceaccount_external_secret_keycloak" {
  count = local.secret_count
  depends_on = [
    kubernetes_manifest.namespace_keycloak,
    kubectl_manifest.application_argocd_external_secrets,
    module.external_secrets_role_keycloak[0]
  ]

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "annotations" = {
        "iam.gke.io/gcp-service-account" = tostring(module.external_secrets_role_keycloak[0].gcp_service_account_email)
      }
      "name"      = "external-secret-keycloak"
      "namespace" = "keycloak"
    }
  }
}

resource "google_secret_manager_secret" "keycloak_config" {
  count = local.secret_count

  secret_id = "cnoe-keycloak-config"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "keycloak_config" {
  count = local.secret_count

  secret = google_secret_manager_secret.keycloak_config[0].id

  secret_data = jsonencode({
    KC_HOSTNAME             = local.kc_domain_name
    KEYCLOAK_ADMIN_PASSWORD = random_password.keycloak_admin_password.result
    POSTGRES_PASSWORD       = random_password.keycloak_postgres_password.result
    POSTGRES_DB             = "keycloak"
    POSTGRES_USER           = "keycloak"
    "user1-password"        = random_password.keycloak_user_password.result
  })
}

resource "kubectl_manifest" "keycloak_secret_store" {
  depends_on = [
    kubectl_manifest.application_argocd_external_secrets,
  ]

  yaml_body = templatefile("${path.module}/templates/manifests/keycloak-secret-store.yaml", {
    PROJECT_ID   = var.project
    KSA          = "external-secret-keycloak"
    GCP_LOCATION = local.region
    GKE_CLUSTER  = local.cluster_name
    }
  )
}

#---------------------------------------------------------------
# Keycloak secrets if external secrets is not enabled
#---------------------------------------------------------------

resource "kubernetes_manifest" "secret_keycloak_keycloak_config" {
  count = local.secret_count == 1 ? 0 : 1

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "keycloak-config"
      "namespace" = "keycloak"
    }
    "data" = {
      "KC_HOSTNAME"             = "${base64encode(local.kc_domain_name)}"
      "KEYCLOAK_ADMIN_PASSWORD" = "${base64encode(random_password.keycloak_admin_password.result)}"
    }
  }
}

resource "kubernetes_manifest" "secret_keycloak_postgresql_config" {
  count = local.secret_count == 1 ? 0 : 1

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "postgresql-config"
      "namespace" = "keycloak"
    }
    "data" = {
      "POSTGRES_DB"       = "${base64encode("keycloak")}"
      "POSTGRES_PASSWORD" = "${base64encode(random_password.keycloak_postgres_password.result)}"
      "POSTGRES_USER"     = "${base64encode("keycloak")}"
    }
  }
}

resource "kubernetes_manifest" "secret_keycloak_keycloak_user_config" {
  count = local.secret_count == 1 ? 0 : 1

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "keycloak-user-config"
      "namespace" = "keycloak"
    }
    "data" = {
      "user1-password" = "${base64encode(random_password.keycloak_user_password.result)}"
    }
  }
}

#---------------------------------------------------------------
# Keycloak passwords
#---------------------------------------------------------------

resource "random_password" "keycloak_admin_password" {
  length           = 48
  special          = false
  override_special = "!#?"
}

resource "random_password" "keycloak_user_password" {
  length           = 48
  special          = false
  override_special = "!#?"
}

resource "random_password" "keycloak_postgres_password" {
  length           = 48
  special          = false
  override_special = "!#?"
}

#---------------------------------------------------------------
# Keycloak installation
#---------------------------------------------------------------

resource "kubectl_manifest" "application_argocd_keycloak" {
  depends_on = [
    kubectl_manifest.keycloak_secret_store,
    kubectl_manifest.application_argocd_ingress_nginx
  ]

  yaml_body = templatefile("${path.module}/templates/argocd-apps/keycloak.yaml", {
    GITHUB_URL = local.repo_url
    PATH       = "${local.secret_count == 1 ? "packages/keycloak/dev-external-secrets/" : "packages/keycloak/dev/"}"
    }
  )

  provisioner "local-exec" {
    command = "./install.sh '${random_password.keycloak_user_password.result}' '${random_password.keycloak_admin_password.result}'"

    working_dir = "${path.module}/scripts/keycloak"
    interpreter = ["/bin/bash", "-c"]
  }
  provisioner "local-exec" {
    when    = destroy
    command = "./uninstall.sh"

    working_dir = "${path.module}/scripts/keycloak"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "kubectl_manifest" "ingress_keycloak" {
  depends_on = [
    kubectl_manifest.application_argocd_keycloak,
  ]

  yaml_body = templatefile("${path.module}/templates/manifests/ingress-keycloak.yaml", {
    KEYCLOAK_DOMAIN_NAME = local.kc_domain_name
    }
  )
}
