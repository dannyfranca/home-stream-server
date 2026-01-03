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
        dirs permissions check-env validate plex-claim

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
	@printf "\n"
	@printf "$(BOLD)$(CYAN)🎬 Home Stream Server - Make Commands$(NC)\n"
	@printf "\n"
	@printf "$(BOLD)Setup Commands:$(NC)\n"
	@printf "  $(CYAN)make setup$(NC)       Interactive setup wizard (recommended)\n"
	@printf "  $(CYAN)make compose$(NC)     Setup Docker Compose only\n"
	@printf "  $(CYAN)make quadlet$(NC)     Setup Podman Quadlet only\n"
	@printf "\n"
	@printf "$(BOLD)Docker Compose Commands:$(NC)\n"
	@printf "  $(CYAN)make compose-start$(NC)   Start compose stack\n"
	@printf "  $(CYAN)make compose-stop$(NC)    Stop compose stack\n"
	@printf "  $(CYAN)make compose-logs$(NC)    View compose logs\n"
	@printf "  $(CYAN)make compose-status$(NC)  Show compose status\n"
	@printf "  $(CYAN)make compose-update$(NC)  Update compose images\n"
	@printf "\n"
	@printf "$(BOLD)Quadlet Commands:$(NC)\n"
	@printf "  $(CYAN)make quadlet-start$(NC)   Start quadlet services\n"
	@printf "  $(CYAN)make quadlet-stop$(NC)    Stop quadlet services\n"
	@printf "  $(CYAN)make quadlet-logs$(NC)    View quadlet logs\n"
	@printf "  $(CYAN)make quadlet-status$(NC)  Show quadlet status\n"
	@printf "  $(CYAN)make quadlet-reload$(NC)  Reload quadlet daemon\n"
	@printf "  $(CYAN)make quadlet-enable$(NC)  Enable services at boot\n"
	@printf "\n"
	@printf "$(BOLD)Utility Commands:$(NC)\n"
	@printf "  $(CYAN)make dirs$(NC)            Create data directories\n"
	@printf "  $(CYAN)make permissions$(NC)     Fix directory permissions\n"
	@printf "  $(CYAN)make validate$(NC)        Validate configuration\n"
	@printf "  $(CYAN)make vpn-check$(NC)       Verify VPN is working\n"
	@printf "  $(CYAN)make password$(NC)        Get qBittorrent initial password\n"
	@printf "  $(CYAN)make plex-claim$(NC)      Get Plex claim token instructions\n"
	@printf "  $(CYAN)make clean$(NC)           Remove all data (DANGEROUS!)\n"
	@printf "\n"
	@printf "$(BOLD)Detected Runtime:$(NC) $(RUNTIME)\n"
	@printf "\n"

## setup: Interactive setup wizard
setup:
	@./scripts/setup.sh

## compose: Setup Docker Compose (non-interactive, requires .env)
compose: check-env
	@printf "$(BOLD)$(CYAN)Setting up Docker Compose...$(NC)\n"
	@if [ ! -f .env ]; then \
		printf "$(RED)Error: .env file not found. Run 'make setup' first.$(NC)\n"; \
		exit 1; \
	fi
	@$(MAKE) dirs
	@printf "$(GREEN)✓ Docker Compose ready!$(NC)\n"
	@printf "  Run: $(COMPOSE) up -d\n"

## quadlet: Setup Podman Quadlet (non-interactive, requires .env)
quadlet: check-env
	@printf "$(BOLD)$(CYAN)Setting up Podman Quadlet...$(NC)\n"
	@if [ ! -f .env ]; then \
		printf "$(RED)Error: .env file not found. Run 'make setup' first.$(NC)\n"; \
		exit 1; \
	fi
	@$(MAKE) quadlet-install
	@$(MAKE) dirs
	@$(MAKE) quadlet-reload
	@printf "$(GREEN)✓ Quadlet ready!$(NC)\n"
	@printf "  Run: make quadlet-start\n"

# =============================================================================
# Docker Compose Targets
# =============================================================================

## compose-start: Start Docker Compose stack
compose-start:
	@printf "$(CYAN)Starting compose stack...$(NC)\n"
	$(COMPOSE) up -d

## compose-stop: Stop Docker Compose stack
compose-stop:
	@printf "$(CYAN)Stopping compose stack...$(NC)\n"
	$(COMPOSE) down

## compose-logs: View Docker Compose logs
compose-logs:
	$(COMPOSE) logs -f

## compose-status: Show Docker Compose status
compose-status:
	$(COMPOSE) ps

## compose-update: Update Docker Compose images
compose-update:
	@printf "$(CYAN)Pulling latest images...$(NC)\n"
	$(COMPOSE) pull
	@printf "$(CYAN)Recreating containers...$(NC)\n"
	$(COMPOSE) up -d
	@printf "$(CYAN)Cleaning old images...$(NC)\n"
	$(RUNTIME) image prune -f

# =============================================================================
# Quadlet Targets
# =============================================================================

SYSTEMD_DIR := $(HOME)/.config/containers/systemd
TEMPLATES_DIR := quadlet
QUADLET_SERVICES := home-stream-network vpn-services media-automation media-streaming flaresolverr tor-proxy

## quadlet-install: Install quadlet templates (internal)
quadlet-install:
	@printf "$(CYAN)Installing Quadlet templates...$(NC)\n"
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
			printf "  Processing: %s\n" "$$filename"; \
			sed \
				-e "s|{{PUID}}|$$PUID|g" \
				-e "s|{{PGID}}|$$PGID|g" \
				-e "s|{{TZ}}|$$TZ|g" \
				-e "s|{{DATA_PATH}}|$$DATA_PATH|g" \
				-e "s|{{SERVER_COUNTRIES}}|$$SERVER_COUNTRIES|g" \
				-e "s|{{PROWLARR_DEFINITIONS_PATH}}|$$PROWLARR_DEFINITIONS_PATH|g" \
				"$$template" > "$(SYSTEMD_DIR)/$$filename"; \
		done; \
		printf "  Creating: wireguard-secret.yaml\n"; \
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
		if [ -n "$$PLEX_CLAIM" ]; then \
			printf "  Creating: plex-claim.env\n"; \
			printf '%s\n' \
				"# Plex Claim Token - AUTO-GENERATED" \
				"# Only needed for first run, can be removed after claiming" \
				"PLEX_CLAIM=$$PLEX_CLAIM" \
				> "$(SYSTEMD_DIR)/plex-claim.env"; \
			chmod 600 "$(SYSTEMD_DIR)/plex-claim.env"; \
		fi; \
	else \
		printf "$(RED)Error: .env file not found$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ Installed to $(SYSTEMD_DIR)$(NC)\n"
	@printf "$(GREEN)✓ Secret file created with chmod 600$(NC)\n"

## quadlet-reload: Reload systemd daemon
quadlet-reload:
	@printf "$(CYAN)Reloading systemd...$(NC)\n"
	systemctl --user daemon-reload
	@printf "$(GREEN)✓ Daemon reloaded$(NC)\n"
	@printf "\n"
	@printf "$(CYAN)Generated units:$(NC)\n"
	@systemctl --user list-unit-files | grep -E "(vpn-services|media-automation|media-streaming|flaresolverr|tor-proxy)" || \
		printf "$(YELLOW)No units found - check for errors with: /usr/libexec/podman/quadlet --dryrun --user$(NC)\n"

## quadlet-start: Start all Quadlet services
quadlet-start:
	@printf "$(CYAN)Starting Quadlet services...$(NC)\n"
	@for svc in $(QUADLET_SERVICES); do \
		printf "  Starting $$svc...\n"; \
		systemctl --user start $$svc || true; \
	done
	@printf "$(GREEN)✓ Services started$(NC)\n"

## quadlet-stop: Stop all Quadlet services
quadlet-stop:
	@printf "$(CYAN)Stopping Quadlet services...$(NC)\n"
	@for svc in $(QUADLET_SERVICES); do \
		printf "  Stopping $$svc...\n"; \
		systemctl --user stop $$svc || true; \
	done
	@printf "$(GREEN)✓ Services stopped$(NC)\n"

## quadlet-status: Show Quadlet service status
quadlet-status:
	@printf "$(BOLD)$(CYAN)Quadlet Service Status$(NC)\n"
	@printf "\n"
	@for svc in $(QUADLET_SERVICES); do \
		status=$$(systemctl --user is-active $$svc 2>/dev/null || echo "inactive"); \
		if [ "$$status" = "active" ]; then \
			printf "  $(GREEN)●$(NC) $$svc: $$status\n"; \
		else \
			printf "  $(RED)○$(NC) $$svc: $$status\n"; \
		fi; \
	done

## quadlet-logs: View Quadlet logs
quadlet-logs:
	journalctl --user -u vpn-services -u media-automation -u media-streaming -u flaresolverr -u tor-proxy -f

## quadlet-enable: Enable Quadlet services at boot
quadlet-enable:
	@printf "$(CYAN)Enabling lingering for boot-time startup...$(NC)\n"
	@sudo loginctl enable-linger $(USER) || printf "$(YELLOW)Failed - you may need to run: sudo loginctl enable-linger $(USER)$(NC)\n"
	@printf "\n"
	@printf "$(CYAN)Services are auto-enabled by Quadlet definitions.$(NC)\n"
	@printf "$(GREEN)✓ Boot startup configured$(NC)\n"

## quadlet-disable: Disable Quadlet services at boot
quadlet-disable:
	@printf "$(CYAN)To disable Quadlet services, you must remove the files from:$(NC)\n"
	@printf "  $(SYSTEMD_DIR)/\n"
	@printf "\n"
	@printf "Run 'make clean' to remove all data and configurations appropriately.\n"

# =============================================================================
# Utility Targets
# =============================================================================

## check-env: Check if .env file exists
check-env:
	@if [ ! -f .env ]; then \
		printf "$(YELLOW)Warning: .env file not found$(NC)\n"; \
		printf "Run 'make setup' for interactive configuration or copy .env.example to .env\n"; \
	fi

## validate: Validate configuration
validate:
	@printf "$(BOLD)$(CYAN)Validating Configuration$(NC)\n"
	@printf "\n"
	@# Check .env
	@if [ -f .env ]; then \
		printf "$(GREEN)✓$(NC) .env file exists\n"; \
		if grep -q "WIREGUARD_PRIVATE_KEY=\"\"" .env; then \
			printf "$(RED)✗$(NC) WIREGUARD_PRIVATE_KEY is empty\n"; \
		else \
			printf "$(GREEN)✓$(NC) WIREGUARD_PRIVATE_KEY is set\n"; \
		fi; \
		DATA_PATH=$$(grep DATA_PATH .env | cut -d= -f2); \
		if [ -d "$$DATA_PATH" ]; then \
			printf "$(GREEN)✓$(NC) DATA_PATH exists: $$DATA_PATH\n"; \
		else \
			printf "$(YELLOW)⚠$(NC) DATA_PATH doesn't exist: $$DATA_PATH\n"; \
		fi; \
	else \
		printf "$(RED)✗$(NC) .env file missing\n"; \
	fi
	@printf "\n"
	@# Check runtime
	@if [ "$(RUNTIME)" = "none" ]; then \
		printf "$(RED)✗$(NC) No container runtime found (docker or podman)\n"; \
	else \
		printf "$(GREEN)✓$(NC) Container runtime: $(RUNTIME)\n"; \
	fi
	@printf "\n"
	@# Check Quadlet (if using Podman)
	@if [ -n "$(PODMAN)" ]; then \
		if [ -f "$(SYSTEMD_DIR)/vpn-services.yaml" ]; then \
			printf "$(GREEN)✓$(NC) Quadlet files installed\n"; \
		else \
			printf "$(YELLOW)⚠$(NC) Quadlet files not installed (run 'make quadlet')\n"; \
		fi; \
	fi

## dirs: Create data directories
dirs:
	@printf "$(CYAN)Creating data directories...$(NC)\n"
	@if [ -f .env ]; then \
		DATA_PATH=$$(grep DATA_PATH .env | cut -d= -f2 | tr -d '"'); \
		mkdir -p "$$DATA_PATH/torrents/movies" "$$DATA_PATH/torrents/tv"; \
		mkdir -p "$$DATA_PATH/usenet/movies" "$$DATA_PATH/usenet/tv" "$$DATA_PATH/usenet/complete" "$$DATA_PATH/usenet/incomplete"; \
		mkdir -p "$$DATA_PATH/media/movies" "$$DATA_PATH/media/tv"; \
		printf "$(GREEN)✓$(NC) Created directories in $$DATA_PATH\n"; \
	else \
		printf "$(RED)Error: .env file not found$(NC)\n"; \
		exit 1; \
	fi

## permissions: Fix directory permissions
permissions:
	@printf "$(CYAN)Fixing permissions...$(NC)\n"
	@if [ -f .env ]; then \
		DATA_PATH=$$(grep DATA_PATH .env | cut -d= -f2 | tr -d '"'); \
		PUID=$$(grep PUID .env | cut -d= -f2); \
		PGID=$$(grep PGID .env | cut -d= -f2); \
		if command -v podman >/dev/null 2>&1; then \
			printf "Using podman unshare for rootless permissions...\n"; \
			podman unshare chown -R "$$PUID:$$PGID" "$$DATA_PATH"; \
			if command -v chcon >/dev/null 2>&1; then \
				printf "Setting SELinux context...\n"; \
				podman unshare chcon -R -t container_file_t "$$DATA_PATH" 2>/dev/null || true; \
			fi; \
		else \
			chown -R "$$PUID:$$PGID" "$$DATA_PATH"; \
		fi; \
		printf "$(GREEN)✓$(NC) Permissions fixed\n"; \
	else \
		printf "$(RED)Error: .env file not found$(NC)\n"; \
		exit 1; \
	fi

## vpn-check: Verify VPN is working
vpn-check:
	@printf "$(CYAN)Checking VPN status...$(NC)\n"
	@printf "\n"
	@printf "Host IP (ISP - Unprotected): %s\n" "$$(curl -s ifconfig.me)"
	@printf "\n"
	@if $(RUNTIME) ps | grep -q gluetun; then \
		printf "Container IP (VPN - Protected): %s\n" "$$($(RUNTIME) exec gluetun wget -qO- ifconfig.me/ip 2>/dev/null || $(RUNTIME) exec vpn-services-gluetun wget -qO- ifconfig.me/ip 2>/dev/null || echo 'Failed to verify - Check container logs')"; \
	else \
		printf "$(YELLOW)Gluetun container not running$(NC)\n"; \
	fi

## password: Get qBittorrent initial password
password:
	@printf "$(CYAN)Searching for qBittorrent initial password...$(NC)\n"
	@if [ "$(RUNTIME)" = "podman" ] && systemctl --user is-active vpn-services >/dev/null 2>&1; then \
		journalctl --user -u vpn-services --no-pager | grep -C 3 "The WebUI administrator password is" || printf "$(YELLOW)Password not found in logs. It may have already rotated or service isn't fully up.$(NC)\n"; \
	elif [ "$(RUNTIME)" = "docker" ] || [ "$(RUNTIME)" = "podman" ]; then \
		$(COMPOSE) logs qbittorrent 2>/dev/null | grep -C 3 "The WebUI administrator password is" || printf "$(YELLOW)Password not found in logs. Check if service is running.$(NC)\n"; \
	else \
		printf "$(RED)No active runtime found.$(NC)\n"; \
	fi

## plex-claim: Get Plex claim token instructions
plex-claim:
	@printf "\n"
	@printf "$(BOLD)$(CYAN)🎬 Plex Claim Token$(NC)\n"
	@printf "\n"
	@printf "To claim your Plex server, you need a token from Plex.tv:\n"
	@printf "\n"
	@printf "  1. Open: $(BOLD)https://plex.tv/claim$(NC)\n"
	@printf "  2. Sign in to your Plex account\n"
	@printf "  3. Copy the claim token (starts with 'claim-')\n"
	@printf "  4. Add to your .env file: PLEX_CLAIM=claim-xxxx\n"
	@printf "\n"
	@printf "$(YELLOW)⚠ Token is valid for 4 minutes only!$(NC)\n"
	@printf "\n"
	@printf "After adding the token, uncomment the plex service in docker-compose.yml\n"
	@printf "and restart: make compose-start\n"
	@printf "\n"

## clean: Remove all data (DANGEROUS!)
clean:
	@printf "$(RED)$(BOLD)⚠️  WARNING: This will remove all container data!$(NC)\n"
	@printf "\n"
	@read -p "Type 'DELETE' to confirm: " confirm; \
	if [ "$$confirm" = "DELETE" ]; then \
		printf "$(CYAN)Stopping services...$(NC)\n"; \
		$(MAKE) compose-stop 2>/dev/null || true; \
		$(MAKE) quadlet-stop 2>/dev/null || true; \
		printf "$(CYAN)Removing volumes...$(NC)\n"; \
		$(RUNTIME) volume prune -f; \
		printf "$(GREEN)✓ Cleanup complete$(NC)\n"; \
	else \
		printf "Cancelled.\n"; \
	fi

# Default target
.DEFAULT_GOAL := help
