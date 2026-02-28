# Migration Plan: Eaglercraft 1.5.2 -> EaglercraftX 1.8.8

## Status: COMPLETE

Migration successfully tested and deployed on 2026-02-28.

## Why Migrate?

The Eaglercraft ecosystem has evolved significantly. EaglercraftX 1.8.8 is now the most
stable and widely deployed version, with a modernized server plugin (EaglerXServer) that
unifies and simplifies the old BungeeCord-based setup. This migration brings:

- Minecraft 1.8.8 gameplay (more blocks, better mechanics, PBR shaders)
- Simplified architecture: 3 services -> 2, two ports -> one
- Modern Java 17 runtime (from Java 8)
- Unified EaglerXServer plugin (replaces legacy built-in BungeeCord integration)
- EaglerWeb plugin serves the web client (replaces Python HTTP server)
- PandaSpigot 1.8.8 backend (high-performance Paper fork, replaces CraftBukkit)

## What Changed

| Component        | Before (1.5.2)              | After (1.8.8)                     |
|------------------|-----------------------------|-----------------------------------|
| Minecraft        | 1.5.2                       | 1.8.8                             |
| Web Client       | Eaglercraft 1.5.2           | EaglercraftX 1.8.8               |
| Backend Server   | CraftBukkit 1.5.2-R1.0      | PandaSpigot 1.8.8                |
| Proxy            | BungeeCord (bundled)         | BungeeCord + EaglerXServer plugin |
| Web Server       | Python 3 http.server         | EaglerWeb plugin (on BungeeCord)  |
| Java             | OpenJDK 8                    | OpenJDK 17                       |
| Base Image       | Ubuntu 20.04                 | Ubuntu 22.04                     |
| Exposed Ports    | 8080 (web) + 25565 (game)    | 8081 (both web + game)           |
| Services         | 3 (Bukkit, BungeeCord, Python)| 2 (PandaSpigot, BungeeCord)      |

## Breaking Changes

1. **Port change**: Web client URL changes from `http://host:8080` to `http://host:8081`
2. **World data**: 1.5.2 worlds are NOT compatible with 1.8.8 - fresh worlds will be generated
3. **Docker image name**: Changes from `eaglercraft-server:local` to `eaglercraftx-server:local`
4. **Game connection**: Players no longer need to manually enter a server address -
   the server address can be pre-configured in the web client

## Migration Steps

- [x] Research latest component versions and download URLs
- [x] Create CLAUDE.md project conventions
- [x] Create PLAN.md (this file)
- [x] Rewrite Dockerfile for EaglercraftX 1.8.8 stack
- [x] Update docker-compose.yml (new port, image name)
- [x] Update README.md (new architecture, instructions)
- [x] Build and test the new Docker image
- [x] Verify web client loads in browser
- [x] Verify game connection works end-to-end

## Lessons Learned During Migration

1. **Plugin directory naming**: EaglerXServer's data directory is `EaglercraftXServer/`
   (full name), not `EaglerXServer/`. Config files placed in the wrong directory are ignored.
2. **PandaSpigot paperclip**: The paperclip JAR patches itself on first run and exits.
   Must run `--initSettings` during Docker build to avoid repeated restarts at runtime.
3. **User UID matching**: The container user must have UID 1000 to match the init
   container's `chown 1000:1000` on volume directories, otherwise permission denied errors.
4. **Web client repos**: Must use repos with PRE-BUILT client files (classes.js, assets.epk).
   Source-only repos (like 3kh0/eaglercraft-1.8) contain only build tools, not compiled output.
5. **Dockerfile heredocs**: `cat > file << 'EOF'` syntax does not work in Dockerfile RUN
   commands (even with BuildKit). Use `printf '%s\n' ... > file` instead.

## How to Build & Test

```bash
# Clean up old setup
docker compose down
rm -rf data/worlds/*    # Old 1.5.2 worlds won't work

# Build new image
docker build -t eaglercraftx-server:local .

# Start
docker compose up -d

# Test
docker compose logs -f eaglercraft     # Watch startup
# Open http://localhost:8081 in browser
```
