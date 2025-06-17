# Eaglercraft Server Docker Image

A complete, self-contained Eaglercraft server that runs Minecraft 1.5.2 in web browsers without requiring Minecraft accounts or installations. Perfect for offline family gaming!

## ✨ Features

- 🎮 **Browser-based Minecraft 1.5.2** - No client installation required
- 🚫 **No accounts needed** - Kids can play immediately with any username
- 🔒 **Completely offline** - No internet dependency after setup
- 📦 **Single container** - Everything included (game server, proxy, web client)
- 💾 **Automatic persistence** - Worlds and logs saved locally in `./data/`
- 🔧 **Zero configuration** - Works out of the box with `docker-compose up -d`
- 🏥 **Health monitoring** - Built-in health checks and status reporting
- 👨‍👩‍👧‍👦 **Family-friendly** - Perfect for kids' multiplayer gaming

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Ports 8080 and 25565 available

### Option 1: Docker Compose (Recommended)

1. **Download the compose file:**
```bash
git clone https://github.com/hackboxguy/eaglercraft-docker.git;cd eaglercraft-docker
```

2. **Start the server (zero configuration required):**
```bash
docker-compose up -d
```

3. **That's it!** The setup automatically:
   - ✅ Downloads the Docker image
   - ✅ Creates data directories with proper permissions
   - ✅ Starts all services
   - ✅ Makes game data persistent in `./data/`

### Option 2: Docker Run (Simple)

```bash
docker run -d \
  --name eaglercraft \
  -p 8080:8080 \
  -p 25565:25565 \
  -v $(pwd)/data/worlds:/opt/eaglercraft/worlds \
  -v $(pwd)/data/logs:/opt/eaglercraft/logs \
  --restart unless-stopped \
  hackboxguy/eaglercraft-server:latest
```

## 🎯 How to Connect and Play

1. **Open your web browser**
2. **Navigate to:** `http://localhost:8080` (or `http://YOUR_SERVER_IP:8080`)
3. **Set your username** (no account required - any name works!)
4. **Choose a skin** (optional)
5. **Click "Multiplayer"** → **"Direct Connect"** → **"Connect to Server"**
6. **Enter server address:** `localhost:25565` (or `YOUR_SERVER_IP:25565`)
7. **Click "Connect"** and start building! 🏗️

## 📋 Server Information

| Service | Port | Description |
|---------|------|-------------|
| **Web Client** | 8080 | Browser-based Eaglercraft client |
| **Game Server** | 25565 | Minecraft server (WebSocket proxy) |

| Path | Description |
|------|-------------|
| `./data/worlds/` | Persistent Minecraft worlds |
| `./data/logs/` | Server logs and diagnostics |

## 🔧 Management Commands

### Basic Operations
```bash
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

## 🎮 Game Features

✅ **Creative and Survival modes**  
✅ **Multiplayer gameplay** (up to 20 players by default)  
✅ **World generation and building**  
✅ **Inventory management**  
✅ **Basic redstone mechanics**  
✅ **Animals and monsters**  
✅ **Day/night cycle**  
✅ **Weather effects**  
✅ **Persistent worlds** - builds are saved automatically  

## ⚙️ Configuration

### Environment Variables
```yaml
environment:
  - EAGLERCRAFT_MAX_PLAYERS=20                    # Max players (default: 20)
  - EAGLERCRAFT_MOTD=Welcome to Eaglercraft!      # Server message of the day
```

### Custom Configuration
```bash
# Edit server settings (after first run)
docker exec -it eaglercraft-server nano /opt/eaglercraft/bukkit/server.properties
docker exec -it eaglercraft-server nano /opt/eaglercraft/bungee/config.yml

# Restart to apply changes
docker-compose restart
```

## 🛠️ Troubleshooting

### Server Won't Start
```bash
# Check detailed logs
docker-compose logs eaglercraft-init
docker-compose logs eaglercraft

# Check service status
docker exec eaglercraft-server supervisorctl status
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

### Permission Issues
```bash
# Fix data directory permissions
sudo chown -R 1000:1000 data/
docker-compose restart
```

### Performance Issues
```bash
# Check resource usage
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

## 📁 Directory Structure

After running `docker-compose up -d`:
```
./
├── docker-compose.yml
└── data/                     # ← Auto-created with proper permissions
    ├── worlds/               # ← Minecraft worlds (persistent)
    │   ├── world/           # ← Main overworld
    │   ├── world_nether/    # ← Nether dimension  
    │   └── world_the_end/   # ← End dimension
    └── logs/                 # ← Server logs
        ├── bukkit.log       # ← Game server logs
        ├── bungee.log       # ← Proxy server logs
        └── web.log          # ← Web server logs
```

## 🔧 System Requirements

- **CPU:** 1+ cores (2+ recommended for multiple players)
- **RAM:** 2GB+ available (4GB+ recommended)
- **Storage:** 2GB+ for Docker image, additional space for worlds
- **Network:** Ports 8080 and 25565 accessible
- **OS:** Linux, macOS, Windows with Docker support

## 📦 What's Inside

The container runs three coordinated services:
- **Bukkit Server** (port 25566 internal) - Minecraft 1.5.2 game logic
- **BungeeCord Proxy** (port 25565 external) - WebSocket to TCP proxy  
- **Python Web Server** (port 8080) - Serves the Eaglercraft client

## 🏗️ Architecture

```
Browser (8080) → Python Web Server → Eaglercraft Client
                        ↓
Game Client → WebSocket (25565) → BungeeCord Proxy → Bukkit Server (25566)
```

## 📜 License & Credits

This project builds upon amazing open-source work:
- **[Eaglercraft](https://github.com/lax1dude/eaglercraft)** by LAX1DUDE - Browser-based Minecraft port
- **[CraftBukkit](https://getbukkit.org/)** - Minecraft 1.5.2 server implementation  
- **[BungeeCord](https://www.spigotmc.org/wiki/bungeecord/)** - Minecraft proxy server


## 🏷️ Docker Hub Tags

- `hackboxguy/eaglercraft-server:latest` - Latest stable release
- `hackboxguy/eaglercraft-server:v1.0` - Version 1.0
- `hackboxguy/eaglercraft-server:ubuntu20.04` - Ubuntu 20.04 based

---

**🎮 Happy Building! Enjoy your offline Minecraft adventures! ⛏️🏰**
