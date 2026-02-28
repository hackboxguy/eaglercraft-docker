# Eaglercraft Docker - Project Conventions

## Project Purpose
Docker build framework for self-contained EaglercraftX 1.8.8 servers. Runs browser-based
Minecraft 1.8.8 without accounts or installations. Designed for offline home/family gaming.

## Architecture
Single Docker container running 2 supervised services on 1 exposed port:
```
Browser :8081 -> BungeeCord (EaglerWeb) -> EaglercraftX 1.8 Web Client
Game    :8081 -> BungeeCord (EaglerXServer) -> PandaSpigot 1.8.8 :25565 (internal)
```

## Component Versions
| Component        | Version              | Source                                                                                      |
|------------------|----------------------|---------------------------------------------------------------------------------------------|
| Base Image       | Ubuntu 22.04         | Docker Hub                                                                                  |
| Java             | OpenJDK 17           | Ubuntu repos                                                                                |
| PandaSpigot      | 1.8.8 (latest build) | https://downloads.hpfxd.com/v2/projects/pandaspigot/versions/1.8.8/builds/latest/downloads/paperclip |
| BungeeCord       | Latest               | https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar |
| EaglerXServer    | v1.0.8               | https://github.com/lax1dude/eaglerxserver/releases/download/v1.0.8/EaglerXServer.jar       |
| EaglerWeb        | v1.0.8               | https://github.com/lax1dude/eaglerxserver/releases/download/v1.0.8/EaglerWeb.jar           |
| Web Client       | EaglercraftX 1.8     | GitHub mirrors (cloned during build)                                                        |

## Port Mapping
- **8081** (exposed): BungeeCord listener - serves both web client (HTTP) and game (WebSocket)
- **25565** (internal only): PandaSpigot backend server

## Container Directory Structure
```
/opt/eaglercraft/
  spigot/                 PandaSpigot server + world data
  bungee/                 BungeeCord proxy
    plugins/
      EaglerXServer.jar
      EaglerWeb.jar
      EaglerWeb/web/      Web client files (index.html, classes.js, assets.epk)
      EaglerXServer/      Generated config (listeners.yml, settings.yml)
  worlds/                 Persistent volume (symlinked from spigot/world)
  logs/                   Persistent volume
  scripts/                start-services.sh, health-check.sh
```

## Build & Test Commands
```bash
docker build -t eaglercraftx-server:local .          # Build image
docker-compose up -d                                  # Start server
docker-compose ps                                     # Check health
docker-compose logs -f eaglercraft                    # View logs
docker-compose down                                   # Stop server
curl -I http://localhost:8081                          # Test web client
```

## Key Config Files (inside container)
- `spigot/server.properties` - server-port=25565, online-mode=false
- `spigot/spigot.yml` - bungeecord: true
- `bungee/config.yml` - listener on 0.0.0.0:8081, server lobby -> localhost:25565
- `bungee/plugins/EaglerXServer/listeners.yml` - inject_address: "0.0.0.0:8081"
- `bungee/plugins/EaglerWeb/settings.json` - document_root: "web"

## Process Management
Supervisord manages 2 services:
1. **spigot** (autostart=true) - `java -Xmx1024M -jar PandaSpigot.jar nogui`
2. **bungee** (autostart=false) - `java -Xmx512M -jar BungeeCord.jar` (started after spigot is ready)
