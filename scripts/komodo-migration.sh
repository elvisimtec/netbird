#!/usr/bin/env bash
# NetBird → Komodo Migration Script
# Run on the server as root BEFORE importing the stack into Komodo.
#
# Usage:
#   sudo bash komodo-migration.sh [--dry-run]
#
# This script:
#   1. Verifies Periphery access
#   2. Checks SQLite integrity
#   3. Creates timestamped backup with checksums
#   4. Verifies compose project name
#   5. Prepares directory for Komodo import
#   6. Provides pre-import verification checklist

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE — no changes will be made ==="
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
STACK_DIR="/opt/stacks/netbird"
BACKUP_DIR="/opt/stacks/netbird-pre-komodo-${TIMESTAMP}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; }

# ─── Step 1: Verify Periphery access ────────────────────────────────────────

echo ""
echo "=== Step 1: Verify Periphery Access ==="

if systemctl is-active --quiet periphery 2>/dev/null; then
    log "Periphery systemd service is active"
    PERIPHERY_MODE="systemd"
elif docker ps --filter name=periphery --format '{{.Names}}' | grep -q periphery; then
    log "Periphery running as Docker container"
    PERIPHERY_MODE="container"
    warn "Periphery in container mode — verify mounts include ${STACK_DIR}"
    docker inspect komodo-periphery --format '{{json .Mounts}}' 2>/dev/null | python3 -m json.tool || true
else
    err "Periphery not found! Is Komodo agent installed?"
    warn "Check: systemctl status periphery || docker ps --filter name=periphery"
fi

# Verify stack directory is accessible
if [[ -d "${STACK_DIR}" ]] && [[ -r "${STACK_DIR}/docker-compose.yml" ]]; then
    log "Stack directory ${STACK_DIR} exists and is readable"
else
    err "Stack directory ${STACK_DIR} not found or docker-compose.yml missing"
    exit 1
fi

# ─── Step 2: Verify compose project name ───────────────────────────────────

echo ""
echo "=== Step 2: Verify Compose Project Name ==="

cd "${STACK_DIR}"

# Get current project name from running containers
PROJECT_NAME=$(docker inspect netbird-server \
    --format '{{ index .Config.Labels "com.docker.compose.project" }}' 2>/dev/null || echo "")

if [[ -n "${PROJECT_NAME}" ]]; then
    log "Current compose project name: ${PROJECT_NAME}"
else
    warn "Could not determine project name from running container (stack might be stopped)"
    PROJECT_NAME="netbird"
    warn "Assuming project name: ${PROJECT_NAME}"
fi

# List all compose projects
echo ""
echo "Current compose projects:"
docker compose ls 2>/dev/null || docker compose -p netbird ps 2>/dev/null || true

# ─── Step 3: SQLite integrity check ────────────────────────────────────────

echo ""
echo "=== Step 3: SQLite Integrity Check ==="

STORE_DB="${STACK_DIR}/data/netbird/store.db"
IDP_DB="${STACK_DIR}/data/netbird/idp.db"

for db in "${STORE_DB}" "${IDP_DB}"; do
    if [[ -f "${db}" ]]; then
        result=$(sqlite3 "${db}" 'PRAGMA integrity_check;' 2>&1)
        if [[ "${result}" == "ok" ]]; then
            log "Integrity check passed: ${db}"
        else
            err "Integrity check FAILED: ${db}"
            echo "  Result: ${result}"
            warn "Do NOT proceed with migration until this is fixed."
            if [[ "${DRY_RUN}" != "true" ]]; then
                exit 1
            fi
        fi
    else
        warn "Database not found: ${db}"
    fi
done

# ─── Step 4: Create backup with checksums ──────────────────────────────────

echo ""
echo "=== Step 4: Create Backup ==="

FILES_TO_BACKUP=(
    "config.yaml"
    "dashboard.env"
    "proxy.env"
    "docker-compose.yml"
    "traefik-dynamic.yaml"
    "data/netbird/store.db"
    "data/netbird/idp.db"
)

if [[ "${DRY_RUN}" == "true" ]]; then
    log "Would create backup at: ${BACKUP_DIR}"
    for f in "${FILES_TO_BACKUP[@]}"; do
        if [[ -f "${STACK_DIR}/${f}" ]]; then
            echo "  → ${f}"
        else
            echo "  → ${f} (MISSING)"
        fi
    done
else
    mkdir -p "${BACKUP_DIR}/data/netbird"
    mkdir -p "${BACKUP_DIR}/data/letsencrypt"
    mkdir -p "${BACKUP_DIR}/data/proxy-certs"

    for f in "${FILES_TO_BACKUP[@]}"; do
        src="${STACK_DIR}/${f}"
        dst="${BACKUP_DIR}/${f}"
        if [[ -f "${src}" ]]; then
            cp -a "${src}" "${dst}"
            log "Backed up: ${f}"
        else
            warn "Skipped (not found): ${f}"
        fi
    done

    # Copy letsencrypt if exists
    if [[ -d "${STACK_DIR}/data/letsencrypt" ]]; then
        cp -a "${STACK_DIR}/data/letsencrypt" "${BACKUP_DIR}/data/"
        log "Backed up: data/letsencrypt/"
    fi

    # Copy proxy-certs if exists
    if [[ -d "${STACK_DIR}/data/proxy-certs" ]]; then
        cp -a "${STACK_DIR}/data/proxy-certs" "${BACKUP_DIR}/data/"
        log "Backed up: data/proxy-certs/"
    fi

    # Generate checksum manifest
    cd "${BACKUP_DIR}"
    sha256sum \
        config.yaml \
        dashboard.env \
        proxy.env \
        data/netbird/store.db \
        data/netbird/idp.db \
        > "${BACKUP_DIR}/SHA256SUMS" 2>/dev/null || true
    log "Checksum manifest: ${BACKUP_DIR}/SHA256SUMS"

    # Also create checksums in stack directory for post-migration verification
    cd "${STACK_DIR}"
    sha256sum \
        config.yaml \
        dashboard.env \
        proxy.env \
        data/netbird/store.db \
        data/netbird/idp.db \
        > "${BACKUP_DIR}/SHA256SUMS-pre" 2>/dev/null || true

    echo ""
    log "Backup created: ${BACKUP_DIR}"
    echo ""
    echo "Backup contents:"
    ls -lh "${BACKUP_DIR}/"
    echo ""
    echo "Checksums:"
    cat "${BACKUP_DIR}/SHA256SUMS" 2>/dev/null || echo "  (no checksum files generated)"
fi

# ─── Step 5: Pre-import checklist ──────────────────────────────────────────

echo ""
echo "=============================================="
echo "=== Step 5: Pre-Import Verification ==="
echo "=============================================="
echo ""
echo "Before importing into Komodo, verify:"
echo ""
echo "  1. Project name in Komodo TOML matches:"
echo "     project_name = \"${PROJECT_NAME}\""
echo ""
echo "  2. Komodo resource TOML has deploy = false for first import"
echo ""
echo "  3. Server 'NetBird' is visible in Komodo UI"
echo ""
echo "  4. Git account 'imtec' is configured in Komodo for git.imtec.ba"
echo ""
echo "  5. Secret files will survive Komodo Git operations:"
echo "     - config.yaml, dashboard.env, proxy.env are gitignored ✓"
echo "     - data/ directory is gitignored ✓"
echo "     - traefik-dynamic.yaml IS in repo ✓"
echo ""
echo "  6. Backup is at: ${BACKUP_DIR}"
echo ""

if [[ "${DRY_RUN}" != "true" ]]; then
    echo "=== Checksums for post-migration verification ==="
    cat "${BACKUP_DIR}/SHA256SUMS-pre" 2>/dev/null || echo "  (no checksums)"
    echo ""
fi

# ─── Step 6: Migration instructions ────────────────────────────────────────

echo "=============================================="
echo "=== Step 6: Migration Sequence ==="
echo "=============================================="
echo ""
echo "After verifying all checks above, proceed in this order:"
echo ""
echo "  A. Import resources/komodo-stack.toml into Komodo UI"
echo "     (Resources → Import TOML)"
echo "     → Komodo will show proposed changes without deploying"
echo ""
echo "  B. Verify in Komodo UI that it sees the existing '${PROJECT_NAME}' project"
echo "     (not creating a new parallel stack)"
echo ""
echo "  C. Stop the current stack:"
echo "     docker compose -p ${PROJECT_NAME} stop"
echo ""
echo "  D. Deploy from Komodo UI"
echo ""
echo "  E. Run post-migration verification:"
echo "     bash scripts/komodo-verify.sh"
echo ""
echo "  F. If verification fails, rollback:"
echo "     bash scripts/komodo-rollback.sh ${TIMESTAMP}"
echo ""

echo "=== Done ==="
log "Pre-migration checks complete"
echo "Backup location: ${BACKUP_DIR}"
