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
| Web Client       | EaglercraftX 1.8     | GitHub mirrors with pre-built files (catfoolyou/EaglerX-Client etc.)                        |

## Port Mapping
- **8081** (exposed): BungeeCord listener - serves both web client (HTTP) and game (WebSocket)
- **25565** (internal only): PandaSpigot backend server

## Container Directory Structure
```
/opt/eaglercraft/
  spigot/                   PandaSpigot server
    PandaSpigot.jar
    server.properties
    spigot.yml
    eula.txt
    world -> ../worlds/world        (symlink)
    world_nether -> ../worlds/world_nether
    world_the_end -> ../worlds/world_the_end
  bungee/                   BungeeCord proxy
    BungeeCord.jar
    config.yml
    plugins/
      EaglercraftXServer.jar        (downloaded as EaglerXServer.jar)
      EaglerWeb.jar
      EaglercraftXServer/           Plugin data dir (note: full name, NOT EaglerXServer)
        listeners.yml
        settings.yml
      EaglerWeb/
        settings.json
        web/                        Web client files
          index.html
          classes.js (~22MB)
          assets.epk (~7MB)
          lang/
          favicon.png
  worlds/                   Persistent volume
  logs/                     Persistent volume
  scripts/
    start-services.sh
    health-check.sh
```

## Important Notes
- The EaglerXServer plugin data directory is named `EaglercraftXServer/` (full name),
  NOT `EaglerXServer/`. Config files must go in the full-name directory.
- PandaSpigot uses a paperclip launcher that patches itself on first run. The Dockerfile
  runs `--initSettings` during build to complete patching before runtime.
- The eaglercraft user must have UID 1000 to match volume ownership from the init container.
- Web client repos must contain PRE-BUILT files (classes.js, assets.epk). Source-only repos
  (like 3kh0/eaglercraft-1.8) will NOT work.

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
- `bungee/plugins/EaglercraftXServer/listeners.yml` - inject_address: "0.0.0.0:8081"
- `bungee/plugins/EaglerWeb/settings.json` - document_root: "web"

## Process Management
Supervisord manages 2 services:
1. **spigot** (autostart=true) - `java -Xmx1024M -jar PandaSpigot.jar nogui`
2. **bungee** (autostart=false) - `java -Xmx512M -jar BungeeCord.jar` (started after spigot is ready)
