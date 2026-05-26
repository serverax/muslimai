#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# Cloudflare DNS setup for SakinaAI / 7jzi.com
# ==================================================

DOMAIN="${DOMAIN:-7jzi.com}"
ORIGIN_IP="${ORIGIN_IP:-148.251.247.56}"

# Set to false for initial Kubernetes / Traefik testing.
# Set to true later if you want Cloudflare proxy enabled.
PROXIED="${PROXIED:-false}"

TTL="${TTL:-1}" # 1 = automatic TTL in Cloudflare

RECORDS=(
  "${DOMAIN}"
  "www.${DOMAIN}"
  "api.${DOMAIN}"
)

echo "=================================================="
echo " Cloudflare DNS Setup for SakinaAI"
echo "=================================================="
echo "Domain:       ${DOMAIN}"
echo "Origin IP:    ${ORIGIN_IP}"
echo "Proxied:      ${PROXIED}"
echo "TTL:          ${TTL}"
echo ""

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is not installed."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is not installed."
  echo "Install it with:"
  echo "  sudo apt update && sudo apt install -y jq"
  exit 1
fi

if [ -z "${CF_API_TOKEN:-}" ]; then
  echo "ERROR: CF_API_TOKEN is not set."
  echo ""
  echo "Set it first:"
  echo "  export CF_API_TOKEN='your_cloudflare_api_token'"
  echo ""
  echo "Required token permissions:"
  echo "  Zone:Read"
  echo "  DNS:Edit"
  echo ""
  exit 1
fi

CF_API="https://api.cloudflare.com/client/v4"

cf_get() {
  curl -sS \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$1"
}

cf_post() {
  curl -sS -X POST \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$2" \
    "$1"
}

cf_put() {
  curl -sS -X PUT \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$2" \
    "$1"
}

echo "Verifying Cloudflare API token..."

VERIFY_RESPONSE="$(cf_get "${CF_API}/user/tokens/verify")"
VERIFY_SUCCESS="$(echo "$VERIFY_RESPONSE" | jq -r '.success')"

if [ "$VERIFY_SUCCESS" != "true" ]; then
  echo "ERROR: Cloudflare token verification failed."
  echo "$VERIFY_RESPONSE" | jq
  echo ""
  echo "Create a new Cloudflare API token with:"
  echo "  Zone:Read"
  echo "  DNS:Edit"
  echo "  Zone Resources: Include specific zone -> ${DOMAIN}"
  exit 1
fi

echo "Token verified."
echo ""

echo "Finding Cloudflare zone for ${DOMAIN}..."

ZONE_RESPONSE="$(cf_get "${CF_API}/zones?name=${DOMAIN}")"
ZONE_ID="$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id // empty')"

if [ -z "$ZONE_ID" ]; then
  echo "ERROR: Could not find Cloudflare zone for ${DOMAIN}."
  echo "$ZONE_RESPONSE" | jq
  echo ""
  echo "Check that ${DOMAIN} is added to your Cloudflare account."
  exit 1
fi

echo "Zone ID found: ${ZONE_ID}"
echo ""

create_or_update_a_record() {
  local NAME="$1"
  local TYPE="A"

  echo "Processing ${TYPE} record: ${NAME} -> ${ORIGIN_IP}"

  local LIST_RESPONSE
  LIST_RESPONSE="$(cf_get "${CF_API}/zones/${ZONE_ID}/dns_records?type=${TYPE}&name=${NAME}")"

  local RECORD_ID
  RECORD_ID="$(echo "$LIST_RESPONSE" | jq -r '.result[0].id // empty')"

  local PAYLOAD
  PAYLOAD="$(jq -n \
    --arg type "$TYPE" \
    --arg name "$NAME" \
    --arg content "$ORIGIN_IP" \
    --argjson ttl "$TTL" \
    --argjson proxied "$PROXIED" \
    '{
      type: $type,
      name: $name,
      content: $content,
      ttl: $ttl,
      proxied: $proxied,
      comment: "SakinaAI Kubernetes ingress"
    }')"

  local RESPONSE
  local SUCCESS

  if [ -z "$RECORD_ID" ]; then
    echo "  Creating new record..."
    RESPONSE="$(cf_post "${CF_API}/zones/${ZONE_ID}/dns_records" "$PAYLOAD")"
  else
    echo "  Updating existing record: ${RECORD_ID}"
    RESPONSE="$(cf_put "${CF_API}/zones/${ZONE_ID}/dns_records/${RECORD_ID}" "$PAYLOAD")"
  fi

  SUCCESS="$(echo "$RESPONSE" | jq -r '.success')"

  if [ "$SUCCESS" != "true" ]; then
    echo "ERROR: Failed to create/update ${NAME}"
    echo "$RESPONSE" | jq
    exit 1
  fi

  echo "  OK"
}

for RECORD in "${RECORDS[@]}"; do
  create_or_update_a_record "$RECORD"
done

echo ""
echo "=================================================="
echo " Final DNS records"
echo "=================================================="

for RECORD in "${RECORDS[@]}"; do
  cf_get "${CF_API}/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD}" \
    | jq -r '.result[] | "\(.type) \(.name) -> \(.content) proxied=\(.proxied) ttl=\(.ttl)"'
done

echo ""
echo "=================================================="
echo " SakinaAI links"
echo "=================================================="
echo "Frontend:"
echo "  http://${DOMAIN}"
echo "  http://www.${DOMAIN}"
echo ""
echo "Backend API:"
echo "  http://api.${DOMAIN}"
echo ""
echo "Backend health:"
echo "  http://api.${DOMAIN}/health"
echo ""
echo "Backend readiness:"
echo "  http://api.${DOMAIN}/ready"
echo ""
echo "Backend metrics:"
echo "  http://api.${DOMAIN}/metrics"
echo ""
echo "Done."
