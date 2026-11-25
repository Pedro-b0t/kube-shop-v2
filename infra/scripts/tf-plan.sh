#!/usr/bin/env bash
# Executa "terraform plan" de uma stack, grava o plano em "tfplan" e publica o resumo da execucao.
# Uso: tf-plan.sh shared|env [argumentos extras do plan, ex.: -destroy]
set -euo pipefail

stack="${1:?uso: tf-plan.sh shared|env}"
shift
cd "$(dirname "$0")/../terraform/$stack"

set +e
terraform plan -input=false -no-color -lock-timeout=5m -detailed-exitcode -out=tfplan "$@" 2>&1 | tee plan.log
code=${PIPESTATUS[0]}
set -e

case "$code" in
  0) changes=false ;;
  2) changes=true ;;
  *) echo "::error::terraform plan falhou na stack $stack" >&2; exit 1 ;;
esac

echo "${stack}_changes=${changes}" >> "${GITHUB_OUTPUT:-/dev/null}"
{
  echo "### Terraform plan - stack \`${stack}\` (alteracoes: ${changes})"
  echo '```'
  terraform show -no-color tfplan
  echo '```'
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
