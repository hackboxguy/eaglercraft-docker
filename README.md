# EaglercraftX 1.8.8 Server - Docker Build Kit

A complete Docker build framework for creating self-contained EaglercraftX 1.8.8 servers that run browser-based Minecraft 1.8.8 without requiring accounts or installations. Perfect for educational purposes and offline family gaming!

> **Migrated from Eaglercraft 1.5.2** - See [PLAN.md](PLAN.md) for migration details.

## Features

- **Browser-based Minecraft 1.8.8** - No client installation required
- **No accounts needed** - Educational environment with any username
- **Completely offline** - No internet dependency after setup
- **Single port** - Web client and game server on one port (8081)
- **Containerized solution** - Everything packaged in Docker
- **Automatic persistence** - Worlds and logs saved locally in `./data/`
- **Zero configuration** - Works out of the box after building
- **Health monitoring** - Built-in health checks and status reporting
- **Modern stack** - Java 17, PandaSpigot 1.8.8, EaglerXServer

## Prerequisites

- Docker with BuildKit support (install `docker-buildx` if needed)
- Docker Compose
- Git (to clone this repository)
- 4GB+ RAM available
- Port 8081 available

## Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/hackboxguy/eaglercraft-docker.git
cd eaglercraft-docker
```

### Step 2: Build the Docker Image

```bash
docker build -t eaglercraftx-server:local .
```

**Build time:** 5-15 minutes depending on your internet connection

### Step 3: Deploy with Docker Compose

```bash
docker-compose up -d
```

### Step 4: Verify Everything is Running

```bash
docker-compose ps
docker-compose logs -f eaglercraft
```

## How to Connect and Play

1. **Open your web browser** (Chrome or Firefox recommended)
2. **Navigate to:** `http://localhost:8081` (or `http://YOUR_SERVER_IP:8081`)
3. **Set your username** (no account required - any name works!)
4. **Choose a skin** (optional)
5. **Click "Multiplayer"** - the local server should be pre-configured
6. **Start building!**

## What Gets Built

The build process creates a container with:
- **Ubuntu 22.04** base system
- **OpenJDK 17** runtime environment
- **PandaSpigot 1.8.8** - High-performance Minecraft server (Paper fork)
- **BungeeCord** - Proxy server with Eaglercraft plugins
- **EaglerXServer v1.0.8** - Eaglercraft WebSocket protocol plugin
- **EaglerWeb** - Serves the web client via HTTP on the same port
- **EaglercraftX 1.8 web client** - Browser-based game client
- **Supervisord** for process management

## Architecture

```
Browser (port 8081)
    |
    v
BungeeCord Proxy (port 8081)
    |--- HTTP requests --> EaglerWeb plugin --> EaglercraftX 1.8 Web Client
    |--- WebSocket     --> EaglerXServer plugin --> PandaSpigot 1.8.8 (port 25565 internal)
                                                         |
                                                    Game Worlds
                                                  (persistent volume)
```

The container runs two coordinated services:
- **PandaSpigot 1.8.8** (port 25565 internal) - Minecraft 1.8.8 game server
- **BungeeCord** (port 8081 external) - Serves web client AND handles WebSocket game connections

## Management Commands

### Basic Operations
```bash
# Build image
docker build -t eaglercraftx-server:local .

# Start server
docker-compose up -d

# Stop server
docker-compose down

# View startup logs
docker-compose logs -f

# Restart server
docker-compose restart

# Check status
docker-compose ps

# Rebuild and restart
docker-compose down && docker build -t eaglercraftx-server:local . && docker-compose up -d
```

### Advanced Monitoring
```bash
# View individual service logs
docker exec eaglercraftx-server tail -f /opt/eaglercraft/logs/spigot.log
docker exec eaglercraftx-server tail -f /opt/eaglercraft/logs/bungee.log

# Check service status inside container
docker exec eaglercraftx-server supervisorctl status

# Restart individual services
docker exec eaglercraftx-server supervisorctl restart spigot
docker exec eaglercraftx-server supervisorctl restart bungee
```

### Data Management
```bash
# Backup worlds and logs
tar -czf eaglercraft-backup-$(date +%Y%m%d).tar.gz data/

# Backup just worlds
tar -czf worlds-backup-$(date +%Y%m%d).tar.gz data/worlds/

# Restore from backup
tar -xzf eaglercraft-backup-20260228.tar.gz

# View world files
ls -la data/worlds/world/
```

## Network Setup

### For Local Gaming (Same Network)
- **Web Client + Game:** `http://192.168.1.XXX:8081`

### For Remote Access
```bash
# Open firewall port (Ubuntu/Debian)
sudo ufw allow 8081/tcp

# Or for specific IP range
sudo ufw allow from 192.168.1.0/24 to any port 8081
```

## Repository Structure

```
eaglercraft-docker/
├── Dockerfile              # Build instructions for the server
├── docker-compose.yml      # Deployment configuration
├── CLAUDE.md               # Project conventions for Claude Code
├── PLAN.md                 # Migration tracking document
├── README.md               # This documentation
├── LICENSE                 # Legal notices
└── data/                   # Auto-created on first run
    ├── worlds/             # Persistent Minecraft worlds
    │   ├── world/
    │   ├── world_nether/
    │   └── world_the_end/
    └── logs/               # Server logs and diagnostics
```

## Troubleshooting

### Docker BuildKit Required
This Dockerfile requires BuildKit. If you get a "legacy builder" error, install buildx:
```bash
# Arch Linux
sudo pacman -S docker-buildx

# Ubuntu/Debian
sudo apt-get install docker-buildx-plugin

# Or force BuildKit for a single build
DOCKER_BUILDKIT=1 docker build -t eaglercraftx-server:local .
```

### Build Issues
```bash
# If build fails due to network issues
docker build --no-cache -t eaglercraftx-server:local .

# Check build logs for specific errors
docker build -t eaglercraftx-server:local . 2>&1 | tee build.log

# Clean build (removes all cached layers)
docker system prune -a
docker build -t eaglercraftx-server:local .
```

### Server Won't Start
```bash
# Check detailed logs
docker-compose logs eaglercraft-init
docker-compose logs eaglercraft

# Check service status
docker exec eaglercraftx-server supervisorctl status

# Verify image was built correctly
docker images | grep eaglercraftx-server
```

### Can't Connect from Browser
1. **Check port is listening on host:** `ss -tlnp | grep 8081`
2. **Test from the server itself:** `curl -I http://localhost:8081`
3. **Try different browser** (Chrome/Firefox recommended)
4. **Disable browser extensions** that might block WebSockets
5. **Check firewall settings** (port 8081 must be open)
6. **Use server IP instead of localhost** when connecting from other devices

### Can't Join Game
1. **Verify the server is in the multiplayer list** - it should be pre-configured
2. **Check browser console** (F12 > Console) for WebSocket errors
3. **Verify port 8081 is accessible:** `curl -I http://YOUR_SERVER_IP:8081`
4. **Check service logs:** `docker exec eaglercraftx-server cat /opt/eaglercraft/logs/bungee.log`
5. **Try different browsers** or clear browser cache

### Performance Issues
```bash
# Check resource usage
docker stats eaglercraftx-server

# Adjust memory limits in docker-compose.yml
services:
  eaglercraft:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

## System Requirements

### For Building:
- **CPU:** 2+ cores recommended
- **RAM:** 4GB+ available during build
- **Storage:** 5GB+ free space
- **Network:** Stable internet for downloading components

### For Running:
- **CPU:** 1+ cores (2+ recommended for multiple players)
- **RAM:** 2GB+ available (4GB+ recommended)
- **Storage:** 2GB+ for built image, additional space for worlds
- **Network:** Port 8081 accessible

## Credits

This Docker build framework utilizes:
- **[EaglercraftX 1.8](https://eaglercraft.com/)** by lax1dude - Browser-based Minecraft 1.8.8 port
- **[EaglerXServer](https://github.com/lax1dude/eaglerxserver)** - Unified Eaglercraft server plugin
- **[PandaSpigot](https://github.com/hpfxd/PandaSpigot)** - High-performance Paper fork for 1.8.8
- **[BungeeCord](https://www.spigotmc.org/wiki/bungeecord/)** - Minecraft proxy server

## Legal Notice

This project is for **educational and research purposes only**. It builds upon open-source Eaglercraft implementations. Users are responsible for:
- Ensuring compliance with applicable laws
- Respecting intellectual property rights
- Using only for educational/research purposes
- Not distributing built images commercially

## Updates and Maintenance

```bash
# Update to latest version
git pull origin main

# Rebuild with updates
docker-compose down
docker build --no-cache -t eaglercraftx-server:local .
docker-compose up -d

# Clean old images (optional)
docker image prune -f
```

## Migrating from Eaglercraft 1.5.2

If you previously ran the 1.5.2 version of this project:

1. **Old worlds are incompatible** - delete `data/worlds/*` before starting
2. **Port changed** from 8080+25565 to just 8081
3. **Image name changed** from `eaglercraft-server:local` to `eaglercraftx-server:local`
4. See [PLAN.md](PLAN.md) for full migration details and lessons learned

---

**Happy Building! Enjoy Minecraft 1.8.8 in your browser!**
