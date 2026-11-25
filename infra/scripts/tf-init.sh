#!/usr/bin/env bash
# Inicializa o backend remoto (GCS) de uma stack Terraform.
# Uso: tf-init.sh shared|env
# Variaveis: TF_STATE_BUCKET e, para "env", ENVIRONMENT e INSTANCE_NAME.
set -euo pipefail

stack="${1:?uso: tf-init.sh shared|env}"
bucket="${TF_STATE_BUCKET:?TF_STATE_BUCKET nao definido (variavel do repositorio)}"

case "$stack" in
  shared) prefix="kubeshop/shared" ;;
  env) prefix="kubeshop/env/${ENVIRONMENT:?}/${INSTANCE_NAME:?}" ;;
  *) echo "::error::stack invalida: $stack" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/../terraform/$stack"
terraform init -input=false -no-color \
  -backend-config="bucket=${bucket}" \
  -backend-config="prefix=${prefix}"
