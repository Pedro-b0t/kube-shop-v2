<#
.SYNOPSIS
  Prepara o projeto GCP para os pipelines do KubeShop (executar UMA vez, por quem tem a conta GCP).

.DESCRIPTION
  - habilita as APIs necessarias;
  - cria o bucket do Terraform State (versionado, acesso uniforme, sem acesso publico);
  - cria as Service Accounts do pipeline de infraestrutura e do CI da aplicacao;
  - configura Workload Identity Federation (o GitHub Actions autentica sem chave JSON);
  - gera chave SSH e senhas do MongoDB em .secrets\infra\ (ignorado pelo Git);
  - se o GitHub CLI (gh) estiver instalado, cadastra variaveis e secrets no repositorio.

  O script e idempotente: pode ser executado novamente sem duplicar recursos.

.EXAMPLE
  .\infra\bootstrap\bootstrap.ps1 -ProjectId kubeshop-zibiska -CreateProject -BillingAccountId 000000-AAAAAA-BBBBBB
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ProjectId,
  [string] $Region = 'southamerica-east1',
  [string] $Zone = 'southamerica-east1-a',
  [string] $GitHubRepo = 'Pedro-b0t/kube-shop-v2',
  [switch] $CreateProject,
  [string] $BillingAccountId,
  [switch] $SkipGitHub
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')

function Invoke-Gcloud {
  param([Parameter(ValueFromRemainingArguments)] [string[]] $Arguments)
  & gcloud @Arguments
  if ($LASTEXITCODE -ne 0) { throw "gcloud $($Arguments -join ' ') falhou (codigo $LASTEXITCODE)" }
}

function Test-Gcloud {
  param([Parameter(ValueFromRemainingArguments)] [string[]] $Arguments)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  & gcloud @Arguments *> $null
  $ok = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $previous
  return $ok
}

function New-Password {
  $bytes = New-Object byte[] 48
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  return ([Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', '').Substring(0, 32)
}

Write-Host "== Conta ativa: $(& gcloud config get-value account 2>$null)"
Write-Host "== Projeto alvo: $ProjectId (os demais projetos da conta nao sao tocados)"

# 1. Projeto e faturamento
if ($CreateProject) {
  if (-not (Test-Gcloud projects describe $ProjectId)) {
    Invoke-Gcloud projects create $ProjectId --name="KubeShop Zibiska"
  }
}
if ($BillingAccountId) {
  Invoke-Gcloud billing projects link $ProjectId --billing-account=$BillingAccountId
}
$billing = & gcloud billing projects describe $ProjectId --format='value(billingEnabled)'
if ($billing -ne 'True') { throw "O projeto $ProjectId nao tem faturamento ativo. Informe -BillingAccountId." }
$projectNumber = & gcloud projects describe $ProjectId --format='value(projectNumber)'

# 2. APIs
Invoke-Gcloud services enable --project=$ProjectId `
  compute.googleapis.com iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com `
  artifactregistry.googleapis.com storage.googleapis.com cloudresourcemanager.googleapis.com `
  iap.googleapis.com serviceusage.googleapis.com logging.googleapis.com

# 3. Bucket do Terraform State
$stateBucket = "$ProjectId-tfstate"
if (-not (Test-Gcloud storage buckets describe "gs://$stateBucket" --project=$ProjectId)) {
  Invoke-Gcloud storage buckets create "gs://$stateBucket" --project=$ProjectId --location=$Region `
    --uniform-bucket-level-access --public-access-prevention
}
Invoke-Gcloud storage buckets update "gs://$stateBucket" --project=$ProjectId --versioning
$lifecycle = Join-Path ([IO.Path]::GetTempPath()) 'tfstate-lifecycle.json'
'{"rule":[{"action":{"type":"Delete"},"condition":{"isLive":false,"numNewerVersions":30}}]}' |
  Set-Content -Path $lifecycle -Encoding ascii
Invoke-Gcloud storage buckets update "gs://$stateBucket" --project=$ProjectId --lifecycle-file=$lifecycle
Remove-Item $lifecycle -Force

# 4. Service Accounts
$infraSa = "kubeshop-infra@$ProjectId.iam.gserviceaccount.com"
$ciSa = "kubeshop-ci@$ProjectId.iam.gserviceaccount.com"
if (-not (Test-Gcloud iam service-accounts describe $infraSa --project=$ProjectId)) {
  Invoke-Gcloud iam service-accounts create kubeshop-infra --project=$ProjectId `
    --display-name="KubeShop - pipelines de infraestrutura"
}
if (-not (Test-Gcloud iam service-accounts describe $ciSa --project=$ProjectId)) {
  Invoke-Gcloud iam service-accounts create kubeshop-ci --project=$ProjectId `
    --display-name="KubeShop - CI da aplicacao (publica imagens)"
}

$infraRoles = @(
  'roles/compute.admin', 'roles/iam.serviceAccountAdmin', 'roles/iam.serviceAccountUser',
  'roles/artifactregistry.admin', 'roles/storage.admin', 'roles/iap.tunnelResourceAccessor',
  'roles/serviceusage.serviceUsageConsumer'
)
foreach ($role in $infraRoles) {
  Invoke-Gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$infraSa" `
    --role=$role --condition=None --quiet | Out-Null
}
Invoke-Gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$ciSa" `
  --role=roles/artifactregistry.writer --condition=None --quiet | Out-Null

# 5. Workload Identity Federation (GitHub -> GCP, sem chaves)
$pool = 'github-actions'
$provider = 'github'
if (-not (Test-Gcloud iam workload-identity-pools describe $pool --project=$ProjectId --location=global)) {
  Invoke-Gcloud iam workload-identity-pools create $pool --project=$ProjectId --location=global `
    --display-name="GitHub Actions"
}
if (-not (Test-Gcloud iam workload-identity-pools providers describe $provider --project=$ProjectId `
      --location=global --workload-identity-pool=$pool)) {
  Invoke-Gcloud iam workload-identity-pools providers create-oidc $provider --project=$ProjectId `
    --location=global --workload-identity-pool=$pool `
    --issuer-uri='https://token.actions.githubusercontent.com' `
    "--attribute-mapping=google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" `
    "--attribute-condition=assertion.repository=='$GitHubRepo'"
}
$principal = "principalSet://iam.googleapis.com/projects/$projectNumber/locations/global/workloadIdentityPools/$pool/attribute.repository/$GitHubRepo"
foreach ($sa in @($infraSa, $ciSa)) {
  Invoke-Gcloud iam service-accounts add-iam-policy-binding $sa --project=$ProjectId `
    --role=roles/iam.workloadIdentityUser --member=$principal --condition=None --quiet | Out-Null
}
$wifProvider = "projects/$projectNumber/locations/global/workloadIdentityPools/$pool/providers/$provider"

# 6. Segredos locais (nunca versionados)
$secretsDir = Join-Path $repoRoot '.secrets\infra'
New-Item -ItemType Directory -Force $secretsDir | Out-Null
$sshKey = Join-Path $secretsDir 'pipeline_ed25519'
if (-not (Test-Path $sshKey)) {
  & ssh-keygen -t ed25519 -N '""' -C "kubeshop-pipeline" -f $sshKey | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen falhou' }
}
foreach ($name in 'mongo-root-password', 'mongo-app-password') {
  $file = Join-Path $secretsDir $name
  if (-not (Test-Path $file)) { [IO.File]::WriteAllText($file, (New-Password)) }
}
$sshPublic = (Get-Content "$sshKey.pub" -Raw).Trim()

# 7. Variaveis e secrets do GitHub
$variables = [ordered]@{
  GCP_PROJECT_ID                 = $ProjectId
  GCP_REGION                     = $Region
  GCP_ZONE                       = $Zone
  GCP_WORKLOAD_IDENTITY_PROVIDER = $wifProvider
  GCP_SERVICE_ACCOUNT            = $infraSa
  GCP_CI_SERVICE_ACCOUNT         = $ciSa
  TF_STATE_BUCKET                = $stateBucket
  SSH_PUBLIC_KEY                 = $sshPublic
}
$secretFiles = [ordered]@{
  SSH_PRIVATE_KEY     = $sshKey
  MONGO_ROOT_PASSWORD = (Join-Path $secretsDir 'mongo-root-password')
  MONGO_APP_PASSWORD  = (Join-Path $secretsDir 'mongo-app-password')
}

if (-not $SkipGitHub -and (Get-Command gh -ErrorAction SilentlyContinue)) {
  foreach ($key in $variables.Keys) { & gh variable set $key --repo $GitHubRepo --body $variables[$key] }
  foreach ($key in $secretFiles.Keys) { Get-Content $secretFiles[$key] -Raw | & gh secret set $key --repo $GitHubRepo }
  Write-Host "== Variaveis e secrets cadastrados em $GitHubRepo"
}
else {
  Write-Host ''
  Write-Host '== Cadastre manualmente em GitHub > Settings > Secrets and variables > Actions'
  Write-Host '-- Variables (Variaveis):'
  foreach ($key in $variables.Keys) { Write-Host ("   {0} = {1}" -f $key, $variables[$key]) }
  Write-Host '-- Secrets (cole o CONTEUDO do arquivo indicado):'
  foreach ($key in $secretFiles.Keys) { Write-Host ("   {0}  <-  {1}" -f $key, $secretFiles[$key]) }
}

Write-Host ''
Write-Host "== Concluido. Proximo passo: Actions > 'Infra - Provisionar e configurar' (action=plan)."
