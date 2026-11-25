# Divisão de tarefas — Pedro e Pablo

Referências: `escopo.pdf` (Zibiska Korp, REQ-01..05 e ACE-01..10) e `PM04 entrega projeto final terraform ansible_.pdf` (prazo de entrega: **27/11/2026**, apresentação na 1ª semana de dezembro, todos os integrantes presentes).

**Decisões de base:** GCP (Pedro tem a conta), Terraform + Ansible, GitHub Actions. Duas VMs: `app` (Nginx + API em Docker) e `db` (MongoDB em Docker, sem IP público, disco de dados separado).

## Resumo

| | Pedro (conta GCP) | Pablo (sem necessidade de GCP) |
|---|---|---|
| Foco | Nuvem, Terraform, pipelines, execução real e evidências | Ansible, adaptação da aplicação para 2 hosts, documentação e custos |
| Precisa de acesso ao GCP? | Sim | Não (testa em Docker/WSL local) |

## Pedro — nuvem, Terraform e pipelines

| # | Tarefa | Critérios |
|---|---|---|
| P1 | Criar projeto GCP, billing e habilitar APIs (Compute, Artifact Registry, Storage, IAM, IAP) | ACE-01 |
| P2 | Script `infra/bootstrap/` com bucket do state (versionado, acesso restrito), Service Account do pipeline e Workload Identity Federation (sem chave JSON) | ACE-08 |
| P3 | Terraform `infra/terraform/shared` (Artifact Registry + bucket de backups) e `infra/terraform/env` (VPC, NAT, firewall, 2 VMs, disco do Mongo, snapshots, IAM) — **já escrito e validado com `terraform validate`**, falta testar com `plan/apply` reais | REQ-01/02/03/05, ACE-02/03 |
| P4 | GitHub Secrets/Variables (nomes na seção Contrato) | REQ-04, ACE-08 |
| P5 | `.github/workflows/infra-deploy.yml`: `workflow_dispatch` com os parâmetros, jobs validate → plan → apply → ansible, logs sem segredos, falha interrompe | PM04 §3.1, ACE-01/08 |
| P6 | `.github/workflows/infra-ops.yml`: reiniciar, health, logs, backup, restore | ACE-07/08 |
| P7 | `.github/workflows/infra-destroy.yml` com confirmação digitada, protegendo dados/backups | ACE-08 |
| P8 | Integração com o CI/CD existente: workflow de exemplo que publica imagens no Artifact Registry e dispara o deploy | ACE-06 |
| P9 | Executar os 3 cenários do PM04 (criação, atualização, reexecução idempotente) + teste de alteração de infraestrutura preservando dados (ex.: mudar `db_machine_type`/`app_machine_type`) | ACE-05, PM04 §5 |
| P10 | Provar isolamento: `nc`/`nmap` externo na 27017 falhando; API conectando pelo IP privado | ACE-03 |
| P11 | Pasta `evidencias/` (prints, logs de execuções, links de runs) e conferir os custos reais no console | ACE-08/09 |

## Pablo — Ansible, aplicação e documentação

| # | Tarefa | Critérios |
|---|---|---|
| B1 | Role `common`: atualização de pacotes/SO conforme `update_os`, `extra_packages`, reboot controlado | PM04 §3.3 |
| B2 | Role `docker`: instalar Docker Engine + Compose plugin (idempotente), log rotation, autenticação no Artifact Registry via credencial da VM | PM04 §3.3 |
| B3 | Role `mongodb` (hosts `db`): formatar/montar o disco `/dev/disk/by-id/google-mongo-data` em `/var/lib/mongo`, subir `mongo:8.0.17` com autenticação, criar usuário da aplicação (reusar `docker/mongodb/init.js` e `healthcheck.js`), escutar apenas no IP privado | REQ-02/03/05 |
| B4 | Role `app` (hosts `app`): subir frontend + API em Docker, `MONGO_HOST={{ db_private_ip }}`, senha em arquivo (`MONGO_PASSWORD_FILE`), imagem `kube-shop/*` na versão `app_version`, `force_pull_images` | REQ-01, ACE-04 |
| B5 | Adaptar a aplicação: criar `deploy/compose.app.yaml` e `deploy/compose.db.yaml` (derivados do `compose.yaml`) e ajustar o `nginx.conf` para a API sem DNS do Compose (proxy para o host da API na rede local da VM `app`), publicando na porta 80 | Seção 5 do escopo |
| B6 | Role `backup`: `mongodump` agendado (systemd timer) → bucket GCS, retenção, e playbook de restauração com conferência de contagem de pedidos | ACE-07 |
| B7 | `infra/ansible/playbooks/`: `site.yml` (completo), `restart.yml`, `health.yml`, `logs.yml`, `backup.yml`, `restore.yml`, cada um idempotente | ACE-08 |
| B8 | Testar localmente com `ansible-lint` e `molecule`/container Debian 12 (WSL ou Docker) | PM04 §3.3 |
| B9 | `docs/arquitetura.md`: diagrama, justificativa de provedor/ferramentas/dimensionamento, limitações, decisão de DNS/TLS | ACE-09/10 |
| B10 | `docs/custos.md`: estimativa mensal com premissas, VMs, disco, snapshots, bucket, IP, NAT, egress, créditos separados (usar a Calculadora de Preços do GCP, que não exige conta) | ACE-09 |
| B11 | `docs/operacao.md`: manual de rotinas (implantação, atualização, saúde, logs, backup, restauração, desativação), separando rotinas cotidianas das destrutivas | ACE-10 |
| B12 | `docs/integracao-cicd.md` e `docs/validacao.md` (modelo do relatório, preenchido com os runs do Pedro) | ACE-06 |

## Contrato entre os dois (para trabalhar em paralelo)

**Caminhos:** Terraform em `infra/terraform/{shared,env}`; Ansible em `infra/ansible` (`ansible.cfg`, `inventory/group_vars/all.yml` já criados). O pipeline gera `infra/ansible/inventory/hosts.ini` a partir de `terraform output -raw ansible_inventory`; o formato está em `inventory/hosts.example.ini`.

**Grupos de inventário:** `app` e `db`. Variáveis disponíveis nos hosts: `db_private_ip`, `app_public_ip`, `backup_bucket`, `registry_url`, `kubeshop_environment`, `gcp_project`, `gcp_zone`.

**Variáveis de entrada do playbook (`-e`):** `app_version`, `mongo_image_tag`, `update_os` (bool), `extra_packages` (lista separada por vírgula), `force_pull_images` (bool), `allow_reboot` (bool). Os valores padrão estão em `inventory/group_vars/all.yml`.

**Playbooks esperados pelos workflows (`infra/ansible/playbooks/`):**

| Playbook | Chamado por | Variáveis extras |
|---|---|---|
| `site.yml` | `infra-deploy`, `infra-app-deploy` (com `--limit app`) | as de cima |
| `health.yml` | `infra-ops` | — |
| `logs.yml` | `infra-ops` | `service_scope` (all/app/db), `log_lines` |
| `restart.yml` | `infra-ops` | `service_scope` |
| `backup.yml` | `infra-ops`, `infra-destroy` | — (grava em `gs://{{ backup_bucket }}/{{ kubeshop_environment }}/`) |
| `restore.yml` | `infra-ops` | `backup_file` (objeto do bucket ou `latest`) |

**Imagens da aplicação:** `{{ registry_url }}/api:{{ app_version }}` e `{{ registry_url }}/frontend:{{ app_version }}` (publicadas pelo pipeline; a VM `app` autentica no Artifact Registry com a Service Account da VM). O pipeline também executa `site.yml` com `--limit app` para implantar só a aplicação, então os plays de `app` não podem depender de tarefas dos hosts `db`.

**Segredos:** o Ansible lê `MONGO_ROOT_PASSWORD` e `MONGO_APP_PASSWORD` de variáveis de ambiente (GitHub Secrets). Nada de senha no repositório nem em logs (usar `no_log: true`).

**Disco do MongoDB:** device `google-mongo-data` (`/dev/disk/by-id/google-mongo-data`), montar em `/var/lib/mongo`.

**Parâmetros do pipeline (Pedro):** `environment`, `instance_name`, `app_machine_type`, `db_machine_type`, `db_disk_size_gb`, `docker_image`/`app_version`, `docker_tag`, `update_os`, `extra_packages`, `force_pull_images`, `action` (apply/plan/destroy).

## Ordem sugerida

1. **Hoje (24/11):** Pedro faz P1–P4 e testa `plan`; Pablo faz B1–B5 localmente.
2. **25/11:** Pedro faz P5 (pipeline) e primeiro `apply`; Pablo faz B6–B7 e integra com o inventário real.
3. **26/11:** Cenários 1–3, backup/restore, isolamento (P9/P10); Pablo finaliza B9–B12.
4. **27/11:** Montar o PDF (integrantes, análise da demanda, decisões, link do repositório e evidências) e anexar na Blackboard.
5. **Apresentação:** os dois ensaiam a demonstração dos 3 cenários antes de dezembro.

## Atenção

- O CI/CD existente da aplicação não está neste repositório: P8 e B12 documentam os pontos de integração (build, publicação da imagem, destino).
- Destruir o ambiente não pode apagar o bucket de backups sem `allow_destroy_data=true` — é de propósito.
