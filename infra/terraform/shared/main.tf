# Recursos de longa duração, compartilhados entre ambientes.
# Sobrevivem à desativação de um ambiente (imagens e backups).

terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  labels = {
    app        = "kubeshop"
    owner      = "zibiska-korp"
    managed-by = "terraform"
    stack      = "shared"
  }
}

resource "google_artifact_registry_repository" "images" {
  repository_id = var.registry_name
  location      = var.region
  format        = "DOCKER"
  description   = "Imagens do KubeShop publicadas pelo CI/CD da aplicacao"
  labels        = local.labels

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "manter-recentes"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.registry_keep_versions
    }
  }
  cleanup_policies {
    id     = "remover-sem-tag-antigas"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"
    }
  }
}

resource "google_storage_bucket" "backups" {
  name                        = "${var.project_id}-kubeshop-backups"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.allow_destroy_data
  labels                      = local.labels

  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }
}
