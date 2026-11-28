Guia de Operação
Objetivo
Este documento descreve os procedimentos operacionais da solução kube-shop-v2, incluindo deploy, monitoramento, coleta de logs, backup, restauração e atualização da aplicação.

Pré-requisitos
Antes da execução dos playbooks é necessário possuir:

Ansible instalado
Coleções Ansible instaladas
Acesso SSH às máquinas virtuais
Inventory configurado
Variáveis de ambiente do MongoDB definidas
Docker instalado nos servidores
Instalar as collections:

ansible-galaxy collection install -r requirements.yml
Estrutura da Solução
A arquitetura é composta por duas máquinas virtuais:

VM APP
Responsável por executar:

Frontend
API
VM DB
Responsável por executar:

MongoDB
Todos os serviços são executados utilizando Docker e Docker Compose.

Deploy Completo
Para provisionar ou atualizar todos os componentes da solução:

ansible-playbook playbooks/site.yml
O playbook realiza:

Configuração básica do sistema operacional
Instalação do Docker
Configuração do MongoDB
Implantação da API
Implantação do Frontend
Verificação de Saúde
Executar:

ansible-playbook playbooks/health.yml
O playbook verifica:

Docker em execução
Containers ativos
Disponibilidade dos serviços
Reinício dos Serviços
Reiniciar Aplicação
ansible-playbook playbooks/restart.yml \
-e service_scope=app
Serviços reiniciados:

frontend
api
Reiniciar Banco de Dados
ansible-playbook playbooks/restart.yml \
-e service_scope=db
Serviço reiniciado:

mongodb
Coleta de Logs
Logs da Aplicação
ansible-playbook playbooks/logs.yml \
-e service_scope=app
Logs do Banco de Dados
ansible-playbook playbooks/logs.yml \
-e service_scope=db
Exibir Mais Linhas
ansible-playbook playbooks/logs.yml \
-e service_scope=app \
-e log_lines=200
Backup do Banco de Dados
Executar:

ansible-playbook playbooks/backup.yml
Procedimentos executados:

Geração do backup utilizando mongodump
Compressão do arquivo
Cópia para o host
Upload para o bucket do Google Cloud Storage
Local de armazenamento:

gs://<backup_bucket>/<ambiente>/
Exemplo:

gs://meu-projeto-kubeshop-backups/dev/
Restore do Banco de Dados
Atenção
A restauração remove os dados atuais e substitui pelo conteúdo do backup selecionado.

Executar Restore
ansible-playbook playbooks/restore.yml \
-e confirm_restore=true \
-e backup_name=mongodb-1700000000.archive.gz
Validações realizadas:

confirmação obrigatória
nome do arquivo válido
download do backup
cópia para o container MongoDB
execução do mongorestore
Atualização da Aplicação
A atualização pode ser realizada alterando a versão da aplicação.

Arquivo:

inventory/group_vars/all.yml
Variável:

app_version: v1.0.0
Após a alteração:

ansible-playbook playbooks/site.yml
Atualização Forçada das Imagens
Caso seja necessário forçar o download das imagens Docker:

force_pull_images: true
Executar novamente:

ansible-playbook playbooks/site.yml
Verificação Manual dos Containers
Acesso à VM:

ssh usuario@servidor
Listar containers:

docker ps
Visualizar logs:

docker logs <container>
Entrar em um container:

docker exec -it <container> bash
Monitoramento do MongoDB
Verificar status:

docker ps
Acompanhar logs:

docker logs mongodb
Executar shell Mongo:

docker exec -it mongodb mongosh
Recuperação de Falhas
Aplicação indisponível
Verificar containers:
docker ps
Verificar logs:
docker logs frontend
docker logs api
Reiniciar serviços:
ansible-playbook playbooks/restart.yml \
-e service_scope=app
Banco indisponível
Verificar status do container:
docker ps
Verificar logs do MongoDB:
docker logs mongodb
Reiniciar serviço:
ansible-playbook playbooks/restart.yml \
-e service_scope=db
Restaurar backup, se necessário.
Arquivos Principais
Playbooks:

playbooks/site.yml
playbooks/health.yml
playbooks/restart.yml
playbooks/logs.yml
playbooks/backup.yml
playbooks/restore.yml
Roles:

roles/common
roles/docker
roles/app
roles/mongodb
roles/backup
Inventário:

inventory/hosts.ini
Variáveis globais:

inventory/group_vars/all.yml
Boas Práticas Operacionais
Executar backup regularmente.
Validar os backups periodicamente.
Utilizar restore apenas com confirmação explícita.
Monitorar espaço em disco da VM DB.
Atualizar imagens Docker antes de implantações críticas.
Utilizar sempre o playbook oficial para mudanças na infraestrutura.
Não armazenar senhas diretamente no repositório.
Conclusão
A operação da solução kube-shop-v2 foi totalmente automatizada utilizando Ansible, permitindo deploy, atualização, monitoramento, backup e recuperação de forma padronizada e reproduzível.