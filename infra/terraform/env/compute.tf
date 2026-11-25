# ---------- Armazenamento persistente do MongoDB ----------

resource "google_compute_resource_policy" "mongo_snapshots" {
  name   = "${local.prefix}-mongo-snapshots"
  region = var.region
  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "06:00" # UTC (03:00 em Brasilia)
      }
    }
    retention_policy {
      max_retention_days    = var.snapshot_retention_days
      on_source_disk_delete = "APPLY_RETENTION_POLICY"
    }
    snapshot_properties {
      labels            = local.labels
      storage_locations = [var.region]
    }
  }
}

# Disco separado do boot: a VM do banco pode ser redimensionada ou recriada sem perder os dados.
resource "google_compute_disk" "mongo_data" {
  name   = "${local.prefix}-mongo-data"
  zone   = var.zone
  type   = "pd-balanced"
  size   = var.db_disk_size_gb
  labels = merge(local.labels, { role = "db-data" })
}

resource "google_compute_disk_resource_policy_attachment" "mongo_snapshots" {
  name = google_compute_resource_policy.mongo_snapshots.name
  disk = google_compute_disk.mongo_data.name
  zone = var.zone
}

# ---------- VMs ----------

resource "google_compute_instance" "app" {
  name                      = "${local.prefix}-app"
  machine_type              = var.app_machine_type
  zone                      = var.zone
  allow_stopping_for_update = true
  labels                    = merge(local.labels, { role = "app" })
  metadata                  = local.metadata

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.os_image
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    network_ip = google_compute_address.app_internal.address
    access_config {
      nat_ip       = google_compute_address.app_public.address
      network_tier = "STANDARD"
    }
  }

  service_account {
    email  = google_service_account.app.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  depends_on = [google_artifact_registry_repository_iam_member.app_pull]
}

resource "google_compute_instance" "db" {
  name                      = "${local.prefix}-db"
  machine_type              = var.db_machine_type
  zone                      = var.zone
  allow_stopping_for_update = true
  labels                    = merge(local.labels, { role = "db" })
  metadata                  = local.metadata

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.os_image
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.mongo_data.id
    device_name = "mongo-data"
    mode        = "READ_WRITE"
  }

  # Sem access_config: a VM do banco nao possui IP publico.
  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    network_ip = google_compute_address.db_internal.address
  }

  service_account {
    email  = google_service_account.db.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  depends_on = [google_storage_bucket_iam_member.db_backups, google_compute_router_nat.nat]
}
