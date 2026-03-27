#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  MockServer API Test Script
#  Tests the mocked endpoints configured in mockserver-init.json
# ─────────────────────────────────────────────────────────────────────────────

set -e

MOCKSERVER_URL="http://localhost:1080"

echo "Testing MockServer endpoints..."
echo "MockServer URL: $MOCKSERVER_URL"
echo ""

# ── Test 1: Portal da Transparência — Contratos (página 1) ──────────────────
echo "1. Testing: GET /api-de-dados/contratos?pagina=1"
curl -s -X GET "$MOCKSERVER_URL/api-de-dados/contratos?pagina=1" \
  -H "Content-Type: application/json" | jq '.' 2>/dev/null || echo "Response received (jq not available for pretty-print)"
echo ""

# ── Test 2: Portal da Transparência — Contratos (página 2, sem resultados) ───
echo "2. Testing: GET /api-de-dados/contratos?pagina=2"
curl -s -X GET "$MOCKSERVER_URL/api-de-dados/contratos?pagina=2" \
  -H "Content-Type: application/json" | jq '.' 2>/dev/null || echo "Response received (jq not available for pretty-print)"
echo ""

# ── Test 3: Portal da Transparência — Despesas por órgão ─────────────────────
echo "3. Testing: GET /api-de-dados/despesas/por-orgao?pagina=1"
curl -s -X GET "$MOCKSERVER_URL/api-de-dados/despesas/por-orgao?pagina=1" \
  -H "Content-Type: application/json" | jq '.' 2>/dev/null || echo "Response received (jq not available for pretty-print)"
echo ""

# ── Test 4: Portal da Transparência — Convênios ──────────────────────────────
echo "4. Testing: GET /api-de-dados/convenios?pagina=1"
curl -s -X GET "$MOCKSERVER_URL/api-de-dados/convenios?pagina=1" \
  -H "Content-Type: application/json" | jq '.' 2>/dev/null || echo "Response received (jq not available for pretty-print)"
echo ""

# ── Test 5: API Datalake Tesouro — Custos por função ────────────────────────
echo "5. Testing: GET /ords/siconfi/api/v1/relatorio_cotas"
curl -s -X GET "$MOCKSERVER_URL/ords/siconfi/api/v1/relatorio_cotas" \
  -H "Content-Type: application/json" | jq '.' 2>/dev/null || echo "Response received (jq not available for pretty-print)"
echo ""

# ── Test 6: Fallback — Rate Limit Test ────────────────────────────────────────
echo "6. Testing: GET /api-de-dados/rate-limit-test (should return 429)"
curl -s -X GET "$MOCKSERVER_URL/api-de-dados/rate-limit-test" \
  -H "Content-Type: application/json" | jq '.' 2>/dev/null || echo "Response received (jq not available for pretty-print)"
echo ""

echo "All tests completed!"