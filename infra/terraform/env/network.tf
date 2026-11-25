locals {
  prefix = "${var.instance_name}-${var.environment}"
  labels = {
    app         = "kubeshop"
    owner       = "zibiska-korp"
    environment = var.environment
    managed-by  = "terraform"
  }
  metadata = {
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "TRUE"
    ssh-keys               = "${var.ssh_user}:${trimspace(var.ssh_public_key)}"
  }
}

# ---------- Rede privada ----------

resource "google_compute_network" "vpc" {
  name                    = "${local.prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "private" {
  name                     = "${local.prefix}-subnet"
  network                  = google_compute_network.vpc.id
  region                   = var.region
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

# Saida para internet (apt, imagens Docker) da VM do banco, que nao possui IP publico.
resource "google_compute_router" "router" {
  name    = "${local.prefix}-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${local.prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_address" "app_public" {
  name         = "${local.prefix}-app-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

resource "google_compute_address" "app_internal" {
  name         = "${local.prefix}-app-internal"
  region       = var.region
  subnetwork   = google_compute_subnetwork.private.id
  address_type = "INTERNAL"
  address      = cidrhost(var.subnet_cidr, 10)
}

# IP privado fixo do banco: a API continua apontando para o mesmo endereco
# mesmo se a VM do banco for recriada.
resource "google_compute_address" "db_internal" {
  name         = "${local.prefix}-db-internal"
  region       = var.region
  subnetwork   = google_compute_subnetwork.private.id
  address_type = "INTERNAL"
  address      = cidrhost(var.subnet_cidr, 20)
}

# ---------- Regras de acesso (por conta de servico, nao por tag) ----------

resource "google_compute_firewall" "allow_http" {
  name                    = "${local.prefix}-allow-http-app"
  network                 = google_compute_network.vpc.id
  direction               = "INGRESS"
  priority                = 1000
  source_ranges           = var.http_source_ranges
  target_service_accounts = [google_service_account.app.email]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_admin_ssh" {
  name                    = "${local.prefix}-allow-ssh-iap"
  network                 = google_compute_network.vpc.id
  direction               = "INGRESS"
  priority                = 1000
  source_ranges           = var.admin_source_ranges
  target_service_accounts = [google_service_account.app.email, google_service_account.db.email]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_mongo_from_app" {
  name                    = "${local.prefix}-allow-mongo-from-app"
  network                 = google_compute_network.vpc.id
  direction               = "INGRESS"
  priority                = 1000
  source_service_accounts = [google_service_account.app.email]
  target_service_accounts = [google_service_account.db.email]
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
}

# Negacao explicita (documenta a intencao; a VPC ja nega por padrao).
resource "google_compute_firewall" "deny_mongo_other" {
  name                    = "${local.prefix}-deny-mongo-other"
  network                 = google_compute_network.vpc.id
  direction               = "INGRESS"
  priority                = 2000
  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.db.email]
  deny {
    protocol = "tcp"
    ports    = ["27017"]
  }
}
