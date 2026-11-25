#!/usr/bin/env bash
# Valida os parametros informados na execucao do pipeline antes de qualquer chamada a nuvem.
# Os valores chegam por variaveis de ambiente (nunca interpolados no script) para evitar injecao.
set -euo pipefail

fail() { echo "::error::$*"; exit 1; }
match() { # nome valor regex
  [[ "$2" =~ $3 ]] || fail "Parametro $1 invalido: '$2'"
}

match environment "${ENVIRONMENT:-}" '^(dev|homolog|prod)$'
match instance_name "${INSTANCE_NAME:-}" '^[a-z][a-z0-9-]{2,14}$'
[[ -z "${APP_MACHINE_TYPE:-}" ]] || match app_machine_type "$APP_MACHINE_TYPE" '^[a-z0-9-]+$'
[[ -z "${DB_MACHINE_TYPE:-}" ]] || match db_machine_type "$DB_MACHINE_TYPE" '^[a-z0-9-]+$'
[[ -z "${DB_DISK_SIZE_GB:-}" ]] || match db_disk_size_gb "$DB_DISK_SIZE_GB" '^[0-9]{2,3}$'
[[ -z "${APP_VERSION:-}" ]] || match app_version "$APP_VERSION" '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
[[ -z "${MONGO_IMAGE_TAG:-}" ]] || match mongo_image_tag "$MONGO_IMAGE_TAG" '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
[[ -z "${EXTRA_PACKAGES:-}" ]] || match extra_packages "$EXTRA_PACKAGES" '^[a-z0-9][a-z0-9.+-]*(,[ ]?[a-z0-9][a-z0-9.+-]*)*$'

for name in TF_STATE_BUCKET GCP_PROJECT_ID GCP_WORKLOAD_IDENTITY_PROVIDER GCP_SERVICE_ACCOUNT SSH_PUBLIC_KEY; do
  [[ -n "${!name:-}" ]] || fail "Configure '$name' em Settings > Secrets and variables > Actions (veja infra/README.md)."
done

echo "Parametros validos."
