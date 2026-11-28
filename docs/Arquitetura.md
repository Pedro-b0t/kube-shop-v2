Arquitetura da Solução
Visão Geral
A aplicação kube-shop-v2 foi implantada utilizando uma arquitetura distribuída em duas máquinas virtuais no Google Cloud Platform (GCP).

A solução é composta por:

VM APP

Frontend
API Node.js
VM DB

MongoDB
Todas as aplicações são executadas em containers Docker e gerenciadas por Docker Compose.

Diagrama Lógico
Internet │ ▼ Frontend (VM APP) │ ▼ API (VM APP) │ ▼ MongoDB (VM DB)

Componentes
Frontend
Responsável pela interface do usuário.

Características:

Executado em container Docker
Exposto na porta 80
Comunicação com API pela rede interna Docker
API
Responsável pelas regras de negócio.

Características:

Node.js
Porta 3000
Health Check configurado
Conexão com MongoDB via IP privado
MongoDB
Banco de dados principal da aplicação.

Características:

Executado em container Docker
Volume persistente em disco dedicado
Usuários separados para aplicação e administração
Backup automatizado
Infraestrutura
Recursos principais:

Google Cloud Platform (GCP)
Compute Engine
Artifact Registry
Cloud Storage
Docker
Ansible
Terraform
Automação
Terraform:

Rede
VMs
Discos
IAM
Outputs para Ansible
Ansible:

Configuração do sistema operacional
Instalação do Docker
Implantação do MongoDB
Implantação da aplicação
Backup
Restore