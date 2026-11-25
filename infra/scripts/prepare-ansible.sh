#!/usr/bin/env bash
# Prepara o Ansible no runner: chave SSH do pipeline e inventario gerado pelo Terraform.
# Requer: terraform init da stack "env" ja executado e SSH_PRIVATE_KEY no ambiente.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

: "${SSH_PRIVATE_KEY:?SSH_PRIVATE_KEY nao definido (secret do repositorio)}"
install -d -m 700 "$HOME/.ssh"
umask 077
printf '%s\n' "$SSH_PRIVATE_KEY" | tr -d '\r' > "$HOME/.ssh/id_ed25519"
chmod 600 "$HOME/.ssh/id_ed25519"

terraform -chdir="$root/infra/terraform/env" output -raw ansible_inventory > "$root/infra/ansible/inventory/hosts.ini"
echo "Inventario gerado:"
sed -E 's/^(db_private_ip|app_public_ip)=.*/\1=<omitido>/' "$root/infra/ansible/inventory/hosts.ini"

# O IAP encaminha o SSH; aguarda as VMs aceitarem conexao (necessario logo apos o primeiro apply).
cd "$root/infra/ansible"
for attempt in $(seq 1 20); do
  if ansible all -m ansible.builtin.ping -o; then exit 0; fi
  echo "VMs ainda indisponiveis via IAP (tentativa $attempt/20); aguardando 15s..."
  sleep 15
done
echo "::error::Nao foi possivel conectar nas VMs via IAP" >&2
exit 1
