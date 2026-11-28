Validação da Solução
Objetivo
Validar a infraestrutura, automações e serviços da aplicação kube-shop-v2 após a implementação da arquitetura proposta.

Validação do Terraform
Foi realizada validação da configuração Terraform utilizando:

terraform validate
Resultado esperado:

Success! The configuration is valid.
Validação do Ansible
Syntax Check
Executado:

ansible-playbook playbooks/site.yml --syntax-check
Resultado:

Validação concluída sem erros de sintaxe.

Ansible Lint
Executado:

ansible-lint playbooks/site.yml
Resultado:

Passed: 0 failure(s), 0 warning(s)
A configuração atende às boas práticas recomendadas pelo Ansible.

Validação do Docker
Verificação dos containers:

docker ps
Resultado esperado:

frontend em execução
api em execução
mongodb em execução
Validação da Aplicação
A aplicação deve estar acessível através do endereço público da VM APP.

Verificações:

Frontend acessível
API respondendo corretamente
Comunicação entre frontend e API funcionando
Validação do Banco de Dados
Verificação da disponibilidade do MongoDB.

Exemplo:

docker exec -it mongodb mongosh
Itens validados:

Container ativo
Autenticação funcional
Banco acessível
Validação dos Backups
Executado:

ansible-playbook playbooks/backup.yml
Validações:

Geração do arquivo de backup
Compressão do backup
Upload para Cloud Storage
Validação do Restore
Executado:

ansible-playbook playbooks/restore.yml \
-e confirm_restore=true \
-e backup_name=<arquivo>
Validações:

Download do backup
Transferência para o container
Execução do mongorestore
Recuperação dos dados
Validação Operacional
Executados os seguintes playbooks:

playbooks/site.yml
playbooks/health.yml
playbooks/restart.yml
playbooks/logs.yml
playbooks/backup.yml
playbooks/restore.yml
Resultado esperado:

Todos os playbooks executando sem falhas.

Resultado Final
A solução implementada atende os requisitos do projeto, utilizando infraestrutura provisionada por Terraform, configuração automatizada por Ansible e execução dos serviços através de containers Docker.

A arquitetura final é composta por:

VM APP (Frontend + API)
VM DB (MongoDB)
com separação de responsabilidades, persistência de dados e mecanismos de backup e recuperação.