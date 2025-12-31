# =============================================================================
# Home Stream Server - Makefile
# =============================================================================
# Interactive setup and management for Docker Compose and Podman Quadlet
#
# Usage:
#   make setup      - Interactive setup wizard
#   make compose    - Setup Docker Compose only
#   make quadlet    - Setup Podman Quadlet only
#   make start      - Start services
#   make stop       - Stop services
#   make status     - Check service status
#   make logs       - View logs
#   make update     - Update all images
#   make clean      - Remove all data (DANGEROUS!)
# =============================================================================

.PHONY: setup compose quadlet start stop status logs update clean help \
        compose-start compose-stop compose-logs compose-status compose-update \
        quadlet-start quadlet-stop quadlet-logs quadlet-status quadlet-update \
        dirs permissions check-env validate

# Detect container runtime
DOCKER := $(shell command -v docker 2>/dev/null)
PODMAN := $(shell command -v podman 2>/dev/null)

ifdef PODMAN
    RUNTIME := podman
    COMPOSE := podman compose
else ifdef DOCKER
    RUNTIME := docker
    COMPOSE := docker compose
else
    RUNTIME := none
endif

# Colors
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BOLD := \033[1m
NC := \033[0m

# =============================================================================
# Main Targets
# =============================================================================

## help: Show this help message
help:
	@echo ""
	@echo "$(BOLD)$(CYAN)🎬 Home Stream Server - Make Commands$(NC)"
	@echo ""
	@echo "$(BOLD)Setup Commands:$(NC)"
	@echo "  $(CYAN)make setup$(NC)       Interactive setup wizard (recommended)"
	@echo "  $(CYAN)make compose$(NC)     Setup Docker Compose only"
	@echo "  $(CYAN)make quadlet$(NC)     Setup Podman Quadlet only"
	@echo ""
	@echo "$(BOLD)Docker Compose Commands:$(NC)"
	@echo "  $(CYAN)make compose-start$(NC)   Start compose stack"
	@echo "  $(CYAN)make compose-stop$(NC)    Stop compose stack"
	@echo "  $(CYAN)make compose-logs$(NC)    View compose logs"
	@echo "  $(CYAN)make compose-status$(NC)  Show compose status"
	@echo "  $(CYAN)make compose-update$(NC)  Update compose images"
	@echo ""
	@echo "$(BOLD)Quadlet Commands:$(NC)"
	@echo "  $(CYAN)make quadlet-start$(NC)   Start quadlet services"
	@echo "  $(CYAN)make quadlet-stop$(NC)    Stop quadlet services"
	@echo "  $(CYAN)make quadlet-logs$(NC)    View quadlet logs"
	@echo "  $(CYAN)make quadlet-status$(NC)  Show quadlet status"
	@echo "  $(CYAN)make quadlet-reload$(NC)  Reload quadlet daemon"
	@echo "  $(CYAN)make quadlet-enable$(NC)  Enable services at boot"
	@echo ""
	@echo "$(BOLD)Utility Commands:$(NC)"
	@echo "  $(CYAN)make dirs$(NC)            Create data directories"
	@echo "  $(CYAN)make permissions$(NC)     Fix directory permissions"
	@echo "  $(CYAN)make validate$(NC)        Validate configuration"
	@echo "  $(CYAN)make vpn-check$(NC)       Verify VPN is working"
	@echo "  $(CYAN)make clean$(NC)           Remove all data (DANGEROUS!)"
	@echo ""
	@echo "$(BOLD)Detected Runtime:$(NC) $(RUNTIME)"
	@echo ""

## setup: Interactive setup wizard
setup:
	@./scripts/setup.sh

## compose: Setup Docker Compose (non-interactive, requires .env)
compose: check-env
	@echo "$(BOLD)$(CYAN)Setting up Docker Compose...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)Error: .env file not found. Run 'make setup' first.$(NC)"; \
		exit 1; \
	fi
	@$(MAKE) dirs
	@echo "$(GREEN)✓ Docker Compose ready!$(NC)"
	@echo "  Run: $(COMPOSE) up -d"

## quadlet: Setup Podman Quadlet (non-interactive, requires .env)
quadlet: check-env
	@echo "$(BOLD)$(CYAN)Setting up Podman Quadlet...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)Error: .env file not found. Run 'make setup' first.$(NC)"; \
		exit 1; \
	fi
	@$(MAKE) quadlet-install
	@$(MAKE) dirs
	@$(MAKE) quadlet-reload
	@echo "$(GREEN)✓ Quadlet ready!$(NC)"
	@echo "  Run: make quadlet-start"

# =============================================================================
# Docker Compose Targets
# =============================================================================

## compose-start: Start Docker Compose stack
compose-start:
	@echo "$(CYAN)Starting compose stack...$(NC)"
	$(COMPOSE) up -d

## compose-stop: Stop Docker Compose stack
compose-stop:
	@echo "$(CYAN)Stopping compose stack...$(NC)"
	$(COMPOSE) down

## compose-logs: View Docker Compose logs
compose-logs:
	$(COMPOSE) logs -f

## compose-status: Show Docker Compose status
compose-status:
	$(COMPOSE) ps

## compose-update: Update Docker Compose images
compose-update:
	@echo "$(CYAN)Pulling latest images...$(NC)"
	$(COMPOSE) pull
	@echo "$(CYAN)Recreating containers...$(NC)"
	$(COMPOSE) up -d
	@echo "$(CYAN)Cleaning old images...$(NC)"
	$(RUNTIME) image prune -f

# =============================================================================
# Quadlet Targets
# =============================================================================

SYSTEMD_DIR := $(HOME)/.config/containers/systemd
TEMPLATES_DIR := quadlet
QUADLET_SERVICES := vpn-services media-automation media-streaming flaresolverr tor-proxy

## quadlet-install: Install quadlet templates (internal)
quadlet-install:
	@echo "$(CYAN)Installing Quadlet templates...$(NC)"
	@mkdir -p $(SYSTEMD_DIR)
	@# Source environment variables and process templates
	@if [ -f .env ]; then \
		set -a && . ./.env && set +a; \
		PUID=$${PUID:-1000}; \
		PGID=$${PGID:-1000}; \
		TZ=$${TZ:-Europe/London}; \
		DATA_PATH=$${DATA_PATH:-$(HOME)/media}; \
		WIREGUARD_PRIVATE_KEY=$${WIREGUARD_PRIVATE_KEY:-}; \
		SERVER_COUNTRIES=$${SERVER_COUNTRIES:-Netherlands}; \
		PROWLARR_DEFINITIONS_PATH="$(SYSTEMD_DIR)/prowlarr-definitions"; \
		for template in $(TEMPLATES_DIR)/*; do \
			filename=$$(basename "$$template"); \
			echo "  Processing: $$filename"; \
			sed \
				-e "s|{{PUID}}|$$PUID|g" \
				-e "s|{{PGID}}|$$PGID|g" \
				-e "s|{{TZ}}|$$TZ|g" \
				-e "s|{{DATA_PATH}}|$$DATA_PATH|g" \
				-e "s|{{SERVER_COUNTRIES}}|$$SERVER_COUNTRIES|g" \
				-e "s|{{PROWLARR_DEFINITIONS_PATH}}|$$PROWLARR_DEFINITIONS_PATH|g" \
				"$$template" > "$(SYSTEMD_DIR)/$$filename"; \
		done; \
		echo "  Creating: wireguard-secret.yaml"; \
		printf '%s\n' \
			"# WireGuard Secret - AUTO-GENERATED, DO NOT COMMIT" \
			"apiVersion: v1" \
			"kind: Secret" \
			"metadata:" \
			"  name: wireguard-key" \
			"stringData:" \
			"  key: \"$$WIREGUARD_PRIVATE_KEY\"" \
			> "$(SYSTEMD_DIR)/wireguard-secret.yaml"; \
		chmod 600 "$(SYSTEMD_DIR)/wireguard-secret.yaml"; \
		chmod 700 "$(SYSTEMD_DIR)"; \
		cp -r prowlarr-definitions "$(SYSTEMD_DIR)/"; \
	else \
		echo "$(RED)Error: .env file not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Installed to $(SYSTEMD_DIR)$(NC)"
	@echo "$(GREEN)✓ Secret file created with chmod 600$(NC)"

## quadlet-reload: Reload systemd daemon
quadlet-reload:
	@echo "$(CYAN)Reloading systemd...$(NC)"
	systemctl --user daemon-reload
	@echo "$(GREEN)✓ Daemon reloaded$(NC)"
	@echo ""
	@echo "$(CYAN)Generated units:$(NC)"
	@systemctl --user list-unit-files | grep -E "(vpn-services|media-automation|media-streaming|flaresolverr|tor-proxy)" || \
		echo "$(YELLOW)No units found - check for errors with: /usr/libexec/podman/quadlet --dryrun --user$(NC)"

## quadlet-start: Start all Quadlet services
quadlet-start:
	@echo "$(CYAN)Starting Quadlet services...$(NC)"
	@for svc in $(QUADLET_SERVICES); do \
		echo "  Starting $$svc..."; \
		systemctl --user start $$svc || true; \
	done
	@echo "$(GREEN)✓ Services started$(NC)"

## quadlet-stop: Stop all Quadlet services
quadlet-stop:
	@echo "$(CYAN)Stopping Quadlet services...$(NC)"
	@for svc in $(QUADLET_SERVICES); do \
		echo "  Stopping $$svc..."; \
		systemctl --user stop $$svc || true; \
	done
	@echo "$(GREEN)✓ Services stopped$(NC)"

## quadlet-status: Show Quadlet service status
quadlet-status:
	@echo "$(BOLD)$(CYAN)Quadlet Service Status$(NC)"
	@echo ""
	@for svc in $(QUADLET_SERVICES); do \
		status=$$(systemctl --user is-active $$svc 2>/dev/null || echo "inactive"); \
		if [ "$$status" = "active" ]; then \
			echo "  $(GREEN)●$(NC) $$svc: $$status"; \
		else \
			echo "  $(RED)○$(NC) $$svc: $$status"; \
		fi; \
	done

## quadlet-logs: View Quadlet logs
quadlet-logs:
	journalctl --user -u vpn-services -u media-automation -u media-streaming -u flaresolverr -u tor-proxy -f

## quadlet-enable: Enable Quadlet services at boot
quadlet-enable:
	@echo "$(CYAN)Enabling lingering for boot-time startup...$(NC)"
	@sudo loginctl enable-linger $(USER) || echo "$(YELLOW)Failed - you may need to run: sudo loginctl enable-linger $(USER)$(NC)"
	@echo ""
	@echo "$(CYAN)Enabling services...$(NC)"
	@for svc in $(QUADLET_SERVICES); do \
		systemctl --user enable $$svc || true; \
	done
	@echo "$(GREEN)✓ Services enabled for boot$(NC)"

## quadlet-disable: Disable Quadlet services at boot
quadlet-disable:
	@echo "$(CYAN)Disabling services...$(NC)"
	@for svc in $(QUADLET_SERVICES); do \
		systemctl --user disable $$svc || true; \
	done
	@echo "$(GREEN)✓ Services disabled$(NC)"

# =============================================================================
# Utility Targets
# =============================================================================

## check-env: Check if .env file exists
check-env:
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Warning: .env file not found$(NC)"; \
		echo "Run 'make setup' for interactive configuration or copy .env.example to .env"; \
	fi

## validate: Validate configuration
validate:
	@echo "$(BOLD)$(CYAN)Validating Configuration$(NC)"
	@echo ""
	@# Check .env
	@if [ -f .env ]; then \
		echo "$(GREEN)✓$(NC) .env file exists"; \
		if grep -q "WIREGUARD_PRIVATE_KEY=\"\"" .env; then \
			echo "$(RED)✗$(NC) WIREGUARD_PRIVATE_KEY is empty"; \
		else \
			echo "$(GREEN)✓$(NC) WIREGUARD_PRIVATE_KEY is set"; \
		fi; \
		DATA_PATH=$$(grep DATA_PATH .env | cut -d= -f2); \
		if [ -d "$$DATA_PATH" ]; then \
			echo "$(GREEN)✓$(NC) DATA_PATH exists: $$DATA_PATH"; \
		else \
			echo "$(YELLOW)⚠$(NC) DATA_PATH doesn't exist: $$DATA_PATH"; \
		fi; \
	else \
		echo "$(RED)✗$(NC) .env file missing"; \
	fi
	@echo ""
	@# Check runtime
	@if [ "$(RUNTIME)" = "none" ]; then \
		echo "$(RED)✗$(NC) No container runtime found (docker or podman)"; \
	else \
		echo "$(GREEN)✓$(NC) Container runtime: $(RUNTIME)"; \
	fi
	@echo ""
	@# Check Quadlet (if using Podman)
	@if [ -n "$(PODMAN)" ]; then \
		if [ -f "$(SYSTEMD_DIR)/vpn-services.yaml" ]; then \
			echo "$(GREEN)✓$(NC) Quadlet files installed"; \
		else \
			echo "$(YELLOW)⚠$(NC) Quadlet files not installed (run 'make quadlet')"; \
		fi; \
	fi

## dirs: Create data directories
dirs:
	@echo "$(CYAN)Creating data directories...$(NC)"
	@if [ -f .env ]; then \
		DATA_PATH=$$(grep DATA_PATH .env | cut -d= -f2 | tr -d '"'); \
		mkdir -p "$$DATA_PATH/torrents/movies" "$$DATA_PATH/torrents/tv"; \
		mkdir -p "$$DATA_PATH/usenet/movies" "$$DATA_PATH/usenet/tv" "$$DATA_PATH/usenet/complete" "$$DATA_PATH/usenet/incomplete"; \
		mkdir -p "$$DATA_PATH/media/movies" "$$DATA_PATH/media/tv"; \
		echo "$(GREEN)✓$(NC) Created directories in $$DATA_PATH"; \
	else \
		echo "$(RED)Error: .env file not found$(NC)"; \
		exit 1; \
	fi

## permissions: Fix directory permissions
permissions:
	@echo "$(CYAN)Fixing permissions...$(NC)"
	@if [ -f .env ]; then \
		DATA_PATH=$$(grep DATA_PATH .env | cut -d= -f2 | tr -d '"'); \
		PUID=$$(grep PUID .env | cut -d= -f2); \
		PGID=$$(grep PGID .env | cut -d= -f2); \
		if command -v podman >/dev/null 2>&1; then \
			echo "Using podman unshare for rootless permissions..."; \
			podman unshare chown -R "$$PUID:$$PGID" "$$DATA_PATH"; \
			if command -v chcon >/dev/null 2>&1; then \
				echo "Setting SELinux context..."; \
				podman unshare chcon -R -t container_file_t "$$DATA_PATH" 2>/dev/null || true; \
			fi; \
		else \
			chown -R "$$PUID:$$PGID" "$$DATA_PATH"; \
		fi; \
		echo "$(GREEN)✓$(NC) Permissions fixed"; \
	else \
		echo "$(RED)Error: .env file not found$(NC)"; \
		exit 1; \
	fi

## vpn-check: Verify VPN is working
vpn-check:
	@echo "$(CYAN)Checking VPN status...$(NC)"
	@echo ""
	@echo "Your IP: $$(curl -s ifconfig.me)"
	@echo ""
	@if $(RUNTIME) ps | grep -q gluetun; then \
		echo "VPN Container IP: $$($(RUNTIME) exec gluetun wget -qO- ifconfig.me 2>/dev/null || $(RUNTIME) exec vpn-services-gluetun wget -qO- ifconfig.me 2>/dev/null || echo 'Failed to get VPN IP')"; \
	else \
		echo "$(YELLOW)Gluetun container not running$(NC)"; \
	fi

## clean: Remove all data (DANGEROUS!)
clean:
	@echo "$(RED)$(BOLD)⚠️  WARNING: This will remove all container data!$(NC)"
	@echo ""
	@read -p "Type 'DELETE' to confirm: " confirm; \
	if [ "$$confirm" = "DELETE" ]; then \
		echo "$(CYAN)Stopping services...$(NC)"; \
		$(MAKE) compose-stop 2>/dev/null || true; \
		$(MAKE) quadlet-stop 2>/dev/null || true; \
		echo "$(CYAN)Removing volumes...$(NC)"; \
		$(RUNTIME) volume prune -f; \
		echo "$(GREEN)✓ Cleanup complete$(NC)"; \
	else \
		echo "Cancelled."; \
	fi

# Default target
.DEFAULT_GOAL := help
