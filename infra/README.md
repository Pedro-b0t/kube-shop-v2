# Infraestrutura do KubeShop (GCP + Terraform + Ansible + GitHub Actions)

Implantação do KubeShop em duas VMs (REQ-01): **app** (Nginx + API) e **db** (MongoDB exclusivo, sem IP público). Tudo é criado e operado por pipelines; nenhum ajuste manual no console ou nos servidores.

```
infra/
  bootstrap/bootstrap.ps1     preparo único do projeto GCP (state, Service Accounts, WIF, segredos)
  terraform/shared/           Artifact Registry + bucket de backups (sobrevivem à desativação)
  terraform/env/              VPC, NAT, firewall, VMs, disco do MongoDB, snapshots, IAM
  ansible/                    configuração das VMs (roles Docker, MongoDB, app, backup)
  scripts/                    utilitários usados pelos pipelines
.github/workflows/            pipelines de infraestrutura e de integração com o CI/CD
.github/actions/setup-infra/  autenticação no GCP (WIF) e instalação de Terraform/Ansible
```

## Pipelines

| Workflow | Para que serve | Critérios |
|---|---|---|
| `infra-deploy.yml` | **Validar → Planejar → Provisionar (Terraform) → Publicar imagens → Configurar (Ansible) → Validar loja.** Execução manual com parâmetros | ACE-01, ACE-08, PM04 §3 |
| `infra-ops.yml` | Rotinas: `health`, `verify`, `logs`, `restart`, `backup`, `restore` | ACE-05, ACE-07, ACE-08 |
| `infra-destroy.yml` | Desativação com confirmação digitada, backup final e relatório do que continua cobrando | ACE-08 |
| `infra-app-deploy.yml` | Implanta somente uma versão da aplicação (chamado pelo CI/CD ou manual, também para **rollback**) | ACE-06 |
| `app-cicd.yml` | Pipeline de **referência** do CI/CD da aplicação: testes → imagens no Artifact Registry → deploy | ACE-06 |

Todos usam `concurrency` por ambiente/instância (nunca dois pipelines mexem no mesmo ambiente ao mesmo tempo) e interrompem na primeira falha. As credenciais vêm de Secrets e os planos/logs não contêm senhas (`no_log` no Ansible; o inventário só traz endereços).

### Parâmetros de `infra-deploy.yml`

| Parâmetro | PM04 | Efeito real |
|---|---|---|
| `action` | — | `plan` só mostra as alterações; `apply` executa |
| `environment` | `environment` | Estado, nomes e backups separados por ambiente (`dev`/`homolog`/`prod`) |
| `instance_name` | `instance_name` | Prefixo dos recursos (ex.: `kubeshop-dev-app`) |
| `app_machine_type`, `db_machine_type` | `instance_type` | Terraform redimensiona as VMs (os dados ficam no disco separado) |
| `db_disk_size_gb` | — | Terraform aumenta o disco de dados do MongoDB |
| `app_version` | `docker_tag` | Tag das imagens `api` e `frontend` implantadas pelo Ansible |
| `build_images` | — | Constrói e publica `app_version` antes de implantar (1ª implantação) |
| `mongo_image_tag` | `docker_tag` | Versão da imagem `mongo` |
| `update_os`, `allow_reboot` | `update_os` | Ansible aplica atualizações do SO e reinicia se necessário |
| `extra_packages` | `extra_packages` | Ansible instala pacotes adicionais |
| `force_pull_images` | — | Força `docker pull` mesmo com a mesma tag |
| `check_idempotence` | — | Reexecuta o playbook e falha se houver alterações (Cenário 3) |
| `run_smoke` | — | Valida a loja, cria/consulta um pedido e prova o isolamento do banco |

Os parâmetros são validados por `infra/scripts/validate-inputs.sh` e chegam ao shell só por variáveis de ambiente (sem injeção de comandos).

## Configuração única

1. Instale `gcloud` e (opcional) `gh`; autentique com `gcloud auth login`.
2. Use um **projeto GCP dedicado** ao KubeShop e execute, no PowerShell:

   ```powershell
   .\infra\bootstrap\bootstrap.ps1 -ProjectId <id-do-projeto> -CreateProject -BillingAccountId <conta-de-faturamento>
   ```

   O script cria o bucket do state, as Service Accounts, a Workload Identity Federation (sem chave JSON) e gera a chave SSH e as senhas do MongoDB em `.secrets\infra\` (ignorado pelo Git). Com `gh` instalado, cadastra tudo no repositório; sem ele, imprime a lista abaixo.
3. Cadastre em **Settings → Secrets and variables → Actions**:

   | Tipo | Nome | Conteúdo |
   |---|---|---|
   | Variable | `GCP_PROJECT_ID`, `GCP_REGION`, `GCP_ZONE` | Projeto e localização |
   | Variable | `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/<número>/locations/global/workloadIdentityPools/github-actions/providers/github` |
   | Variable | `GCP_SERVICE_ACCOUNT` | `kubeshop-infra@<projeto>.iam.gserviceaccount.com` |
   | Variable | `GCP_CI_SERVICE_ACCOUNT` | `kubeshop-ci@<projeto>.iam.gserviceaccount.com` (só grava imagens) |
   | Variable | `TF_STATE_BUCKET` | `<projeto>-tfstate` |
   | Variable | `SSH_PUBLIC_KEY` | Chave pública do pipeline |
   | Secret | `SSH_PRIVATE_KEY` | Chave privada do pipeline |
   | Secret | `MONGO_ROOT_PASSWORD`, `MONGO_APP_PASSWORD` | Senhas do MongoDB |

4. Opcional: em **Settings → Environments** crie `prod` com *Required reviewers* para exigir aprovação de apply/destroy.

## Roteiro de demonstração (PM04 §5 e ACE)

| Passo | Como executar | Evidência |
|---|---|---|
| **Cenário 1 — criação** | `infra-deploy`: `action=apply`, `build_images=true`, `app_version=1.0.0` | Plan com ~20 recursos de rede/VMs/discos, apply, imagens publicadas, Ansible, validação (ACE-01/02/03/04) |
| **Pedido e persistência** | Anote o `order_id` do resumo da validação; `infra-ops`: `operation=restart`, depois `operation=verify` com `order_id` | Pedido preservado após reinício (ACE-05) |
| **Cenário 2 — atualização** | `infra-deploy`: `db_machine_type=e2-medium`, `extra_packages=curl,git,unzip`, `update_os=true` | Plan mostra alteração só da VM; dados preservados; `verify` com o mesmo `order_id` (ACE-05) |
| **Cenário 3 — sem alterações** | Repita os mesmos parâmetros com `check_idempotence=true` | Terraform "No changes" e Ansible `changed=0` |
| **Backup e restauração** | `infra-ops`: `backup`; crie outro pedido; `restore` (`confirm=RESTORE`, `backup_file=latest`); `verify` | Backup no bucket e dados conferidos (ACE-07) |
| **Isolamento** | Resumo do `verify` | 27017 e 22 fechadas no IP público; VM do banco sem IP público (ACE-03) |
| **Integração CI/CD** | `app-cicd` (ou `infra-app-deploy` com `app_version` anterior para rollback) | ACE-06 |
| **Desativação** | `infra-destroy` | Resumo com snapshots e backups remanescentes (ACE-08) |

Guarde o link de cada execução e os prints em [`evidencias/`](../evidencias/README.md).

## Decisões de infraestrutura (resumo para o documento de arquitetura)

- **Rede privada e isolamento (REQ-02/03):** a VM do banco não tem IP público. O firewall só permite `27017` com origem na Service Account da VM de aplicação; existe ainda uma regra explícita de negação. SSH só pelo Identity-Aware Proxy (`35.235.240.0/20`); Cloud NAT dá saída para `apt`/Docker sem expor o banco.
- **Persistência (REQ-05):** dados do MongoDB em um disco persistente próprio, anexado à VM do banco. Trocar o tipo da VM ou recriá-la não apaga o disco; snapshots diários com retenção de 7 dias e backups lógicos (`mongodump`) em bucket versionado por 30 dias.
- **Acessos e segredos (REQ-04):** autenticação do pipeline por Workload Identity Federation restrita ao repositório; Service Accounts separadas (app lê imagens, banco grava backups, CI só publica imagens); chaves e senhas só em GitHub Secrets; sem chave JSON.
- **Estado do Terraform:** em bucket GCS próprio (`<projeto>-tfstate`), com versionamento, acesso uniforme e sem acesso público; há um prefixo por ambiente/instância e *lock* nativo do backend. Para recuperar um state, liste as versões com `gcloud storage ls -a gs://<bucket>/kubeshop/env/<ambiente>/<instancia>/` e restaure a geração desejada com `gcloud storage cp`.
- **Atualizações sem recriação:** `allow_stopping_for_update`, imagem do SO ignorada em `lifecycle`, IPs internos fixos e disco de dados separado evitam recriações desnecessárias.

## Integração com o CI/CD existente (ACE-06)

| Ponto de integração | Valor |
|---|---|
| Destino das imagens | `<região>-docker.pkg.dev/<projeto>/kubeshop/{api,frontend}:<tag>` |
| Autenticação do CI | Workload Identity Federation → `GCP_CI_SERVICE_ACCOUNT` (papel `artifactregistry.writer`) |
| Disparo do deploy | Chamar `infra-app-deploy.yml` (`workflow_call`/`workflow_dispatch`) com `environment` e `app_version` |
| Responsabilidades | CI da aplicação: testes, build e publicação. Pipelines de infraestrutura: VMs, rede, configuração, deploy nas VMs, backups e desativação |
| Segredos necessários | Somente referências (nomes acima); nenhum valor no repositório |
| Habilitar deploy automático no push | Criar a variável `CI_DEPLOY_ENABLED=true` depois do ambiente provisionado |

## Pré-requisito dos playbooks

Os workflows esperam em `infra/ansible/playbooks/`: `site.yml` (aceita `--limit app`), `health.yml`, `logs.yml`, `restart.yml`, `backup.yml` e `restore.yml`, conforme o contrato em [`docs/DIVISAO-TAREFAS.md`](../docs/DIVISAO-TAREFAS.md).
