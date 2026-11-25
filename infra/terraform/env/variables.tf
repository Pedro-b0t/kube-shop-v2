variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Regiao GCP"
  type        = string
  default     = "southamerica-east1"
}

variable "zone" {
  description = "Zona GCP das VMs e do disco do banco"
  type        = string
  default     = "southamerica-east1-a"
}

variable "environment" {
  description = "Ambiente de destino"
  type        = string
  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

variable "instance_name" {
  description = "Prefixo dos nomes das VMs e recursos (ex.: kubeshop -> kubeshop-dev-app)"
  type        = string
  default     = "kubeshop"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,14}$", var.instance_name))
    error_message = "instance_name: 3-15 caracteres, minusculas, digitos ou hifen, iniciando por letra."
  }
}

variable "app_machine_type" {
  description = "Tipo da VM de aplicacao (Nginx + API)"
  type        = string
  default     = "e2-small"
}

variable "db_machine_type" {
  description = "Tipo da VM exclusiva do MongoDB"
  type        = string
  default     = "e2-small"
}

variable "os_image" {
  description = "Imagem do sistema operacional das VMs"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "boot_disk_size_gb" {
  description = "Tamanho do disco de boot das VMs"
  type        = number
  default     = 10
}

variable "db_disk_size_gb" {
  description = "Tamanho do disco persistente de dados do MongoDB (so pode aumentar)"
  type        = number
  default     = 10
  validation {
    condition     = var.db_disk_size_gb >= 10 && var.db_disk_size_gb <= 200
    error_message = "db_disk_size_gb deve estar entre 10 e 200."
  }
}

variable "subnet_cidr" {
  description = "Faixa da sub-rede privada"
  type        = string
  default     = "10.10.0.0/24"
}

variable "admin_source_ranges" {
  description = "Origens autorizadas para SSH administrativo (padrao: somente o proxy do Identity-Aware Proxy)"
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "http_source_ranges" {
  description = "Origens autorizadas a acessar a loja (porta 80)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_user" {
  description = "Usuario administrativo criado nas VMs para o Ansible"
  type        = string
  default     = "ansible"
}

variable "ssh_public_key" {
  description = "Chave publica SSH do pipeline (a privada fica apenas no GitHub Secrets)"
  type        = string
}

variable "snapshot_retention_days" {
  description = "Dias de retencao dos snapshots diarios do disco do MongoDB"
  type        = number
  default     = 7
}

variable "registry_name" {
  description = "Repositorio do Artifact Registry criado pela stack shared"
  type        = string
  default     = "kubeshop"
}

variable "backup_bucket" {
  description = "Bucket de backups criado pela stack shared"
  type        = string
}
