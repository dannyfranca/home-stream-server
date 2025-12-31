#!/usr/bin/env bash
# =============================================================================
# Home Stream Server - Interactive Setup Script
# =============================================================================
# This script provides an interactive experience for configuring both
# Docker Compose and Podman Quadlet deployments.
#
# Usage: make setup OR ./scripts/setup.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
DEFAULT_PUID=$(id -u)
DEFAULT_PGID=$(id -g)
DEFAULT_TZ="Europe/London"
DEFAULT_DATA_PATH="${HOME}/media"
DEFAULT_SERVER_COUNTRIES="Netherlands"

# Configuration variables
PUID=""
PGID=""
TZ=""
DATA_PATH=""
WIREGUARD_PRIVATE_KEY=""
SERVER_COUNTRIES=""

# =============================================================================
# Utility Functions
# =============================================================================

print_header() {
    printf "\n"
    printf "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BOLD}${CYAN}  🎬 Home Stream Server - Interactive Setup${NC}\n"
    printf "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "\n"
}

print_section() {
    printf "\n"
    printf "${BOLD}${YELLOW}▶ %s${NC}\n" "$1"
    printf "\n"
}

print_success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}✗${NC} %s\n" "$1"
}

print_info() {
    printf "${CYAN}ℹ${NC} %s\n" "$1"
}

prompt() {
    local message="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        # Print prompt to stderr so it's visible when captured via $(...)
        printf "%b" "${BOLD}$message${NC} [${CYAN}$default${NC}]: " >&2
        read -r result
        result="${result:-$default}"
    else
        printf "%b" "${BOLD}$message${NC}: " >&2
        read -r result
    fi
    # Only the result goes to stdout for capture
    printf "%s\n" "$result"
}

prompt_secret() {
    local message="$1"
    local result

    # Print prompt to stderr so it's visible when captured via $(...)
    printf "%b" "${BOLD}$message${NC}: " >&2
    read -rs result
    printf "\n" >&2
    # Only the result goes to stdout for capture
    printf "%s\n" "$result"
}

confirm() {
    local message="$1"
    local default="${2:-n}"
    local result

    if [[ "$default" == "y" ]]; then
        printf "%b" "${BOLD}$message${NC} [${CYAN}Y/n${NC}]: "
    else
        printf "%b" "${BOLD}$message${NC} [${CYAN}y/N${NC}]: "
    fi
    read -r result
    result="${result:-$default}"

    [[ "$result" =~ ^[Yy]$ ]]
}

check_command() {
    command -v "$1" &>/dev/null
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_path() {
    local path="$1"
    
    # Expand ~ to HOME
    path="${path/#\~/$HOME}"
    
    # Check if parent directory is writable
    local parent_dir
    parent_dir=$(dirname "$path")
    
    if [[ ! -d "$parent_dir" ]]; then
        print_warning "Parent directory doesn't exist: $parent_dir"
        if confirm "Create it?"; then
            mkdir -p "$parent_dir" || {
                print_error "Failed to create directory"
                return 1
            }
        else
            return 1
        fi
    fi
    
    printf "%s\n" "$path"
}

validate_wireguard_key() {
    local key="$1"
    
    # WireGuard private keys are base64-encoded 32-byte values (44 chars with =)
    if [[ ${#key} -ne 44 ]]; then
        print_warning "WireGuard key should be 44 characters, got ${#key}"
        return 1
    fi
    
    # Check if it's valid base64
    if ! echo "$key" | base64 -d &>/dev/null; then
        print_warning "WireGuard key doesn't appear to be valid base64"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Configuration Collection
# =============================================================================

collect_common_config() {
    print_section "Common Configuration"
    
    print_info "These settings are shared by all services."
    print_info "Press Enter to accept the default value shown in brackets."
    printf "\n"
    
    PUID=$(prompt "User ID (PUID)" "$DEFAULT_PUID")
    PGID=$(prompt "Group ID (PGID)" "$DEFAULT_PGID")
    TZ=$(prompt "Timezone" "$DEFAULT_TZ")
    
    print_info "Find your timezone: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
    printf "\n"
    
    # Data path with validation
    while true; do
        DATA_PATH=$(prompt "Data/media storage path" "$DEFAULT_DATA_PATH")
        DATA_PATH=$(validate_path "$DATA_PATH") && break
        print_error "Invalid path, please try again"
    done
    
    printf "\n"
    print_section "NordVPN WireGuard Configuration"
    
    printf "${CYAN}To get your WireGuard private key:${NC}\n"
    printf "  1. Install NordVPN CLI: sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)\n"
    printf "  2. sudo nordvpn login\n"
    printf "  3. sudo nordvpn set technology nordlynx\n"
    printf "  4. sudo nordvpn c\n"
    printf "  5. sudo wg showconf nordlynx  # Copy the PrivateKey value\n"
    printf "  6. sudo nordvpn d\n"
    printf "\n"
    
    while true; do
        WIREGUARD_PRIVATE_KEY=$(prompt_secret "WireGuard Private Key")
        if [[ -z "$WIREGUARD_PRIVATE_KEY" ]]; then
            print_error "WireGuard key is required"
            continue
        fi
        if validate_wireguard_key "$WIREGUARD_PRIVATE_KEY"; then
            break
        fi
        if confirm "Key validation failed. Use it anyway?"; then
            break
        fi
    done
    
    SERVER_COUNTRIES=$(prompt "VPN Server Countries" "$DEFAULT_SERVER_COUNTRIES")
}

# =============================================================================
# Docker Compose Setup
# =============================================================================

setup_docker_compose() {
    print_section "Docker Compose Setup"
    
    # Create .env file
    local env_file="$PROJECT_ROOT/.env"
    
    cat > "$env_file" << EOF
# =============================================================================
# Home Stream Server - Environment Configuration
# Generated by setup script on $(date)
# =============================================================================

# User and Group IDs
PUID=$PUID
PGID=$PGID

# Timezone
TZ=$TZ

# Data Path
DATA_PATH=$DATA_PATH

# NordVPN WireGuard
WIREGUARD_PRIVATE_KEY=$WIREGUARD_PRIVATE_KEY
SERVER_COUNTRIES=$SERVER_COUNTRIES

# Service Ports (change if you have conflicts)
QBITTORRENT_PORT=8090
SABNZBD_PORT=8080
PROWLARR_PORT=9696
SONARR_PORT=8989
RADARR_PORT=7878
BAZARR_PORT=6767
JELLYFIN_PORT=8096
JELLYSEERR_PORT=5055

# Local Network Subnets (for VPN firewall exceptions)
# LOCAL_NETWORK_SUBNETS=10.88.0.0/16,172.16.0.0/12,192.168.0.0/16
EOF
    
    print_success "Created $env_file"
    
    # Create data directories
    print_section "Creating Data Directories"
    create_data_directories
    
    print_success "Docker Compose setup complete!"
    printf "\n"
    print_info "To start the stack:"
    printf "    cd %s\n" "$PROJECT_ROOT"
    printf "    docker compose up -d   # or: podman compose up -d\n"
}

# =============================================================================
# Quadlet Setup
# =============================================================================

setup_quadlet() {
    print_section "Podman Quadlet Setup"
    
    local systemd_dir="$HOME/.config/containers/systemd"
    
    print_info "Quadlet files will be installed to: $systemd_dir"
    printf "\n"
    
    # Create systemd directory
    mkdir -p "$systemd_dir"
    
    # Process and copy template files
    local templates_dir="$PROJECT_ROOT/quadlet"
    local prowlarr_defs_dir="$PROJECT_ROOT/prowlarr-definitions"
    
    # Check for templates
    if [[ ! -d "$templates_dir" ]]; then
        print_error "Quadlet directory not found: $templates_dir"
        print_info "Please run this from the project root directory"
        exit 1
    fi
    
    # Template variables
    local prowlarr_defs_path="$systemd_dir/prowlarr-definitions"
    
    print_info "Processing templates..."
    
    # Process each template file (EXCEPT we skip wireguard key replacement in main files)
    for template in "$templates_dir"/*; do
        local filename
        filename=$(basename "$template")
        local output_file="$systemd_dir/$filename"
        
        # Replace template variables (no WIREGUARD_PRIVATE_KEY - that goes in separate file)
        sed \
            -e "s|{{PUID}}|$PUID|g" \
            -e "s|{{PGID}}|$PGID|g" \
            -e "s|{{TZ}}|$TZ|g" \
            -e "s|{{DATA_PATH}}|$DATA_PATH|g" \
            -e "s|{{SERVER_COUNTRIES}}|$SERVER_COUNTRIES|g" \
            -e "s|{{PROWLARR_DEFINITIONS_PATH}}|$prowlarr_defs_path|g" \
            "$template" > "$output_file"
        
        print_success "Installed: $filename"
    done
    
    # Create separate secret file (NEVER committed to git)
    print_info "Creating WireGuard secret file..."
    local secret_file="$systemd_dir/wireguard-secret.yaml"
    cat > "$secret_file" << EOF
# WireGuard Secret - AUTO-GENERATED, DO NOT COMMIT
# This file contains your NordVPN WireGuard private key.
# Created by setup script on $(date)
apiVersion: v1
kind: Secret
metadata:
  name: wireguard-key
stringData:
  key: "$WIREGUARD_PRIVATE_KEY"
EOF
    
    # Secure the secret file with restrictive permissions
    chmod 600 "$secret_file"
    print_success "Created: wireguard-secret.yaml (chmod 600)"
    
    # Secure the systemd directory
    chmod 700 "$systemd_dir" 2>/dev/null || true
    
    # Copy prowlarr definitions
    if [[ -d "$prowlarr_defs_dir" ]]; then
        cp -r "$prowlarr_defs_dir" "$prowlarr_defs_path"
        # Set SELinux context for prowlarr definitions if needed
        if check_command getenforce && [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
            chcon -R -t container_file_t "$prowlarr_defs_path" 2>/dev/null || true
        fi
        print_success "Installed: prowlarr-definitions/"
    fi
    
    # Create data directories
    print_section "Creating Data Directories"
    create_data_directories
    
    # Enable lingering for boot-time startup
    print_section "Enabling System Boot Integration"
    enable_lingering
    
    # Reload systemd
    print_section "Activating Quadlet Services"
    
    systemctl --user daemon-reload
    print_success "Reloaded systemd user daemon"
    
    # Verify units were generated
    printf "\n"
    print_info "Generated systemd units:"
    if systemctl --user list-unit-files | grep -E "(vpn-services|media-automation|media-streaming|flaresolverr|tor-proxy)" | head -10; then
        print_success "Quadlet units generated successfully"
    else
        print_warning "No units found - checking for errors..."
        /usr/libexec/podman/quadlet --dryrun --user 2>&1 | grep -i error || true
    fi
    
    printf "\n"
    print_success "Quadlet setup complete!"
    printf "\n"
    print_info "To start the services:"
    printf "    systemctl --user start vpn-services\n"
    printf "    systemctl --user start media-automation\n"
    printf "    systemctl --user start media-streaming\n"
    printf "    systemctl --user start flaresolverr\n"
    printf "    systemctl --user start tor-proxy\n"
    printf "\n"
    print_info "To enable auto-start on boot:"
    printf "    systemctl --user enable vpn-services media-automation media-streaming flaresolverr tor-proxy\n"
}

# =============================================================================
# Shared Setup Functions
# =============================================================================

create_data_directories() {
    local dirs=(
        "$DATA_PATH/torrents/movies"
        "$DATA_PATH/torrents/tv"
        "$DATA_PATH/usenet/movies"
        "$DATA_PATH/usenet/tv"
        "$DATA_PATH/usenet/complete"
        "$DATA_PATH/usenet/incomplete"
        "$DATA_PATH/media/movies"
        "$DATA_PATH/media/tv"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_success "Created: $dir"
        else
            print_info "Exists: $dir"
        fi
    done
    
    # Set proper permissions for rootless Podman
    printf "\n"
    print_section "Configuring Permissions for Rootless Containers"
    
    print_info "This is critical for rootless Podman to access bind-mounted directories."
    printf "\n"
    
    if check_command podman; then
        # For rootless Podman, we need to handle user namespace mapping
        # The container runs as a different UID inside the user namespace
        
        print_info "Setting ownership within Podman user namespace..."
        
        # Use podman unshare to set ownership as the mapped user
        # This ensures the container's user (typically UID 1000 inside) can access files
        if podman unshare chown -R "$PUID:$PGID" "$DATA_PATH" 2>/dev/null; then
            print_success "Ownership set via podman unshare"
        else
            print_warning "podman unshare failed, trying regular chown..."
            chown -R "$PUID:$PGID" "$DATA_PATH" 2>/dev/null || {
                print_warning "Could not set ownership - you may need to run:"
                printf "    sudo chown -R \\$(id -u):\\$(id -g) %s\n" "$DATA_PATH"
            }
        fi
        
        # SELinux context is CRITICAL on Fedora/RHEL/Bazzite
        # Without this, containers get "Permission denied" even with correct ownership
        if check_command getenforce && [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
            print_info "SELinux is enabled - setting container_file_t context..."
            
            # Use chcon to set the SELinux type to container_file_t
            # This allows containers to read/write these directories
            if podman unshare chcon -R -t container_file_t "$DATA_PATH" 2>/dev/null; then
                print_success "SELinux context set via podman unshare"
            elif chcon -R -t container_file_t "$DATA_PATH" 2>/dev/null; then
                print_success "SELinux context set"
            else
                print_warning "Could not set SELinux context - you may need to run:"
                printf "    sudo chcon -R -t container_file_t %s\n" "$DATA_PATH"
                printf "\n"
                print_info "Alternatively, use the :Z suffix on volume mounts (already configured in templates)"
            fi
        else
            print_info "SELinux not enforcing - skipping context setup"
        fi
        
        # Ensure directories are world-readable at minimum (fallback)
        # This helps with edge cases in user namespace mapping
        print_info "Ensuring base directory permissions..."
        chmod 755 "$DATA_PATH" 2>/dev/null || true
        find "$DATA_PATH" -type d -exec chmod 755 {} \; 2>/dev/null || true
        
    else
        # Docker or no container runtime - just set ownership
        print_info "Setting standard ownership..."
        chown -R "$PUID:$PGID" "$DATA_PATH" 2>/dev/null || {
            print_warning "Could not set ownership - you may need sudo"
        }
    fi
    
    print_success "Directory permissions configured"
    printf "\n"
    print_info "If you still get permission errors, see README.md troubleshooting section"
}

enable_lingering() {
    # Enable lingering so user services can run at boot without login
    local current_user
    current_user=$(whoami)
    
    if loginctl show-user "$current_user" 2>/dev/null | grep -q "Linger=yes"; then
        print_info "Lingering already enabled for user: $current_user"
    else
        print_info "Enabling lingering for user: $current_user"
        print_warning "This allows services to start at boot without logging in"
        
        if confirm "Enable lingering? (requires sudo)" "y"; then
            if sudo loginctl enable-linger "$current_user"; then
                print_success "Lingering enabled"
            else
                print_error "Failed to enable lingering"
                print_info "You can enable it manually with: sudo loginctl enable-linger $current_user"
            fi
        else
            print_warning "Skipped - services will only start when you log in"
        fi
    fi
}

# =============================================================================
# Main Menu
# =============================================================================

show_menu() {
    print_header
    
    printf "${BOLD}Choose your deployment method:${NC}\n"
    printf "\n"
    printf "  ${CYAN}1)${NC} Docker Compose - Works with Docker or Podman\n"
    printf "     Best for most users, simpler setup\n"
    printf "\n"
    printf "  ${CYAN}2)${NC} Podman Quadlet - Native systemd integration\n"
    printf "     Best for Fedora Atomic, Bazzite, immutable distros\n"
    printf "     Enables boot-time startup without login\n"
    printf "\n"
    printf "  ${CYAN}q)${NC} Quit\n"
    printf "\n"
    
    local choice
    printf "%b" "${BOLD}Your choice${NC} [1/2/q]: "
    read -r choice
    
    case "$choice" in
        1)
            collect_common_config
            setup_docker_compose
            ;;
        2)
            collect_common_config
            setup_quadlet
            ;;
        q|Q)
            printf "Goodbye!\n"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter 1, 2, or q."
            show_menu
            ;;
    esac
}

# =============================================================================
# Final Summary
# =============================================================================

show_summary() {
    printf "\n"
    printf "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BOLD}${GREEN}  ✓ Setup Complete!${NC}\n"
    printf "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "\n"
    printf "${BOLD}Next Steps:${NC}\n"
    printf "  1. Start your containers using the commands above\n"
    printf "  2. Access the web UIs to configure each service\n"
    printf "  3. See README.md for detailed configuration instructions\n"
    printf "\n"
    printf "${BOLD}Service URLs:${NC}\n"
    printf "  • qBittorrent:  http://localhost:8090\n"
    printf "  • SABnzbd:      http://localhost:8080\n"
    printf "  • Prowlarr:     http://localhost:9696\n"
    printf "  • Sonarr:       http://localhost:8989\n"
    printf "  • Radarr:       http://localhost:7878\n"
    printf "  • Bazarr:       http://localhost:6767\n"
    printf "  • Jellyfin:     http://localhost:8096\n"
    printf "  • Jellyseerr:   http://localhost:5055\n"
    printf "\n"
    printf "${BOLD}Happy Streaming! 🍿${NC}\n"
    printf "\n"
}

# =============================================================================
# Entry Point
# =============================================================================

main() {
    # CD to project root
    cd "$PROJECT_ROOT"
    
    show_menu
    show_summary
}

main "$@"
