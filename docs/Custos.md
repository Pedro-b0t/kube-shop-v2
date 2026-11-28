Estimativa de Custos
Recursos Utilizados
VM APP
Responsável por:

Frontend
API
Configuração estimada:

e2-micro ou equivalente
VM DB
Responsável por:

MongoDB
Configuração estimada:

e2-small ou equivalente
Disco Persistente
Utilizado pelo MongoDB para armazenamento dos dados.

Artifact Registry
Armazenamento das imagens Docker.

Cloud Storage
Armazenamento dos backups do banco de dados.

Custos Principais
Os custos estão relacionados a:

Máquinas virtuais
Disco persistente
Tráfego de rede
Cloud Storage
Artifact Registry
Estratégias de Redução
Utilização de instâncias pequenas
Compressão dos backups
Limpeza periódica de imagens antigas
Remoção de backups obsoletos
Conclusão
A arquitetura foi projetada para manter baixo custo operacional, utilizando apenas dois servidores e serviços gerenciados do Google Cloud.