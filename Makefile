# NetBird Infrastructure Makefile
# Operational commands for managing the NetBird deployment.

.PHONY: help deploy down restart status logs logs-server logs-proxy \
        health-check backup update clean ssh

# Default target
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Deployment ───────────────────────────────────────────────────────────────

deploy: ## Deploy/start all services
	docker compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@$(MAKE) status

down: ## Stop all services
	docker compose down

restart: ## Restart all services
	docker compose restart
	@sleep 3
	@$(MAKE) status

# ─── Status & Monitoring ──────────────────────────────────────────────────────

status: ## Show service status
	@docker compose ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

logs: ## Tail all service logs (follow)
	docker compose logs -f --tail=50

logs-server: ## Tail NetBird server logs
	docker compose logs -f --tail=50 netbird-server

logs-dashboard: ## Tail dashboard logs
	docker compose logs -f --tail=50 netbird-dashboard

logs-proxy: ## Tail proxy logs
	docker compose logs -f --tail=50 netbird-proxy

logs-traefik: ## Tail Traefik logs
	docker compose logs -f --tail=50 netbird-traefik

health-check: ## Run health checks on all services
	@echo "=== Container Status ==="
	@docker compose ps --format 'table {{.Name}}\t{{.Status}}'
	@echo ""
	@echo "=== NetBird Server Health ==="
	@curl -sf http://localhost:9000/health && echo "OK" || echo "FAIL"
	@echo ""
	@echo "=== Dashboard Reachable ==="
	@curl -sf -o /dev/null -w "HTTP %{http_code}" https://netb.koorpa.ba && echo "" || echo "FAIL"

# ─── Backup & Restore ─────────────────────────────────────────────────────────

backup: ## Create a backup of volumes and config
	@backup_dir="backup-$$(date +%Y%m%d-%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	echo "Creating backup in $$backup_dir ..."; \
	cp docker-compose.yml config.yaml dashboard.env proxy.env traefik-dynamic.yaml "$$backup_dir/"; \
	echo "Config files copied."; \
	echo "To backup SQLite data, run: docker compose exec netbird-server sqlite3 /var/lib/netbird/store.db .dump > $$backup_dir/store.sql"; \
	echo "Backup created: $$backup_dir"

# ─── Updates ──────────────────────────────────────────────────────────────────

update: ## Update all Docker images and restart
	@echo "Pulling latest images..."
	docker compose pull
	@echo "Restarting services with new images..."
	docker compose up -d --remove-orphans
	@sleep 5
	@$(MAKE) status
	@echo "To clean up old images, run: docker image prune -f"

update-stack: backup update ## Backup then update (safe update)

# ─── Maintenance ──────────────────────────────────────────────────────────────

clean: ## Stop and remove containers (keeps volumes and config)
	docker compose down

clean-all: ## Stop and remove containers AND volumes (DESTRUCTIVE)
	@echo "WARNING: This will remove all Docker volumes and data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "All containers and volumes removed."; \
	else \
		echo "Cancelled."; \
	fi

prune: ## Remove unused Docker resources
	docker system prune -f
	@echo "Unused Docker resources cleaned."

# ─── SSH ──────────────────────────────────────────────────────────────────────

ssh: ## Connect to the NetBird server via SSH
	ssh netbird

# ─── Validation ───────────────────────────────────────────────────────────────

validate: ## Validate Docker Compose configuration
	docker compose config --quiet && echo "Configuration is valid." || echo "Configuration has errors."

lint: ## Lint all YAML and Markdown files
	@echo "Checking Docker Compose config..."
	@docker compose config --quiet || echo "Docker Compose validation failed"
	@echo "Checking for secrets in files..."
	@! grep -rE 'NB_PROXY_TOKEN|authSecret|encryptionKey|3lv1s' --include='*.yml' --include='*.yaml' --include='*.md' --include='*.env' . 2>/dev/null || echo "WARNING: Potential secrets found in tracked files"
