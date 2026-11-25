# Evidências de execução

Cada critério de aceite deve ter aqui um registro verificável. Preencha a coluna **Execução** com o link da execução do GitHub Actions (aba *Actions*) e salve prints ou logs em subpastas por data.

Não salve senhas, chaves ou o conteúdo de `.secrets/` — os logs dos pipelines já não os exibem; confira antes de anexar prints do console.

| Critério | Evidência esperada | Workflow | Execução | Arquivos |
|---|---|---|---|---|
| ACE-01 Reprodução | Ambiente criado do zero pelo pipeline | `infra-deploy` (`apply`, `build_images`) | | |
| ACE-02 Duas VMs | Inventário (`terraform output`) e lista de VMs no console | `infra-deploy` | | |
| ACE-03 Isolamento | Resumo do `verify` (27017 fechada, banco sem IP público, `/api/health/ready` = 200) | `infra-ops` (`verify`) | | |
| ACE-04 Aplicação | Loja aberta, catálogo, pedido criado e consultado após recarregar | `infra-ops` (`verify`) + print do navegador | | |
| ACE-05 Persistência | `order_id` preservado após `restart` e após alteração de tipo de VM | `infra-ops` (`restart`, `verify`), `infra-deploy` (Cenário 2) | | |
| ACE-06 CI/CD | Imagens publicadas e deploy disparado pelo CI | `app-cicd`, `infra-app-deploy` | | |
| ACE-07 Recuperação | Backup no bucket e restauração com conferência dos pedidos | `infra-ops` (`backup`, `restore`, `verify`) | | |
| ACE-08 Administração | Registros dos pipelines, rotinas e desativação | `infra-ops`, `infra-destroy` | | |
| ACE-09 Custos | Estimativa (documento de custos) e custo real do console | — | | |
| PM04 Cenário 3 | Terraform sem alterações e Ansible `changed=0` | `infra-deploy` (`check_idempotence`) | | |
