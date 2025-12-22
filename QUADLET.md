# Running Home Stream Server with Quadlets on Bazzite [Work In Progress]

This guide covers deploying the Home Stream Server stack using **Podman Quadlets** on Bazzite (or any Fedora Atomic/immutable distribution).

## Why Quadlets?

Quadlets are the modern way to run containers as systemd services with Podman:

- **Native systemd integration** - Containers start on boot, restart on failure
- **Rootless by default** - Better security, no daemon required
- **Atomic-friendly** - Works perfectly on immutable distributions like Bazzite
- **Auto-updates** - Built-in support for automatic container updates

## Prerequisites

- Bazzite (or Fedora Atomic, Silverblue, Kinoite, uBlue, etc.)
- Podman 4.4+ (pre-installed on Bazzite)
- Docker Compose or Podman Compose (for expanding variables)
- yq (for YAML processing)
- Your NordVPN WireGuard private key

```bash
# Install podman-compose
pip install podman-compose
# or
brew install podman-compose

# Install yq
brew install yq
# or on Fedora/Bazzite
sudo dnf install yq
```

## Quick Start

### 1. Install Podlet

Podlet converts Docker Compose files to Quadlet format:

```bash
brew install podlet
```

Verify installation:

```bash
podlet --version
```

### 2. Clone and Configure

```bash
git clone https://github.com/dannyfranca/home-stream-server.git
cd home-stream-server

# Create your environment file
cp .env.example .env
nano .env
```

Fill in your `.env`:

```env
PUID=1000
PGID=1000
TZ=Europe/London
DATA_PATH=/var/home/YOUR_USER/media
```

### 3. Store Your WireGuard Key as a Podman Secret

The secret name must be `wireguard_private_key` to match the docker-compose.yml definition:

```bash
# Option A: Create interactively (paste your key, then Ctrl+D)
podman secret create wireguard_private_key -

# Option B: From the same file used by Docker Compose
podman secret create wireguard_private_key secrets/wireguard_private_key.txt

# Option C: From a temporary file
echo "your_private_key_here" > /tmp/wg_key
podman secret create wireguard_private_key /tmp/wg_key
rm /tmp/wg_key

# Verify it exists
podman secret ls
```

> ✅ **Cross-compatible**: Both Docker Compose and Podman mount secrets to `/run/secrets/wireguard_private_key`. The Gluetun container reads from this path via `WIREGUARD_PRIVATE_KEY_SECRETFILE`, so no code changes are needed between platforms.

### 4. Create Directory Structure

```bash
DATA_PATH="${DATA_PATH:-$HOME/media}"

mkdir -p "$DATA_PATH"/{torrents/{movies,tv},media/{movies,tv},config/{gluetun,qbittorrent,prowlarr,sonarr,radarr,bazarr,jellyfin,plex,jellyseerr}}
```

### 5. Generate and Install Quadlet Files

The compose file uses environment variables and file-based secrets that need processing before podlet can handle them:

```bash
cd ~/git/home-stream-server

# Option A: Using Docker Compose
docker compose config | yq '
  del(.secrets) | 
  del(.services.[].secrets) | 
  (.services.[] | select(.depends_on != null)).depends_on |= keys |
  (.services.[] | select(.network_mode != null)).network_mode |= sub("^service:", "container:")
' | podlet --unit-directory compose -

# Option B: Using Podman Compose
podman-compose config | yq '
  del(.secrets) | 
  del(.services.[].secrets) | 
  (.services.[] | select(.depends_on != null)).depends_on |= keys |
  (.services.[] | select(.network_mode != null)).network_mode |= sub("^service:", "container:")
' | podlet --unit-directory compose -

# Add the secret reference to gluetun container
sed -i '/^\[Container\]/a Secret=wireguard_private_key' ~/.config/containers/systemd/gluetun.container

# Reload systemd to pick up the new units
systemctl --user daemon-reload
```

> The `-u` / `--unit-directory` flag automatically places files in `~/.config/containers/systemd/` for rootless users.

> 💡 **What's happening**:
> - `compose config` expands all `${VAR:-default}` variables
> - `yq` strips secrets, converts `depends_on` to arrays, and fixes `network_mode` syntax
> - `sed` adds the `Secret=` line to use the Podman secret you created in step 3
> - Dependency ordering is preserved via systemd `After=` directives

> 💡 **Tip**: Podlet may warn about unsupported options (like `depends_on: condition`). These are usually non-critical — see Troubleshooting if services don't start in the right order.

Verify the generated files:

```bash
ls ~/.config/containers/systemd/
```

> ✅ **No manual adjustments needed for secrets!** The docker-compose.yml uses `WIREGUARD_PRIVATE_KEY_SECRETFILE` which is compatible with both Docker Compose and Podman. Both mount secrets to `/run/secrets/`. Podlet converts the `secrets:` section to Quadlet's `Secret=` directive automatically.

### 6. Start the Services

```bash
# Start all services
systemctl --user start gluetun qbittorrent prowlarr flaresolverr sonarr radarr bazarr jellyfin jellyseerr

# Or start them individually (gluetun first, as others depend on it)
systemctl --user start gluetun
systemctl --user start qbittorrent prowlarr
systemctl --user start flaresolverr sonarr radarr bazarr
systemctl --user start jellyfin jellyseerr
```

### 7. Enable Auto-Start on Boot

```bash
# Enable all services to start on boot
systemctl --user enable gluetun qbittorrent prowlarr flaresolverr sonarr radarr bazarr jellyfin jellyseerr

# Enable lingering so user services start without login
loginctl enable-linger $USER
```

### 8. Verify Everything is Running

```bash
# Check service status
systemctl --user status gluetun qbittorrent prowlarr sonarr radarr

# Check containers
podman ps

# Verify VPN is working
podman exec gluetun wget -qO- ifconfig.me && echo
```

## Service Management

### Common Commands

```bash
# View logs
journalctl --user -u gluetun -f
podman logs -f gluetun

# Restart a service
systemctl --user restart sonarr

# Stop all services
systemctl --user stop gluetun qbittorrent prowlarr flaresolverr sonarr radarr bazarr jellyfin jellyseerr

# Check which containers are running
podman ps -a
```

### Auto-Updates

Enable automatic container updates:

```bash
# Enable the podman auto-update timer
systemctl --user enable --now podman-auto-update.timer

# Check timer status
systemctl --user list-timers
```

Add `AutoUpdate=registry` to your `.container` files (podlet should add this by default).

## Networking Notes

### Container Communication

On Podman, containers communicate differently than Docker:

| Service     | Address from other containers             |
| ----------- | ----------------------------------------- |
| qBittorrent | `gluetun:8090` (shares gluetun's network) |
| Prowlarr    | `gluetun:9696` (shares gluetun's network) |
| Sonarr      | `sonarr:8989` or `localhost:8989`         |
| Radarr      | `radarr:7878` or `localhost:7878`         |
| Jellyfin    | `jellyfin:8096` or `localhost:8096`       |

> **Important**: qBittorrent and Prowlarr use `Network=container:gluetun`, so they share Gluetun's network namespace. Access them via `gluetun` hostname or the published ports on the host.

### Firewall (firewalld)

If services aren't accessible, check firewalld:

```bash
# Allow ports through firewall
sudo firewall-cmd --permanent --add-port=8090/tcp   # qBittorrent
sudo firewall-cmd --permanent --add-port=9696/tcp   # Prowlarr
sudo firewall-cmd --permanent --add-port=8989/tcp   # Sonarr
sudo firewall-cmd --permanent --add-port=7878/tcp   # Radarr
sudo firewall-cmd --permanent --add-port=6767/tcp   # Bazarr
sudo firewall-cmd --permanent --add-port=8096/tcp   # Jellyfin
sudo firewall-cmd --permanent --add-port=5055/tcp   # Jellyseerr
sudo firewall-cmd --permanent --add-port=8191/tcp   # FlareSolverr
sudo firewall-cmd --reload
```

## Troubleshooting

### Podlet Conversion Errors

If podlet reports unsupported options:

```bash
# List unsupported compose options
podlet compose docker-compose.yml 2>&1 | grep -i "unsupported\|error"
```

Common issues:
- `healthcheck.test` array format → manually add `HealthCmd=` to the quadlet file
- `depends_on.condition` → use `After=` and `Requires=` in `[Unit]` section

### Services Won't Start

```bash
# Check for errors
systemctl --user status gluetun
journalctl --user -u gluetun --no-pager -n 50

# Common issues:
# - SELinux: Add :Z or :z to volume mounts
# - Permissions: Check PUID/PGID match your user
# - Network: Ensure the .network file is installed
```

### VPN Connection Issues

```bash
# Check gluetun logs
podman logs gluetun

# Verify secret is accessible
podman secret ls

# Test VPN manually
podman run --rm --cap-add=NET_ADMIN --device=/dev/net/tun \
  -e VPN_SERVICE_PROVIDER=nordvpn \
  -e VPN_TYPE=wireguard \
  -e WIREGUARD_PRIVATE_KEY="your_key_here" \
  qmcgaw/gluetun:v3.40.3
```

### SELinux Denials

On Fedora-based systems, SELinux may block container access to volumes:

```bash
# Check for SELinux denials
sudo ausearch -m avc -ts recent

# Add :Z (private) or :z (shared) to volume mounts in quadlet files
# Volume=/path/to/data:/data:Z
```

### Resetting Everything

```bash
# Stop and disable all services
systemctl --user stop gluetun qbittorrent prowlarr flaresolverr sonarr radarr bazarr jellyfin jellyseerr
systemctl --user disable gluetun qbittorrent prowlarr flaresolverr sonarr radarr bazarr jellyfin jellyseerr

# Remove quadlet files
rm ~/.config/containers/systemd/*.container
rm ~/.config/containers/systemd/*.network

# Reload systemd
systemctl --user daemon-reload

# Remove containers and volumes (careful!)
podman rm -af
podman volume prune -f
```

## Directory Structure (Quadlet Setup)

```
~/.config/containers/systemd/
├── gluetun.container
├── qbittorrent.container
├── prowlarr.container
├── flaresolverr.container
├── sonarr.container
├── radarr.container
├── bazarr.container
├── jellyfin.container
├── plex.container
├── jellyseerr.container
└── home-stream-server.network

$DATA_PATH/
├── config/
│   ├── gluetun/
│   ├── qbittorrent/
│   ├── prowlarr/
│   ├── sonarr/
│   ├── radarr/
│   ├── bazarr/
│   ├── jellyfin/
│   └── jellyseerr/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

## Comparison: Docker Compose vs Quadlets

| Feature      | Docker Compose        | Quadlets                       |
| ------------ | --------------------- | ------------------------------ |
| Daemon       | Requires dockerd      | Daemonless (Podman)            |
| Init system  | Separate from systemd | Native systemd                 |
| Auto-start   | `restart: always`     | `WantedBy=default.target`      |
| Logs         | `docker logs`         | `journalctl --user -u service` |
| Updates      | Manual                | `podman auto-update`           |
| Rootless     | Requires config       | Default                        |
| Immutable OS | Challenging           | Native support                 |

## Resources

- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Podlet GitHub](https://github.com/containers/podlet)
- [Bazzite Documentation](https://universal-blue.discourse.group/docs?topic=561)
- [Red Hat Quadlet Guide](https://www.redhat.com/sysadmin/quadlet-podman)

---

**Happy Streaming on Bazzite! 🎮🍿**

