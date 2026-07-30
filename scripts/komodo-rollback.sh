#!/usr/bin/env bash
# Komodo → Manual Rollback Script
# Restores NetBird stack to pre-Komodo state using the timestamped backup.
#
# Usage:
#   sudo bash komodo-rollback.sh <timestamp>
#
# Example:
#   sudo bash komodo-rollback.sh 20260730-231500

set -euo pipefail

TIMESTAMP="${1:-}"
if [[ -z "${TIMESTAMP}" ]]; then
    echo "Usage: $0 <timestamp>"
    echo "Example: $0 20260730-231500"
    echo ""
    echo "Available backups:"
    ls -d /opt/stacks/netbird-pre-komodo-* 2>/dev/null || echo "  (none found)"
    exit 1
fi

BACKUP_DIR="/opt/stacks/netbird-pre-komodo-${TIMESTAMP}"
STACK_DIR="/opt/stacks/netbird"
PROJECT_NAME="netbird"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=============================================="
echo "  NetBird Komodo → Manual Rollback"
echo "==============================================${NC}"
echo ""
echo "Backup:  ${BACKUP_DIR}"
echo "Stack:   ${STACK_DIR}"
echo "Project: ${PROJECT_NAME}"
echo ""

# ─── Verify backup exists ──────────────────────────────────────────────────

if [[ ! -d "${BACKUP_DIR}" ]]; then
    echo -e "${RED}[ERR]${NC} Backup not found: ${BACKUP_DIR}"
    echo ""
    echo "Available backups:"
    ls -d /opt/stacks/netbird-pre-komodo-* 2>/dev/null || echo "  (none found)"
    exit 1
fi

echo "Backup contents:"
ls -lh "${BACKUP_DIR}/"
echo ""

# ─── Confirmation ──────────────────────────────────────────────────────────

echo -e "${RED}WARNING: This will:${NC}"
echo "  1. Stop the Komodo-managed stack (if running)"
echo "  2. Restore config files from backup"
echo "  3. Restore databases from backup"
echo "  4. Start the stack with 'docker compose -p ${PROJECT_NAME} up -d'"
echo ""

read -p "Are you sure? Type 'ROLLBACK' to confirm: " CONFIRM
if [[ "${CONFIRM}" != "ROLLBACK" ]]; then
    echo "Rollback cancelled."
    exit 0
fi

echo ""

# ─── Step 1: Stop Komodo-managed stack ────────────────────────────────────

echo "=== Step 1: Stop Komodo-managed stack ==="

if docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" --format '{{.Names}}' | grep -q netbird; then
    echo "Stopping running containers..."
    docker compose -p "${PROJECT_NAME}" stop 2>/dev/null || true
    docker compose -p "${PROJECT_NAME}" down 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} Stack stopped"
else
    echo "No running containers found — skipping stop"
fi

# ─── Step 2: Restore config files ──────────────────────────────────────────

echo ""
echo "=== Step 2: Restore config files ==="

RESTORE_FILES=(
    "config.yaml"
    "dashboard.env"
    "proxy.env"
)

for f in "${RESTORE_FILES[@]}"; do
    if [[ -f "${BACKUP_DIR}/${f}" ]]; then
        cp -a "${BACKUP_DIR}/${f}" "${STACK_DIR}/${f}"
        echo -e "${GREEN}[OK]${NC} Restored: ${f}"
    else
        echo -e "${YELLOW}[WARN]${NC} Not in backup: ${f}"
    fi
done

# ─── Step 3: Restore databases ─────────────────────────────────────────────

echo ""
echo "=== Step 3: Restore databases ==="

DB_FILES=(
    "data/netbird/store.db"
    "data/netbird/idp.db"
)

for f in "${DB_FILES[@]}"; do
    if [[ -f "${BACKUP_DIR}/${f}" ]]; then
        cp -a "${BACKUP_DIR}/${f}" "${STACK_DIR}/${f}"
        echo -e "${GREEN}[OK]${NC} Restored: ${f}"
    else
        echo -e "${YELLOW}[WARN]${NC} Not in backup: ${f}"
    fi
done

# ─── Step 4: Verify checksums ──────────────────────────────────────────────

echo ""
echo "=== Step 4: Verify restored files ==="

if [[ -f "${BACKUP_DIR}/SHA256SUMS-pre" ]]; then
    cd "${STACK_DIR}"
    if sha256sum -c "${BACKUP_DIR}/SHA256SUMS-pre" 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC} All checksums match"
    else
        echo -e "${RED}[ERR]${NC} Checksum mismatch — check restored files manually!"
        sha256sum -c "${BACKUP_DIR}/SHA256SUMS-pre" || true
    fi
fi

# ─── Step 5: Start stack manually ──────────────────────────────────────────

echo ""
echo "=== Step 5: Start stack ==="

cd "${STACK_DIR}"
docker compose -p "${PROJECT_NAME}" up -d

echo -e "${GREEN}[OK]${NC} Stack started with project name: ${PROJECT_NAME}"

# ─── Step 6: Quick verification ────────────────────────────────────────────

echo ""
echo "=== Step 6: Quick verification ==="

sleep 5

echo ""
echo "Container status:"
docker compose -p "${PROJECT_NAME}" ps --format 'table {{.Name}}\t{{.Status}}'

echo ""
echo "Health checks:"
curl -sf http://localhost:9000/health && echo -e "${GREEN}[OK]${NC} Server health OK" || echo -e "${RED}[FAIL]${NC} Server health FAIL"
curl -sf -o /dev/null -w "Dashboard: HTTP %{http_code}\n" https://netb.koorpa.ba || echo -e "${RED}[FAIL]${NC} Dashboard unreachable"

echo ""
echo -e "${GREEN}=============================================="
echo "  Rollback Complete"
echo "==============================================${NC}"
echo ""
echo "Stack is now running under manual docker compose."
echo "To verify fully, run: sudo bash scripts/komodo-verify.sh"
echo ""
echo "Note: You may want to remove the Komodo stack resource from the Komodo UI"
echo "to prevent conflicts if you re-import later."
