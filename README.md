# 🎬 Home Stream Server

A complete, production-ready stack for home media streaming with automated downloads, subtitles, and VPN-protected torrenting.

## ✨ Features

- **🔒 VPN Protection** - All torrent traffic routes through NordVPN WireGuard
- **📺 TV & Movies** - Automated downloads with Sonarr & Radarr
- **🎯 Smart Search** - Centralized indexers with Prowlarr
- **📝 Subtitles** - Automatic downloads with Bazarr
- **🎥 Streaming** - Beautiful media experience with Jellyfin or Plex
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

---

## 🚀 Quick Start

### Prerequisites

- NordVPN subscription
- One of these container runtimes:
  - **Docker** + Docker Compose V2
  - **Podman** + Podman Compose (or Quadlet for systemd integration)

### Choose Your Setup Method

| Method             | Best For                                    | Guide                    |
| ------------------ | ------------------------------------------- | ------------------------ |
| **Docker Compose** | Most users, Docker or Podman                | Continue below           |
| **Podman Quadlet** | Bazzite, Fedora Atomic, systemd integration | [QUADLET.md](QUADLET.md) |

---

# Part 1: Pre-Setup (Required for All Methods)

Complete these steps before proceeding to Docker Compose or Quadlet setup.

## 1.1 Get Your NordVPN WireGuard Key

You need to extract your WireGuard private key from NordVPN. Choose one method:

### Method A: Using NordVPN Linux CLI (Recommended)

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

### Method B: Using Access Token

1. Go to [NordVPN Dashboard](https://my.nordaccount.com/dashboard/nordvpn/)
2. Navigate to **Manual Setup** → **Set up NordVPN manually**
3. Generate an **Access Token**
4. Run this command (replace `YOUR_TOKEN`):

```bash
curl -s "https://api.nordvpn.com/v1/users/services/credentials" \
  -u token:YOUR_TOKEN | jq -r '.nordlynx_private_key'
```

## 1.2 Configure Environment Variables

```bash
# Navigate to the project
cd ~/git/home-stream-server

# Copy the example environment file
cp .env.example .env

# Edit the configuration
nano .env
```

Fill in your configuration:

```env
# Your user/group IDs (run: id -u && id -g)
PUID=1000
PGID=1000

# Your timezone (find yours: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
TZ=Europe/London

# Where to store data (must have enough space!)
DATA_PATH=/srv/media

# NordVPN WireGuard Private Key (from step 1.1)
WIREGUARD_PRIVATE_KEY=your_private_key_here
```

## 1.3 Create Media Directory Structure

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

> 💡 **Podman Users**: If using Podman in rootless mode, you may need to use `podman unshare` for proper UID mapping. See the [Troubleshooting](#permission-denied-errors) section.

---

# Part 2: Technical Setup

Choose **one** of the following based on your preference:

## Option A: Docker Compose Setup

This works with both **Docker** and **Podman**.

### Start the Stack

```bash
cd ~/git/home-stream-server

# Pull all images
docker compose pull  # or: podman compose pull

# Start all services
docker compose up -d  # or: podman compose up -d

# Check status
docker compose ps  # or: podman compose ps
```

### Verify VPN Connection

```bash
# Check your current public IP
curl -s ifconfig.me && echo

# Check what IP the containers see (should be DIFFERENT)
docker exec gluetun wget -qO- ifconfig.me && echo
```

➡️ **Continue to [Part 3: Service Configuration](#part-3-service-configuration)**

---

## Option B: Podman Quadlet Setup

For systemd integration on Fedora Atomic, Bazzite, or other immutable distros.

👉 **Follow the dedicated guide: [QUADLET.md](QUADLET.md)**

After completing the Quadlet setup, return here for service configuration.

➡️ **Continue to [Part 3: Service Configuration](#part-3-service-configuration)**

---

# Part 3: Service Configuration

After your containers are running, configure each service using these instructions.

## Service Hostnames Reference

> ⚠️ **Important**: Hostnames differ between Docker Compose and Quadlet!

| Connection         | Docker Compose      | Quadlet                 |
| ------------------ | ------------------- | ----------------------- |
| **→ qBittorrent**  | `gluetun:8090`      | `vpn-services:8090`     |
| **→ Prowlarr**     | `gluetun:9696`      | `vpn-services:9696`     |
| **→ Sonarr**       | `sonarr:8989`       | `media-automation:8989` |
| **→ Radarr**       | `radarr:7878`       | `media-automation:7878` |
| **→ Bazarr**       | `bazarr:6767`       | `media-automation:6767` |
| **→ Jellyfin**     | `jellyfin:8096`     | `media-streaming:8096`  |
| **→ FlareSolverr** | `flaresolverr:8191` | `flaresolverr:8191`     |

> 💡 **Docker Compose Note**: qBittorrent and Prowlarr share Gluetun's network, so use `gluetun` as the hostname, not their container names.

---

## 3.1 qBittorrent (http://localhost:8090)

1. Get the temporary password from logs:
   ```bash
   docker logs qbittorrent  # or: podman logs qbittorrent
   ```
2. Login with `admin` and the password from logs
3. Go to **Tools** → **Options** → **Downloads**
   - Default Save Path: `/data/torrents`
4. Go to **Options** → **Web UI**
   - Change the default password

---

## 3.2 Prowlarr (http://localhost:9696)

1. Set up authentication on first visit
2. **Connect FlareSolverr** (for Cloudflare-protected indexers):
   - Go to **Settings** → **Indexers**
   - Add **FlareSolverr**: `http://flaresolverr:8191`
   - Test the connection
3. Go to **Settings** → **Apps**
   - Add **Sonarr**: Use hostname from table above + API key from Sonarr
   - Add **Radarr**: Use hostname from table above + API key from Radarr
4. Go to **Indexers** → **Add Indexer** and add your preferred indexers

### Recommended Indexers

| Indexer            | Best For                     | FlareSolverr Required |
| ------------------ | ---------------------------- | --------------------- |
| **1337x** ⭐        | TV Shows, Movies, General    | Yes                   |
| **TorrentGalaxy**  | Movies (incl. 4K), TV, Games | Sometimes             |
| **EZTV**           | TV Shows                     | No                    |
| **LimeTorrents**   | General                      | No                    |
| **The Pirate Bay** | General                      | No                    |
| **Nyaa.si**        | Anime, Asian media           | No                    |

---

## 3.3 Sonarr (http://localhost:8989)

1. Go to **Settings** → **General** → copy the **API Key** (for Prowlarr)
2. Go to **Settings** → **Media Management**
   - Root Folder: `/data/media/tv`
3. Go to **Settings** → **Download Clients**
   - Add **qBittorrent**: Use hostname from table above, Port: `8090`

---

## 3.4 Radarr (http://localhost:7878)

1. Go to **Settings** → **General** → copy the **API Key** (for Prowlarr)
2. Go to **Settings** → **Media Management**
   - Root Folder: `/data/media/movies`
3. Go to **Settings** → **Download Clients**
   - Add **qBittorrent**: Use hostname from table above, Port: `8090`

---

## 3.5 Bazarr (http://localhost:6767)

1. Go to **Settings** → **Sonarr**
   - Enable, use Sonarr hostname from table, Port: `8989`, API Key from Sonarr
2. Go to **Settings** → **Radarr**
   - Enable, use Radarr hostname from table, Port: `7878`, API Key from Radarr
3. Go to **Settings** → **Languages**
   - Set your preferred subtitle languages
4. Go to **Settings** → **Providers**
   - Enable subtitle providers (OpenSubtitles, Subscene, etc.)

---

## 3.6 Jellyfin (http://localhost:8096)

1. Complete the setup wizard
2. Add libraries:
   - **Movies**: `/data/media/movies`
   - **TV Shows**: `/data/media/tv`
3. Enable **Fetch missing metadata automatically**

---

## 3.7 Plex (http://localhost:32400/web)

1. **First-time setup**: Get a claim token from [plex.tv/claim](https://plex.tv/claim) (valid 4 minutes)
2. Add to `.env`: `PLEX_CLAIM=claim-xxxxx` and restart the container
3. Add libraries:
   - **Movies**: `/data/media/movies`
   - **TV Shows**: `/data/media/tv`

> 💡 **Plex vs Jellyfin**: Both can share the same media library. Use whichever you prefer, or both!

---

## 3.8 Jellyseerr (http://localhost:5055)

1. Sign in with your Jellyfin credentials
2. Add Jellyfin server: Use Jellyfin hostname from table
3. Add Radarr: Use Radarr hostname from table + API key
4. Add Sonarr: Use Sonarr hostname from table + API key

---

# 🌐 Networking Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Container Network                         │
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
│  │     :8989       │  │     :7878       │    (metadata only)    │
│  └────────┬────────┘  └────────┬────────┘                       │
│           │                    │                                │
│  ┌────────┴────────────────────┴────────┐                       │
│  │               Bazarr                 │                       │
│  │               :6767                  │                       │
│  └───────────────────┬──────────────────┘                       │
│                      │                                          │
│  ┌───────────────────┴──────────────────┐                       │
│  │         Jellyfin / Plex              │◄── Direct Internet    │
│  │         :8096 / :32400               │    (metadata only)    │
│  └───────────────────┬──────────────────┘                       │
│                      │                                          │
│  ┌───────────────────┴──────────────────┐                       │
│  │             Jellyseerr               │                       │
│  │               :5055                  │                       │
│  └──────────────────────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

### Do I Need a Proxy in Each App?

**No!** Here's why:

- **qBittorrent & Prowlarr**: Already fully VPN-protected via network sharing with Gluetun
- **Sonarr, Radarr, Bazarr**: Only fetch metadata from public APIs - no privacy concern
- **Jellyfin, Plex, Jellyseerr**: Only serve local media - no need for VPN

---

# 🔧 Hardware Transcoding (Optional)

For smoother streaming with transcoding, enable hardware acceleration:

## Intel QuickSync

Uncomment in `docker-compose.yml` (or `media-streaming.kube` for Quadlet):

```yaml
jellyfin:
  devices:
    - /dev/dri:/dev/dri
```

## NVIDIA GPUs

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

---

# 🛠️ Troubleshooting

## VPN Won't Connect

```bash
# Check gluetun logs
docker logs gluetun  # or: podman logs gluetun

# Verify your .env file contains the key
grep WIREGUARD_PRIVATE_KEY .env

# Common issues:
# - Missing or invalid WIREGUARD_PRIVATE_KEY
# - Firewall blocking WireGuard (UDP port 51820)
```

## Containers Can't Communicate

- **Docker Compose**: Use `gluetun:8090` for qBittorrent (not `qbittorrent:8090`)
- **Quadlet**: Use pod names like `vpn-services:8090`
- See the [hostname table](#service-hostnames-reference)

## Permission Denied Errors

### Docker Users

```bash
# Verify PUID/PGID match your user
id -u  # Should match PUID in .env
id -g  # Should match PGID in .env

# Fix ownership
sudo chown -R $(id -u):$(id -g) $DATA_PATH
```

### Podman Rootless Users

```bash
# Fix ownership within Podman's user namespace
podman unshare chown -R 1000:1000 $DATA_PATH

# Or make directories world-writable (less secure)
chmod -R 777 $DATA_PATH/torrents $DATA_PATH/media
```

## Downloads Not Moving to Library

Ensure Sonarr/Radarr paths match:
- Download Client Remote Path: `/data/torrents`
- Library Root Folder: `/data/media/{movies,tv}`

---

# 📁 Directory Structure

```
home-stream-server/
├── docker-compose.yml      # Docker/Podman Compose config
├── quadlet/                # Podman Quadlet files (alternative)
├── .env                    # Environment config (git-ignored)
└── .env.example            # Template for .env

# Named Volumes (auto-managed)
gluetun_config, qbittorrent_config, prowlarr_config,
sonarr_config, radarr_config, bazarr_config,
jellyfin_config, plex_config, jellyseerr_config

# Bind Mounts (you create these)
$DATA_PATH/
├── torrents/
│   ├── movies/         # Downloads in progress
│   └── tv/
└── media/
    ├── movies/         # Completed (library)
    └── tv/
```

---

# 🔄 Updates

## Docker Compose

```bash
docker compose pull
docker compose up -d
docker image prune -f
```

## Quadlet

```bash
# Update images in YAML files, then:
systemctl --user restart vpn-services media-automation media-streaming
podman image prune -f
```

---

## 📜 License

MIT License - Use freely for personal purposes.

---

**Happy Streaming! 🍿**
