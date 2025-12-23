# 🎬 Home Stream Server

A complete, production-ready Docker Compose stack for home media streaming with automated downloads, subtitles, and VPN-protected torrenting.

## ✨ Features

- **🔒 VPN Protection** - All torrent traffic routes through NordVPN WireGuard
- **📺 TV & Movies** - Automated downloads with Sonarr & Radarr
- **🎯 Smart Search** - Centralized indexers with Prowlarr
- **📝 Subtitles** - Automatic downloads with Bazarr
- **🎥 Streaming** - Beautiful media experience with Jellyfin
- **📱 Requests** - Easy media requests via Jellyseerr
- **💾 Optimized Storage** - Hardlink support for instant moves

## 📦 Services

| Service                               | Port  | Description                        |
| ------------------------------------- | ----- | ---------------------------------- |
| [qBittorrent](http://localhost:8090)  | 8090  | Torrent client (VPN protected)     |
| [Prowlarr](http://localhost:9696)     | 9696  | Indexer management (VPN protected) |
| [FlareSolverr](http://localhost:8191) | 8191  | Cloudflare bypass for indexers     |
| [Sonarr](http://localhost:8989)       | 8989  | TV show automation                 |
| [Radarr](http://localhost:7878)       | 7878  | Movie automation                   |
| [Bazarr](http://localhost:6767)       | 6767  | Subtitle management                |
| [Jellyfin](http://localhost:8096)     | 8096  | Media streaming server (free)      |
| [Plex](http://localhost:32400/web)    | 32400 | Media streaming server (freemium)  |
| [Jellyseerr](http://localhost:5055)   | 5055  | Request management                 |

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+ or Podman
- Docker Compose V2 or Podman Compose
- NordVPN subscription

### 1. Clone and Configure

```bash
cd ~/git/home-stream-server

# Copy the example environment file
cp .env.example .env

# Edit the configuration
nano .env
```

### 2. Get Your NordVPN WireGuard Key

You need to extract your WireGuard private key from NordVPN. Choose one method:

#### Method A: Using NordVPN Linux CLI (Recommended)

```bash
# Install NordVPN CLI (if not installed)
sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)

# Login to your account
sudo nordvpn login

# Set technology to NordLynx (WireGuard)
sudo nordvpn set technology nordlynx

# Connect to any server
sudo nordvpn c

# Extract the WireGuard config (copy the PrivateKey value)
sudo wg showconf nordlynx

# Disconnect when done
sudo nordvpn d
```

#### Method B: Using Access Token

1. Go to [NordVPN Dashboard](https://my.nordaccount.com/dashboard/nordvpn/)
2. Navigate to **Manual Setup** → **Set up NordVPN manually**
3. Generate an **Access Token**
4. Run this command (replace `YOUR_TOKEN`):

```bash
curl -s "https://api.nordvpn.com/v1/users/services/credentials" \
  -u token:YOUR_TOKEN | jq -r '.nordlynx_private_key'
```

### 3. Configure Your .env File
 
Edit `.env` and fill in your configuration, including the WireGuard private key you obtained in the previous step:

```env
# Your user/group IDs (run: id -u && id -g)
PUID=1000
PGID=1000

# Your timezone
TZ=Europe/London

# Where to store data (must have enough space!)
DATA_PATH=/srv/media

# NordVPN WireGuard Private Key
WIREGUARD_PRIVATE_KEY=your_private_key_here
```

> 💡 **Podman Support**: This stack is fully compatible with Podman Compose. Using an environment variable for the WireGuard key ensures seamless operation in rootless environments.

### 4. Create Media Directory Structure

Config directories are managed automatically using named volumes. You only need to create the **media and torrent directories** for bind mounts:

```bash
# Set your data path (match your .env)
DATA_PATH=/var/home/YOUR_USER/media

# Create media and torrent directories
sudo mkdir -p $DATA_PATH/{torrents/{movies,tv},media/{movies,tv}}

# Set ownership to your user
sudo chown -R $(id -u):$(id -g) $DATA_PATH

# Verify permissions
ls -la $DATA_PATH
```

> 💡 **Podman Users**: If using Podman in rootless mode, you may need to use `podman unshare` for proper UID mapping. See the [Troubleshooting](#permission-denied-errors) section for details.

### 5. Start the Stack

```bash
# Pull all images
docker compose pull # or 'podman compose pull'

# Start all services
docker compose up -d # or 'podman compose up -d'

# Check status
docker compose ps # or 'podman compose ps'

# View logs (optional)
docker compose logs -f # or 'podman compose logs -f'
```

### 6. Verify VPN Connection

```bash
# Check your current public IP
curl -s ifconfig.me && echo

# Check what IP the containers see
docker exec gluetun wget -qO- ifconfig.me && echo

# These should be DIFFERENT!
```

## 🌐 Networking Architecture

Understanding how the containers communicate:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Network                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────┐                    │
│  │           Gluetun (VPN Tunnel)          │◄── Internet via    │
│  │  ┌─────────────┐  ┌─────────────┐       │    NordVPN         │
│  │  │ qBittorrent │  │  Prowlarr   │       │                    │
│  │  │ :8090       │  │  :9696      │       │                    │
│  │  └─────────────┘  └─────────────┘       │                    │
│  └─────────────────────────────────────────┘                    │
│           ▲                    ▲                                │
│           │                    │                                │
│  ┌────────┴────────┐  ┌────────┴────────┐                       │
│  │     Sonarr      │  │     Radarr      │◄── Direct Internet    │
│  │   sonarr:8989   │  │   radarr:7878   │    (metadata only)    │
│  └────────┬────────┘  └────────┬────────┘                       │
│           │                    │                                │
│  ┌────────┴────────────────────┴────────┐                       │
│  │               Bazarr                 │                       │
│  │            bazarr:6767               │                       │
│  └───────────────────┬──────────────────┘                       │
│                      │                                          │
│  ┌───────────────────┴──────────────────┐                       │
│  │              Jellyfin                │◄── Direct Internet    │
│  │           jellyfin:8096              │    (metadata only)    │
│  └───────────────────┬──────────────────┘                       │
│                      │                                          │
│  ┌───────────────────┴──────────────────┐                       │
│  │             Jellyseerr               │                       │
│  │          jellyseerr:5055             │                       │
│  └──────────────────────────────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Container DNS Names

Docker Compose creates an internal network where containers communicate using their **service names** as hostnames:

| From          | To          | Address          |
| ------------- | ----------- | ---------------- |
| Sonarr/Radarr | qBittorrent | `gluetun:8090` ⚠️ |
| Prowlarr      | Sonarr      | `sonarr:8989`    |
| Prowlarr      | Radarr      | `radarr:7878`    |
| Bazarr        | Sonarr      | `sonarr:8989`    |
| Bazarr        | Radarr      | `radarr:7878`    |
| Jellyseerr    | Jellyfin    | `jellyfin:8096`  |
| Jellyseerr    | Sonarr      | `sonarr:8989`    |
| Jellyseerr    | Radarr      | `radarr:7878`    |

> ⚠️ **Important**: qBittorrent uses Gluetun's network, so connect to `gluetun:8090`, not `qbittorrent:8090`

### Do I Need a Proxy in Each App?

**No!** Here's why:

- **qBittorrent & Prowlarr**: Already fully VPN-protected via `network_mode: service:gluetun`. All their traffic goes through the WireGuard tunnel automatically.
- **Sonarr, Radarr, Bazarr**: Only fetch metadata from public APIs (TMDB, TVDB) - no privacy concern.
- **Jellyfin, Jellyseerr**: Only serve local media and fetch public metadata - no need for VPN.

Adding NordVPN SOCKS5/HTTP proxy would be **redundant and slower**. The Gluetun VPN tunnel already protects all torrent traffic.

## ⚙️ First-Run Setup

After starting the stack, configure each service:

### 1. qBittorrent (http://localhost:8090)

- Default credentials: `admin` / check logs with `docker logs qbittorrent`
- Go to **Tools** → **Options** → **Downloads**
  - Default Save Path: `/data/torrents`
- Go to **Options** → **Web UI**
  - Change the default password

### 2. Prowlarr (http://localhost:9696)

- Set up authentication on first visit
- **Connect FlareSolverr** (for Cloudflare-protected indexers):
  1. Go to **Settings** → **Indexers**
  2. Add **FlareSolverr**: Host: `http://flaresolverr:8191`
  3. Test the connection
- Go to **Settings** → **Apps**
  - Add **Sonarr**: `http://sonarr:8989` + API key from Sonarr
  - Add **Radarr**: `http://radarr:7878` + API key from Radarr
- Go to **Indexers** → **Add Indexer** and add recommended indexers (see below)

#### Recommended Indexers

| Indexer            | Best For                     | FlareSolverr Required |
| ------------------ | ---------------------------- | --------------------- |
| **1337x** ⭐        | TV Shows, Movies, General    | Yes                   |
| **TorrentGalaxy**  | Movies (incl. 4K), TV, Games | Sometimes             |
| **EZTV**           | TV Shows                     | No                    |
| **LimeTorrents**   | General                      | No                    |
| **The Pirate Bay** | General                      | No                    |
| **Nyaa.si**        | Anime, Asian media           | No                    |
| **BitSearch**      | Meta-search aggregator       | No                    |

> 💡 **Tips**:
> - Add **multiple indexers** for redundancy
> - Set **Minimum Seeders** to 5-10 in indexer settings to filter dead torrents
> - All indexer traffic is already VPN-protected (Prowlarr routes through Gluetun)

### 3. Sonarr (http://localhost:8989)

- Go to **Settings** → **General** → copy the **API Key** (for Prowlarr)
- Go to **Settings** → **Media Management**
  - Root Folder: `/data/media/tv`
- Go to **Settings** → **Download Clients**
  - Add **qBittorrent**: Host: `gluetun`, Port: `8090`

### 4. Radarr (http://localhost:7878)

- Go to **Settings** → **General** → copy the **API Key** (for Prowlarr)
- Go to **Settings** → **Media Management**
  - Root Folder: `/data/media/movies`
- Go to **Settings** → **Download Clients**
  - Add **qBittorrent**: Host: `gluetun`, Port: `8090`

### 5. Bazarr (http://localhost:6767)

- Go to **Settings** → **Sonarr**
  - Enable, Host: `sonarr`, Port: `8989`, API Key from Sonarr
- Go to **Settings** → **Radarr**
  - Enable, Host: `radarr`, Port: `7878`, API Key from Radarr
- Go to **Settings** → **Languages**
  - Set your preferred subtitle languages
- Go to **Settings** → **Providers**
  - Enable subtitle providers (OpenSubtitles, Subscene, etc.)

### 6. Jellyfin (http://localhost:8096)

- Complete the setup wizard
- Add libraries:
  - **Movies**: `/data/media/movies`
  - **TV Shows**: `/data/media/tv`
- Enable **Fetch missing metadata automatically**

### 7. Plex (http://localhost:32400/web)

- **First-time setup**: Get a claim token from [plex.tv/claim](https://plex.tv/claim) (valid 4 minutes)
- Add to `.env`: `PLEX_CLAIM=claim-xxxxx` and restart: `docker compose up -d plex`
- Or: Access http://localhost:32400/web and sign in with your Plex account
- Add libraries:
  - **Movies**: `/data/media/movies`
  - **TV Shows**: `/data/media/tv`
- Enable **Automatically update my library**

> 💡 **Plex vs Jellyfin**: Both share the same media. Use whichever you prefer, or both!

### 8. Jellyseerr (http://localhost:5055)

- Sign in with your Jellyfin credentials
- Add Jellyfin server: `http://jellyfin:8096`
- Add Radarr: `http://radarr:7878` + API key
- Add Sonarr: `http://sonarr:8989` + API key

## 🔧 Hardware Transcoding (Optional)

For smoother streaming with transcoding, enable hardware acceleration:

### Intel QuickSync

Uncomment in `docker-compose.yml`:

```yaml
jellyfin:
  devices:
    - /dev/dri:/dev/dri
```

### NVIDIA GPUs

1. Install [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
2. Uncomment in `docker-compose.yml`:

```yaml
jellyfin:
  runtime: nvidia
  deploy:
    resources:
      reservations:
        devices:
          - capabilities: [gpu]
```

## 🛠️ Troubleshooting

### VPN Won't Connect

```bash
# Check gluetun logs
docker logs gluetun # or 'podman logs gluetun'

# Verify your .env file contains the key
grep WIREGUARD_PRIVATE_KEY .env

# Common issues:
# - Missing or invalid WIREGUARD_PRIVATE_KEY in .env
# - Firewall blocking WireGuard (UDP port 51820)
# - (Podman) Missing TUN device access (gluetun handles this but check logs)
```

### Containers Can't Communicate

Make sure to use container names, not `localhost`:
- qBittorrent from Sonarr: `gluetun:8090` (routes through VPN container)
- Sonarr from Prowlarr: `sonarr:8989`

### Permission Denied Errors

Permission issues are common with Podman rootless mode due to UID/GID namespace mapping.

#### For Docker Users

```bash
# Verify PUID/PGID match your user
id -u  # Should match PUID in .env
id -g  # Should match PGID in .env

# Fix ownership of media directories
sudo chown -R $(id -u):$(id -g) $DATA_PATH
```

#### For Podman Rootless Users

Podman maps container UIDs to different host UIDs. Use `podman unshare` to set permissions correctly:

```bash
# Set your data path
DATA_PATH=/var/home/yourusername/media

# Option 1: Use podman unshare to fix ownership (recommended)
# This sets ownership to UID 1000 inside the container's user namespace
podman unshare chown -R 1000:1000 $DATA_PATH

# Option 2: Make directories world-writable (less secure, but works)
chmod -R 777 $DATA_PATH/torrents $DATA_PATH/media

# Check what the container sees
podman unshare ls -la $DATA_PATH
```

#### TUN Device Permission Denied (Gluetun)

If you see `open /dev/net/tun: permission denied`, the compose file already includes `privileged: true` for gluetun. If issues persist:

```bash
# Verify TUN device exists
ls -la /dev/net/tun

# Check gluetun logs
podman logs gluetun
```

#### Config Volume Permissions

Config directories use **named volumes** which are managed automatically by Docker/Podman. If you need to access config data:

```bash
# List volumes
podman volume ls

# Inspect a volume to find its location
podman volume inspect sonarr_config

# Access volume data (Podman)
podman unshare ls -la $(podman volume inspect sonarr_config --format '{{.Mountpoint}}')
```

### Downloads Not Moving to Library

Ensure Sonarr/Radarr can see the same paths:
- Download Client Remote Path: `/data/torrents`
- Library Root Folder: `/data/media/{movies,tv}`

## 📁 Directory Structure

```
home-stream-server/
├── docker-compose.yml
└── .env                              # Environment config (git-ignored)

# Named Volumes (managed by Docker/Podman - no manual setup needed)
# Use 'podman volume ls' or 'docker volume ls' to see them
gluetun_config
qbittorrent_config
prowlarr_config
sonarr_config
radarr_config
bazarr_config
jellyfin_config
plex_config
jellyseerr_config

# Bind Mounts (you create these)
$DATA_PATH/
├── torrents/
│   ├── movies/         # Movie downloads in progress
│   └── tv/             # TV downloads in progress
└── media/
    ├── movies/         # Completed movies (library)
    └── tv/             # Completed TV shows (library)
```

> 💡 **Why named volumes for config?** Named volumes are managed by the container runtime and avoid permission issues in Podman rootless mode. Your media files use bind mounts so you can easily access them from the host.

## 🔄 Updates

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Clean up old images
docker image prune -f
```

## 🐧 Running on Bazzite / Fedora Atomic [Work In Progress]

Want to run this stack with Podman Quadlets instead of Docker Compose? Perfect for immutable distributions like Bazzite, Silverblue, or Kinoite.

👉 **See [QUADLET.md](QUADLET.md) for the complete guide.**

Quick overview:
1. Install `podlet` to convert docker-compose.yml to Quadlet files
2. Store your WireGuard key as a Podman secret
3. Generate and install the Quadlet files
4. Enable systemd user services

## 📜 License

MIT License - Use freely for personal purposes.

---

**Happy Streaming! 🍿**
