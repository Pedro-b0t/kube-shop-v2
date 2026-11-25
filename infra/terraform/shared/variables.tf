variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Regiao GCP dos recursos compartilhados"
  type        = string
  default     = "southamerica-east1"
}

variable "registry_name" {
  description = "Nome do repositorio Docker no Artifact Registry"
  type        = string
  default     = "kubeshop"
}

variable "registry_keep_versions" {
  description = "Quantidade de versoes recentes mantidas por imagem"
  type        = number
  default     = 10
}

variable "backup_retention_days" {
  description = "Dias de retencao dos backups logicos (mongodump) no bucket"
  type        = number
  default     = 30
}

variable "allow_destroy_data" {
  description = "Permite apagar o bucket de backups mesmo com objetos (somente na desativacao total)"
  type        = bool
  default     = false
}
