#!/usr/bin/env bash
# Constroi e publica as imagens da aplicacao no Artifact Registry.
# Uso: build-push-images.sh <tag>
# Variaveis: REGISTRY_URL (ex.: southamerica-east1-docker.pkg.dev/projeto/kubeshop); FORCE_REBUILD=true para sobrescrever.
# Pre-requisito: autenticacao do Docker no registry (gcloud auth configure-docker).
set -euo pipefail

tag="${1:?uso: build-push-images.sh <tag>}"
registry="${REGISTRY_URL:?REGISTRY_URL nao definido}"
[[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] || { echo "::error::tag invalida: $tag"; exit 1; }
cd "$(dirname "$0")/../.."

build() { # nome dockerfile
  local image="${registry}/$1:${tag}"
  if [[ "${FORCE_REBUILD:-false}" != "true" ]] && gcloud artifacts docker images describe "$image" >/dev/null 2>&1; then
    echo "Imagem $image ja existe; mantida (tags reproduziveis). Use force_rebuild para sobrescrever."
    return 0
  fi
  docker build --pull -f "$2" -t "$image" .
  docker push "$image"
  echo "Publicada: $image"
}

build api apps/backend/Dockerfile
build frontend apps/frontend/Dockerfile
