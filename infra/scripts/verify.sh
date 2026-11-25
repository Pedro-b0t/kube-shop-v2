#!/usr/bin/env bash
# Valida a loja implantada e o isolamento do banco, gerando evidencias no resumo da execucao.
# Variaveis: STORE_URL (obrigatoria), APP_PUBLIC_IP, DB_PUBLIC_IP (esperado vazio), ORDER_ID (opcional).
# Sem ORDER_ID cria um pedido ficticio e informa o id; com ORDER_ID confere que o pedido foi preservado.
set -uo pipefail

store="${STORE_URL:?STORE_URL nao definido}"
store="${store%/}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
fail=0
{
  echo "### Validacao da loja e do isolamento"
  echo "| Verificacao | Resultado |"
  echo "|---|---|"
} >> "$summary"

check() { # descricao comando...
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $name"; echo "| $name | PASS |" >> "$summary"
  else
    echo "FAIL  $name"; echo "| $name | FAIL |" >> "$summary"; fail=1
  fi
}

port_closed() { ! timeout 6 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }
http_status() { [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$1")" == "$2" ]]; }
has_products() { curl -fsS --max-time 10 "$store/api/products" | jq -e '.products | length > 0'; }
ready() { curl -fsS --retry 10 --retry-delay 6 --retry-all-errors --max-time 10 "$store/api/health/ready"; }

check "ACE-04 Pagina inicial da loja (GET /) = 200" http_status "$store/" 200
check "ACE-03 API conectada ao banco pela rede privada (/api/health/ready) = 200" ready
check "ACE-04 Catalogo carregado (/api/products)" has_products
check "Rotas de laboratorio ausentes (/api/metrics = 404)" http_status "$store/api/metrics" 404

if [[ -n "${ORDER_ID:-}" ]]; then
  order_exists() { curl -fsS --max-time 10 "$store/api/orders" | jq -e --arg id "$ORDER_ID" '.orders | any(.id == $id)'; }
  check "ACE-05 Pedido $ORDER_ID preservado" order_exists
else
  product_id="$(curl -fsS --max-time 10 "$store/api/products" | jq -r '.products[0].id')"
  response="$(curl -fsS --max-time 10 -X POST -H 'Content-Type: application/json' \
    -d "{\"items\":[{\"productId\":\"${product_id}\",\"quantity\":1}]}" "$store/api/orders" || true)"
  order_id="$(jq -r '.order.id // empty' <<<"$response" 2>/dev/null)"
  if [[ -n "$order_id" ]]; then
    echo "PASS  Pedido ficticio criado: $order_id"
    echo "| ACE-04 Pedido ficticio criado: \`$order_id\` | PASS |" >> "$summary"
    echo "order_id=${order_id}" >> "${GITHUB_OUTPUT:-/dev/null}"
    order_listed() { curl -fsS --max-time 10 "$store/api/orders" | jq -e --arg id "$order_id" '.orders | any(.id == $id)'; }
    check "ACE-04 Pedido consultado no historico" order_listed
  else
    echo "FAIL  Criacao de pedido"; echo "| Criacao de pedido | FAIL |" >> "$summary"; fail=1
  fi
fi

if [[ -n "${APP_PUBLIC_IP:-}" ]]; then
  check "ACE-03 Porta 27017 (MongoDB) fechada no IP publico ${APP_PUBLIC_IP}" port_closed "$APP_PUBLIC_IP" 27017
  check "Porta 22 (SSH) fechada no IP publico ${APP_PUBLIC_IP}" port_closed "$APP_PUBLIC_IP" 22
fi
check "ACE-03 VM do banco sem IP publico" test -z "${DB_PUBLIC_IP:-}"

echo "" >> "$summary"
exit "$fail"
