output "registry_url" {
  description = "Prefixo das imagens Docker"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "backup_bucket" {
  description = "Bucket dos backups logicos do MongoDB"
  value       = google_storage_bucket.backups.name
}
