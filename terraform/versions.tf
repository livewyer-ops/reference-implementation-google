terraform {
  required_version = ">= 1.5.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.16.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.3"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.3"
    }
  }
}
