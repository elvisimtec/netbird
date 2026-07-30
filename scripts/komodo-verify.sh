#!/usr/bin/env bash
# Post-Komodo migration verification script
# Run on the server after deploying the stack through Komodo.
#
# Usage:
#   sudo bash komodo-verify.sh [backup_timestamp]

set -euo pipefail

TIMESTAMP="${1:-}"
STACK_DIR="/opt/stacks/netbird"
PROJECT_NAME="netbird"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local desc="$1"
    if eval "$2" &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} ${desc}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} ${desc}"
        ((FAIL++))
        return 1
    fi
}

echo "=============================================="
echo "  NetBird Post-Komodo Migration Verification"
echo "=============================================="
echo ""

# ─── 1. Komodo manages the correct compose project ─────────────────────────

echo "=== 1. Compose Project ==="

check "Stack running with project name '${PROJECT_NAME}'" \
    "docker compose -p ${PROJECT_NAME} ps --format '{{.Name}}' | grep -q netbird"

check "Containers have correct compose project label" \
    "docker ps --filter 'label=com.docker.compose.project=${PROJECT_NAME}' --format '{{.Names}}' | grep -q netbird"

echo ""
echo "=== 2. Container Status ==="

docker compose -p "${PROJECT_NAME}" ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || \
    docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo ""

check "netbird-traefik is running" \
    "docker ps --filter name=netbird-traefik --filter status=running --format '{{.Names}}' | grep -q netbird-traefik"

check "netbird-dashboard is running" \
    "docker ps --filter name=netbird-dashboard --filter status=running --format '{{.Names}}' | grep -q netbird-dashboard"

check "netbird-server is running" \
    "docker ps --filter name=netbird-server --filter status=running --format '{{.Names}}' | grep -q netbird-server"

check "netbird-proxy is running" \
    "docker ps --filter name=netbird-proxy --filter status=running --format '{{.Names}}' | grep -q netbird-proxy"

# ─── 2. Service health ─────────────────────────────────────────────────────

echo ""
echo "=== 3. Service Health ==="

check "Server health endpoint (port 9000)" \
    "curl -sf http://localhost:9000/health"

check "Dashboard responds (HTTP 200)" \
    "curl -sf -o /dev/null -w '%{http_code}' https://netb.koorpa.ba | grep -q 200"

# ─── 3. Published ports ────────────────────────────────────────────────────

echo ""
echo "=== 4. Published Ports ==="

check "Port 443/tcp published" \
    "ss -tlnp | grep -q ':443 '"

check "Port 80/tcp published" \
    "ss -tlnp | grep -q ':80 '"

check "Port 3478/udp published (STUN)" \
    "ss -ulnp | grep -q ':3478 '"

check "Port 51820/udp published (WireGuard)" \
    "ss -ulnp | grep -q ':51820 '"

# ─── 4. SQLite data integrity ──────────────────────────────────────────────

echo ""
echo "=== 5. SQLite Data Integrity ==="

STORE_DB="${STACK_DIR}/data/netbird/store.db"
IDP_DB="${STACK_DIR}/data/netbird/idp.db"

if [[ -f "${STORE_DB}" ]]; then
    result=$(sqlite3 "${STORE_DB}" 'PRAGMA integrity_check;' 2>&1)
    if [[ "${result}" == "ok" ]]; then
        check "store.db integrity OK" "true"
    else
        check "store.db integrity OK" "false"
        echo "  Result: ${result}"
    fi
else
    echo -e "${RED}[FAIL]${NC} store.db not found"
    ((FAIL++))
fi

if [[ -f "${IDP_DB}" ]]; then
    result=$(sqlite3 "${IDP_DB}" 'PRAGMA integrity_check;' 2>&1)
    if [[ "${result}" == "ok" ]]; then
        check "idp.db integrity OK" "true"
    else
        check "idp.db integrity OK" "false"
        echo "  Result: ${result}"
    fi
fi

# ─── 5. Secret files still present ─────────────────────────────────────────

echo ""
echo "=== 6. Secret Files ==="

check "config.yaml present" \
    "test -f ${STACK_DIR}/config.yaml"

check "dashboard.env present" \
    "test -f ${STACK_DIR}/dashboard.env"

check "proxy.env present" \
    "test -f ${STACK_DIR}/proxy.env"

# ─── 6. Checksum verification (if backup timestamp provided) ───────────────

if [[ -n "${TIMESTAMP}" ]]; then
    BACKUP_DIR="/opt/stacks/netbird-pre-komodo-${TIMESTAMP}"
    CHECKSUM_FILE="${BACKUP_DIR}/SHA256SUMS-pre"

    echo ""
    echo "=== 7. Checksum Verification (vs ${TIMESTAMP}) ==="

    if [[ -f "${CHECKSUM_FILE}" ]]; then
        cd "${STACK_DIR}"
        if sha256sum -c "${CHECKSUM_FILE}" &>/dev/null; then
            check "All checksums match pre-migration backup" "true"
        else
            echo -e "${RED}[FAIL]${NC} Checksum mismatch detected!"
            sha256sum -c "${CHECKSUM_FILE}" 2>&1 || true
            ((FAIL++))
        fi
    else
        warn "Checksum file not found: ${CHECKSUM_FILE}"
    fi
fi

# ─── 7. Recent logs (noise check) ──────────────────────────────────────────

echo ""
echo "=== 8. Recent Server Logs (last 20 lines) ==="
docker logs --tail 20 netbird-server 2>/dev/null || echo "  (could not read logs)"

# ─── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "=============================================="
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "=============================================="

if [[ "${FAIL}" -gt 0 ]]; then
    echo ""
    echo -e "${RED}Verification FAILED.${NC}"
    echo "Review failures above. To rollback:"
    echo "  sudo bash scripts/komodo-rollback.sh ${TIMESTAMP}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All checks passed!${NC}"
    echo "NetBird stack is now managed by Komodo."
fi
