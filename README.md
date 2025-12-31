# 🎬 Home Stream Server

A complete, production-ready stack for home media streaming with automated downloads, subtitles, and VPN-protected torrenting.

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
| [SABnzbd](http://localhost:8080)      | 8080  | Usenet downloader (VPN protected)  |
| [Prowlarr](http://localhost:9696)     | 9696  | Indexer management (VPN protected) |
| [FlareSolverr](http://localhost:8191) | 8191  | Cloudflare bypass for indexers     |
| Tor Proxy                             | 9050* | SOCKS5 proxy for .onion indexers   |
| [Sonarr](http://localhost:8989)       | 8989  | TV show automation                 |
| [Radarr](http://localhost:7878)       | 7878  | Movie automation                   |
| [Bazarr](http://localhost:6767)       | 6767  | Subtitle management                |
| [Jellyfin](http://localhost:8096)     | 8096  | Media streaming server (free)      |
| [Jellyseerr](http://localhost:5055)   | 5055  | Request management                 |

> *Tor Proxy is internal-only (port 9050 not exposed to host)

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Interactive Setup (Recommended)](#-interactive-setup-recommended)
- [Manual Setup](#-manual-setup)
  - [Pre-Setup](#part-1-pre-setup-required)
  - [Docker Compose](#option-a-docker-compose-setup)
  - [Podman Quadlet](#option-b-podman-quadlet-setup)
- [Service Configuration](#part-3-service-configuration)
  - [qBittorrent](#31-qbittorrent-httplocalhost8090)
    - [Share Ratio Limiting & Auto-Removal](#-share-ratio-limiting--auto-removal-recommended)
    - [Queue & Connection Limits](#-queue--connection-limits-recommended)
  - [SABnzbd](#32-sabnzbd-httplocalhost8080)
  - [Prowlarr](#33-prowlarr-httplocalhost9696)
  - [Sonarr](#34-sonarr-httplocalhost8989)
  - [Radarr](#35-radarr-httplocalhost7878)
  - [Bazarr](#36-bazarr-httplocalhost6767)
  - [Jellyfin](#37-jellyfin-httplocalhost8096)
  - [Jellyseerr](#38-jellyseerr-httplocalhost5055)
- [Networking Architecture](#-networking-architecture)
- [Hardware Transcoding](#-hardware-transcoding-optional)
- [Troubleshooting](#️-troubleshooting)
- [Directory Structure](#-directory-structure)
- [Updates](#-updates)

---

## 🚀 Quick Start

### Prerequisites

- NordVPN subscription
- One of these container runtimes:
  - **Docker** + Docker Compose V2
  - **Podman** + Podman Compose (or Quadlet for systemd integration)

### Choose Your Setup Method

| Method                 | Best For                                    | Setup                         |
| ---------------------- | ------------------------------------------- | ----------------------------- |
| **Interactive (Easy)** | Everyone - guided wizard                    | `make setup`                  |
| **Docker Compose**     | Docker or Podman users                      | [Manual Setup](#manual-setup) |
| **Podman Quadlet**     | Bazzite, Fedora Atomic, systemd integration | [Quadlet Guide](QUADLET.md)   |

---

# 🧙 Interactive Setup (Recommended)

The easiest way to get started is our interactive setup wizard:

```bash
# Clone the repository
git clone https://github.com/dannyfranca/home-stream-server.git
cd home-stream-server

# Run the interactive setup
make setup
```

The wizard will:
1. Ask for your configuration (user IDs, timezone, paths)
2. Guide you through getting your NordVPN WireGuard key
3. Create all necessary directories with proper permissions
4. Set up either Docker Compose or Podman Quadlet (your choice)
5. For Quadlet: Enable lingering for boot-time startup

### Available Make Commands

```bash
make help              # Show all available commands

# Setup
make setup             # Interactive setup wizard
make compose           # Setup Docker Compose only
make quadlet           # Setup Quadlet only

# Docker Compose
make compose-start     # Start compose stack
make compose-stop      # Stop compose stack
make compose-logs      # View logs
make compose-status    # Check status

# Quadlet
make quadlet-start     # Start all services
make quadlet-stop      # Stop all services
make quadlet-logs      # View logs
make quadlet-status    # Check status
make quadlet-enable    # Enable boot-time startup

# Utilities
make validate          # Check configuration
make vpn-check         # Verify VPN is working
make permissions       # Fix directory permissions
```

➡️ **After setup, continue to [Service Configuration](#part-3-service-configuration)**

---

# 📖 Manual Setup

If you prefer manual configuration over the interactive wizard, follow these steps.

## Part 1: Pre-Setup (Required)

### 1.1 Get Your NordVPN WireGuard Key

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

### 1.2 Configure Environment Variables

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

### 1.3 Create Media Directory Structure

```bash
# Set your data path (match your .env)
DATA_PATH=/var/home/YOUR_USER/media

# Create media and torrent directories
sudo mkdir -p $DATA_PATH/{torrents/{movies,tv},usenet/{movies,tv,complete,incomplete},media/{movies,tv}}

# Set ownership to your user
sudo chown -R $(id -u):$(id -g) $DATA_PATH

# (Fedora/Bazzite Users) Allow container access via SELinux
podman unshare chcon -R -t container_file_t $DATA_PATH

# Verify permissions
ls -la $DATA_PATH
```

> 💡 **Podman Users**: If using Podman in rootless mode, you may need to use `podman unshare` for proper UID mapping. See the [Troubleshooting](#permission-denied-errors) section.

---

## Part 2: Technical Setup

Choose **one** of the following based on your preference:

### Option A: Docker Compose Setup

This works with both **Docker** and **Podman**.

#### Start the Stack

```bash
cd ~/git/home-stream-server

# Pull all images
docker compose pull  # or: podman compose pull

# Start all services
docker compose up -d  # or: podman compose up -d

# Check status
docker compose ps  # or: podman compose ps
```

#### Verify VPN Connection

```bash
# Check your current public IP
curl -s ifconfig.me && echo

# Check what IP the containers see (should be DIFFERENT)
docker exec gluetun wget -qO- ifconfig.me && echo
```

➡️ **Continue to [Part 3: Service Configuration](#part-3-service-configuration)**

---

### Option B: Podman Quadlet Setup

For systemd integration on Fedora Atomic, Bazzite, or other immutable distros.

👉 **Follow the dedicated guide: [QUADLET.md](QUADLET.md)**

After completing the Quadlet setup, return here for service configuration.

➡️ **Continue to [Part 3: Service Configuration](#part-3-service-configuration)**

---

# Part 3: Service Configuration

After your containers are running, configure each service using these instructions.

## Service Hostnames Reference

> ⚠️ **Important**: Hostnames differ between Docker Compose and Quadlet!

| Connection         | Docker Compose      | Quadlet                  |
| ------------------ | ------------------- | ------------------------ |
| **→ qBittorrent**  | `gluetun:8090`      | `vpn-services:8090`      |
| **→ SABnzbd**      | `gluetun:8080`      | `vpn-services:8080`      |
| **→ Prowlarr**     | `gluetun:9696`      | `vpn-services:9696`      |
| **→ Sonarr**       | `sonarr:8989`       | `media-automation:8989`  |
| **→ Radarr**       | `radarr:7878`       | `media-automation:7878`  |
| **→ Bazarr**       | `bazarr:6767`       | `media-automation:6767`  |
| **→ Jellyfin**     | `jellyfin:8096`     | `media-streaming:8096`   |
| **→ FlareSolverr** | `flaresolverr:8191` | `flaresolverr:8191`      |
| **→ Tor Proxy**    | `tor-proxy:9050`    | `systemd-tor-proxy:9050` |

> 💡 **Docker Compose Note**: qBittorrent, SABnzbd, and Prowlarr share Gluetun's network, so use `gluetun` as the hostname, not their container names.

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

### 🔄 Share Ratio Limiting & Auto-Removal (Recommended)

To prevent endless torrents accumulating in your queue, configure automatic removal after seeding:

1. Go to **Tools** → **Options** → **BitTorrent**
2. Scroll to **Share Ratio Limiting** section
3. Configure these settings:

| Setting                                | Recommended Value      | Notes                              |
| -------------------------------------- | ---------------------- | ---------------------------------- |
| **When seeding ratio reaches**         | ☑️ `1.0`                | Upload as much as you downloaded   |
| **When seeding time reaches**          | ☑️ `10080` min (7 days) | Maximum seeding duration           |
| **When inactive seeding time reaches** | ☑️ `1440` min (1 day)   | Stop if no upload activity for 24h |
| **Then**                               | `Remove torrent`       | Removes entry, keeps files         |

> 💡 **How it works**: Torrents will be removed when reaching **either** the ratio limit **or** the time limit (whichever comes first). "Seeding time" only counts active upload time, not inactive periods.

> ⚠️ **Important**: Choose `Remove torrent` (not `Remove torrent and files`) since Sonarr/Radarr will have already imported the files to your media library via hardlinks.

### ⚡ Queue & Connection Limits (Recommended)

The default qBittorrent settings allow too many simultaneous transfers. Reduce them for better performance:

1. Go to **Tools** → **Options** → **BitTorrent**
2. Scroll to **Torrent Queueing** section and configure:

| Setting                                        | Recommended Value | Notes                                |
| ---------------------------------------------- | ----------------- | ------------------------------------ |
| **Maximum active downloads**                   | `3`               | Prevents bandwidth fragmentation     |
| **Maximum active uploads**                     | `3`               | Reasonable for home connections      |
| **Maximum active torrents**                    | `5`               | Total active (downloading + seeding) |
| **Do not count slow torrents in these limits** | ☑️ Enabled         | Allows progress when torrents stall  |

3. Go to **Connection** tab and configure:

| Setting                              | Recommended Value | Notes                               |
| ------------------------------------ | ----------------- | ----------------------------------- |
| **Global maximum connections**       | `200`             | Prevents router/system overload     |
| **Maximum connections per torrent**  | `50`              | Balance between speed and resources |
| **Global maximum upload slots**      | `10`              | Limits upload connections           |
| **Maximum upload slots per torrent** | `4`               | Per-torrent upload limit            |

> 💡 **Tip**: These conservative values work well for typical home connections (50-500 Mbps). Increase if you have gigabit fiber and a powerful router.

---

## 3.2 SABnzbd (http://localhost:8080)

1. Follow the wizard to set language and credentials
2. **Server Setup**:
   - Add your Usenet provider details (e.g., Newshosting, Eweka)
   - Enable SSL (usually port 563 or 443)
3. **Folder Setup**:
   - Temporary Download Folder: `/data/usenet/incomplete`
   - Completed Download Folder: `/data/usenet/complete`
4. **Categories**:
   - Create `movies` category -> Folder/Path: `movies`
   - Create `tv` category -> Folder/Path: `tv`

---

## 3.3 Prowlarr (http://localhost:9696)

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

| Indexer             | Type    | Best For                     | Proxy Needed    |
| ------------------- | ------- | ---------------------------- | --------------- |
| **nzbGeek** ⭐       | Usenet  | TV, Movies, High retention   | No              |
| **1337x (Onion)** ⭐ | Torrent | TV Shows, Movies, General    | Tor (see below) |
| **1337x**           | Torrent | TV Shows, Movies, General    | FlareSolverr    |
| **TorrentGalaxy**   | Torrent | Movies (incl. 4K), TV, Games | Sometimes       |
| **EZTV**            | Torrent | TV Shows                     | No              |

### 🧅 Using 1337x via Tor (Recommended)

This stack includes a custom **1337x (Onion)** indexer that bypasses Cloudflare entirely by using the official `.onion` address via Tor. This is more reliable than FlareSolverr.

**Setup Steps:**

1. **Configure Tor Proxy in Prowlarr:**
   - Go to **Settings** → **Indexers** → **Indexer Proxies**
   - Click **+** → **SOCKS5**
   - **Name**: `Tor`
   - **Host**: `tor-proxy` (Docker Compose) or `systemd-tor-proxy` (Quadlet)
   - **Port**: `9050`
   - **Tag**: `tor`
   - Click **Test** then **Save**

2. **Add the 1337x Onion Indexer:**
   - Go to **Indexers** → **Add Indexer**
   - Search for **1337x (Onion)** (custom definition)
   - Configure settings (magnet links recommended)
   - **Important**: Add the `tor` tag to route through Tor
   - Click **Test** then **Save**

> ⚠️ **Note**: The onion site is in beta with some limitations (no registration, limited login for regular users). Search functionality works without login.

---

## 3.4 Sonarr (http://localhost:8989)

1. Go to **Settings** → **General** → copy the **API Key** (for Prowlarr)
2. Go to **Settings** → **Media Management**
   - Root Folder: `/data/media/tv`
3. Go to **Settings** → **Download Clients**
   - Add **qBittorrent**: Use hostname from table above, Port: `8090`
   - Add **SABnzbd**: Use hostname from table above, Port: `8080`, API Key from SABnzbd
4. **Enable Completed Download Handling** (in each download client's advanced settings):
   - ☑️ **Remove** - Removes torrent from qBittorrent after import
   
> 💡 **Note**: Sonarr will only remove torrents after they've stopped seeding (based on qBittorrent's share ratio limits). This works with hardlinks - your media files remain in the library.

---

## 3.5 Radarr (http://localhost:7878)

1. Go to **Settings** → **General** → copy the **API Key** (for Prowlarr)
2. Go to **Settings** → **Media Management**
   - Root Folder: `/data/media/movies`
3. Go to **Settings** → **Download Clients**
   - Add **qBittorrent**: Use hostname from table above, Port: `8090`
   - Add **SABnzbd**: Use hostname from table above, Port: `8080`, API Key from SABnzbd
4. **Enable Completed Download Handling** (in each download client's advanced settings):
   - ☑️ **Remove** - Removes torrent from qBittorrent after import
   
> 💡 **Note**: Same as Sonarr - torrents are only removed after meeting qBittorrent's share ratio limits.

---

## 3.6 Bazarr (http://localhost:6767)

1. Go to **Settings** → **Sonarr**
   - Enable, use Sonarr hostname from table, Port: `8989`, API Key from Sonarr
2. Go to **Settings** → **Radarr**
   - Enable, use Radarr hostname from table, Port: `7878`, API Key from Radarr
3. Go to **Settings** → **Languages**
   - Set your preferred subtitle languages
4. Go to **Settings** → **Providers**
   - Enable subtitle providers (OpenSubtitles, Subscene, etc.)

---

## 3.7 Jellyfin (http://localhost:8096)

1. Complete the setup wizard
2. Add libraries:
   - **Movies**: `/data/media/movies`
   - **TV Shows**: `/data/media/tv`
3. Enable **Fetch missing metadata automatically**

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
│  │  │ qBittorrent │  │   SABnzbd   │       │                    │
│  │  │ :8090       │  │   :8080     │       │                    │
│  │  └─────────────┘  └─────────────┘       │                    │
│  │  ┌─────────────┐                        │                    │
│  │  │  Prowlarr   │                        │                    │
│  │  │  :9696      │                        │                    │
│  │  └─────────────┘                        │                    │
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
│  │            Jellyfin                  │◄── Direct Internet    │
│  │            :8096                     │    (metadata only)    │
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

- **qBittorrent, SABnzbd & Prowlarr**: Already fully VPN-protected via network sharing with Gluetun
- **Sonarr, Radarr, Bazarr**: Only fetch metadata from public APIs - no privacy concern
- **Jellyfin, Jellyseerr**: Only serve local media - no need for VPN

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

### SELinux Permission Denied (Fedora/Bazzite)

If logs show `Permission denied` or `not writable` even with correct ownership:

```bash
# Update SELinux labels to allow container access
podman unshare chcon -R -t container_file_t $DATA_PATH
```

## Downloads Not Moving to Library

Ensure Sonarr/Radarr paths match:
- Download Client Remote Path: `/data/torrents`
- Library Root Folder: `/data/media/{movies,tv}`

## Quadlet Services Won't Start at Boot

For services to start at boot (without logging in), you need **lingering** enabled:

```bash
# Enable lingering for your user
sudo loginctl enable-linger $USER

# Verify it's enabled
loginctl show-user $USER | grep Linger
# Should show: Linger=yes

# Enable the services
systemctl --user enable vpn-services media-automation media-streaming flaresolverr tor-proxy
```

---

# 📁 Directory Structure

```
home-stream-server/
├── Makefile                # Make commands for setup and management
├── scripts/
│   └── setup.sh            # Interactive setup wizard
├── docker-compose.yml      # Docker/Podman Compose config
├── quadlet/
│   └── templates/          # Quadlet templates (processed during setup)
├── prowlarr-definitions/   # Custom indexers (1337x-onion, etc.)
├── .env                    # Environment config (git-ignored)
└── .env.example            # Template for .env

# Named Volumes (auto-managed)
gluetun_config, qbittorrent_config, sabnzbd_config, prowlarr_config,
sonarr_config, radarr_config, bazarr_config,
jellyfin_config, jellyseerr_config

# Bind Mounts (you create these)
$DATA_PATH/
├── torrents/
│   ├── movies/         # Downloads in progress
│   └── tv/
├── usenet/
│   ├── complete/       # Completed usenet downloads
│   └── incomplete/
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
# Update images in template YAML files, then:
make quadlet           # Re-process templates
make quadlet-start     # Restart services
podman image prune -f
```

---

## 📜 License

MIT License - Use freely for personal purposes.

---

**Happy Streaming! 🍿**
