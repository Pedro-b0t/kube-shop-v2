output "store_url" {
  description = "Endereco publico da loja"
  value       = "http://${google_compute_address.app_public.address}"
}

output "app_public_ip" {
  value = google_compute_address.app_public.address
}

output "app_private_ip" {
  value = google_compute_address.app_internal.address
}

output "db_private_ip" {
  value = google_compute_address.db_internal.address
}

output "app_instance" {
  value = google_compute_instance.app.name
}

output "db_instance" {
  value = google_compute_instance.db.name
}

output "db_public_ip" {
  description = "Sempre vazio: a VM do banco nao tem IP publico"
  value       = try(google_compute_instance.db.network_interface[0].access_config[0].nat_ip, "")
}

output "zone" {
  value = var.zone
}

output "mongo_data_disk" {
  value = google_compute_disk.mongo_data.name
}

output "ansible_inventory" {
  description = "Inventario gerado para o Ansible (acesso SSH via IAP, sem IP publico de administracao)"
  value = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    app_name      = google_compute_instance.app.name
    db_name       = google_compute_instance.db.name
    ssh_user      = var.ssh_user
    project_id    = var.project_id
    zone          = var.zone
    environment   = var.environment
    db_private_ip = google_compute_address.db_internal.address
    app_public_ip = google_compute_address.app_public.address
    backup_bucket = var.backup_bucket
    registry_url  = "${var.region}-docker.pkg.dev/${var.project_id}/${var.registry_name}"
  })
}
