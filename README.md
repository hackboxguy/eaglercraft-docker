# Eaglercraft Server Docker Build Kit(Claude-AI assisted code)

A complete Docker build framework for creating self-contained Eaglercraft servers that run browser-based Minecraft 1.5.2 without requiring accounts or installations. Perfect for educational purposes and offline family gaming!

## ✨ Features

- 🎮 **Browser-based Minecraft 1.5.2** - No client installation required
- 🚫 **No accounts needed** - Educational environment with any username
- 🔒 **Completely offline** - No internet dependency after setup
- 📦 **Containerized solution** - Everything packaged in Docker
- 💾 **Automatic persistence** - Worlds and logs saved locally in `./data/`
- 🔧 **Zero configuration** - Works out of the box after building
- 🏥 **Health monitoring** - Built-in health checks and status reporting
- 🎓 **Educational focus** - Perfect for learning containerization and game servers

## 📋 Prerequisites

- Docker and Docker Compose installed
- Git (to clone this repository)
- 4GB+ RAM available
- Ports 8080 and 25565 available

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/hackboxguy/eaglercraft-docker.git
cd eaglercraft-docker
```

### Step 2: Build the Docker Image

```bash
# Build the Eaglercraft server image
docker build -t eaglercraft-server:local .
```

**⏱️ Build time:** 5-15 minutes depending on your internet connection

### Step 3: Deploy with Docker Compose

```bash
# Start the server (automatically sets up directories and permissions)
docker-compose up -d
```

### Step 4: Verify Everything is Running

```bash
# Check container status
docker-compose ps

# Watch startup logs
docker-compose logs -f eaglercraft
```

## 🎯 How to Connect and Play

1. **Open your web browser**
2. **Navigate to:** `http://localhost:8080` (or `http://YOUR_SERVER_IP:8080`)
3. **Set your username** (no account required - any name works!)
4. **Choose a skin** (optional)
5. **Click "Multiplayer"** → **"Direct Connect"** → **"Connect to Server"**
6. **Enter server address:** `localhost:25565` (or `YOUR_SERVER_IP:25565`)
7. **Click "Connect"** and start building! 🏗️

## 📦 What Gets Built

The build process creates a container with:
- **Ubuntu 20.04** base system
- **OpenJDK 8** runtime environment
- **Eaglercraft server components** (downloaded during build)
- **Web client files** for browser access
- **Supervisord** for process management
- **Automatic configuration** with proper networking

## 📋 Build Process Details

```bash
# The Dockerfile performs these steps:
1. 📥 Downloads Eaglercraft source from multiple fallback repositories
2. ✅ Validates all required server components
3. 🔧 Configures proper port separation (Bukkit: 25566, Proxy: 25565)
4. 🏠 Sets up directory structure and permissions
5. 📜 Creates management and health check scripts
6. 🚀 Configures supervisor for service management
```

## 🔧 Management Commands

### Basic Operations
```bash
# Build image
docker build -t eaglercraft-server:local .

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
docker-compose down && docker build -t eaglercraft-server:local . && docker-compose up -d
```

### Advanced Monitoring
```bash
# View individual service logs
docker exec eaglercraft-server tail -f /opt/eaglercraft/logs/bukkit.log
docker exec eaglercraft-server tail -f /opt/eaglercraft/logs/bungee.log
docker exec eaglercraft-server tail -f /opt/eaglercraft/logs/web.log

# Check service status inside container
docker exec eaglercraft-server supervisorctl status

# Restart individual services
docker exec eaglercraft-server supervisorctl restart bukkit
docker exec eaglercraft-server supervisorctl restart bungee
```

### Data Management
```bash
# Backup worlds and logs
tar -czf eaglercraft-backup-$(date +%Y%m%d).tar.gz data/

# Backup just worlds
tar -czf worlds-backup-$(date +%Y%m%d).tar.gz data/worlds/

# Restore from backup
tar -xzf eaglercraft-backup-20250615.tar.gz

# View world files
ls -la data/worlds/world/
```

## 🌐 Network Setup

### For Local Gaming (Same Network)
- **Web Client:** `http://192.168.1.XXX:8080`  
- **Game Server:** `192.168.1.XXX:25565`

### For Remote Access
```bash
# Open firewall ports (Ubuntu/Debian)
sudo ufw allow 8080/tcp
sudo ufw allow 25565/tcp

# Or for specific IP range
sudo ufw allow from 192.168.1.0/24 to any port 8080
sudo ufw allow from 192.168.1.0/24 to any port 25565
```

## 📁 Repository Structure

```
eaglercraft-docker/
├── Dockerfile              # ← Build instructions for the server
├── docker-compose.yml      # ← Deployment configuration
├── README.md               # ← This documentation
├── DISCLAIMER.md           # ← Legal notices and educational use
└── data/                   # ← Auto-created on first run
    ├── worlds/             # ← Persistent Minecraft worlds
    └── logs/               # ← Server logs and diagnostics
```

## 🛠️ Troubleshooting

### Build Issues
```bash
# If build fails due to network issues
docker build --no-cache -t eaglercraft-server:local .

# Check build logs for specific errors
docker build -t eaglercraft-server:local . 2>&1 | tee build.log

# Clean build (removes all cached layers)
docker system prune -a
docker build -t eaglercraft-server:local .
```

### Server Won't Start
```bash
# Check detailed logs
docker-compose logs eaglercraft-init
docker-compose logs eaglercraft

# Check service status
docker exec eaglercraft-server supervisorctl status

# Verify image was built correctly
docker images | grep eaglercraft-server
```

### Can't Connect from Browser
1. **Check web server:** `curl -I http://localhost:8080`
2. **Try different browser** (Chrome/Firefox recommended)
3. **Disable browser extensions** that might block WebSockets
4. **Check firewall settings**
5. **Use server IP instead of localhost** when connecting from other devices

### Can't Join Multiplayer Game
1. **Use correct server address:** `YOUR_SERVER_IP:25565` (not localhost for remote connections)
2. **Check game server:** `telnet YOUR_SERVER_IP 25565`
3. **Verify ports are open:** `sudo netstat -tlnp | grep -E ':(8080|25565)'`
4. **Try different browsers** or clear browser cache
5. **Check browser console** (F12 → Console) for WebSocket errors

### Performance Issues
```bash
# Check resource usage during build
docker system df

# Check runtime resource usage
docker stats eaglercraft-server

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

## 🔧 System Requirements

### For Building:
- **CPU:** 2+ cores recommended
- **RAM:** 4GB+ available during build
- **Storage:** 5GB+ free space
- **Network:** Stable internet for downloading components

### For Running:
- **CPU:** 1+ cores (2+ recommended for multiple players)
- **RAM:** 2GB+ available (4GB+ recommended)
- **Storage:** 2GB+ for built image, additional space for worlds
- **Network:** Ports 8080 and 25565 accessible

## 🏗️ Architecture

```
Browser (8080) → Python Web Server → Eaglercraft Client
                        ↓
Game Client → WebSocket (25565) → BungeeCord Proxy → Bukkit Server (25566)
```

The container runs three coordinated services:
- **Bukkit Server** (port 25566 internal) - Minecraft 1.5.2 game logic
- **BungeeCord Proxy** (port 25565 external) - WebSocket to TCP proxy  
- **Python Web Server** (port 8080) - Serves the Eaglercraft client

## 🎓 Educational Use

This project is designed for:
- **Learning Docker containerization**
- **Understanding multi-service architectures**
- **Exploring network proxying and WebSocket technology**
- **Educational gaming environments**
- **Family offline gaming setups**

## ⚖️ Legal Notice

This project is for **educational and research purposes only**. It builds upon open-source Eaglercraft implementations. Users are responsible for:
- Ensuring compliance with applicable laws
- Respecting intellectual property rights
- Using only for educational/research purposes
- Not distributing built images commercially


## 📜 Credits & License

This Docker build framework utilizes:
- **[Eaglercraft](https://github.com/lax1dude/eaglercraft)** by LAX1DUDE - Browser-based Minecraft port
- **[CraftBukkit](https://getbukkit.org/)** - Minecraft 1.5.2 server implementation  
- **[BungeeCord](https://www.spigotmc.org/wiki/bungeecord/)** - Minecraft proxy server


## 🔄 Updates and Maintenance

```bash
# Update to latest version
git pull origin main

# Rebuild with updates
docker-compose down
docker build --no-cache -t eaglercraft-server:local .
docker-compose up -d

# Clean old images (optional)
docker image prune -f
```

---

**🎮 Happy Building! Enjoy learning Docker while creating offline Minecraft adventures! ⛏️🐳**
