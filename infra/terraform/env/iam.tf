# Contas de servico dedicadas, com permissoes minimas por recurso.

resource "google_service_account" "app" {
  account_id   = "${local.prefix}-app"
  display_name = "KubeShop ${var.environment} - VM de aplicacao"
}

resource "google_service_account" "db" {
  account_id   = "${local.prefix}-db"
  display_name = "KubeShop ${var.environment} - VM do MongoDB"
}

resource "google_artifact_registry_repository_iam_member" "app_pull" {
  project    = var.project_id
  location   = var.region
  repository = var.registry_name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.app.email}"
}

resource "google_storage_bucket_iam_member" "db_backups" {
  bucket = var.backup_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.db.email}"
}
