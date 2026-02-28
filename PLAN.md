# Version Plan: Eaglercraft 1.12.2 (v1.12.2 branch)

## Status: IN PROGRESS

Adapted from the EaglercraftX 1.8.8 Docker setup on the `main` branch.

## Why 1.12.2?

Eaglercraft 1.12.2 brings a newer Minecraft version with more content (concrete, glazed
terracotta, parrots, illagers, observer blocks, etc.) while also simplifying the server
architecture. EaglerXServer v1.0.8 runs directly on Paper 1.12.2 as a standalone plugin,
eliminating the need for BungeeCord proxy and supervisord process management.

## What Changed (vs 1.8.8 on main branch)

| Component        | 1.8.8 (main)                  | 1.12.2 (this branch)             |
|------------------|-------------------------------|----------------------------------|
| Minecraft        | 1.8.8                         | 1.12.2                           |
| Web Client       | EaglercraftX 1.8              | Eaglercraft 1.12.2              |
| Backend Server   | PandaSpigot 1.8.8             | Paper 1.12.2                    |
| Proxy            | BungeeCord + EaglerXServer    | None (EaglerXServer on Paper)   |
| Process Manager  | Supervisord (2 JVMs)          | None (single JVM)               |
| WorldEdit        | 6.1.2                         | 6.1.2                           |
| WorldGuard       | 6.1                           | 6.1.2                           |
| ViaVersion       | N/A                           | N/A (conflicts with EaglerXServer Netty injection) |
| Java             | OpenJDK 17                    | OpenJDK 17                      |
| Docker Image     | eaglercraftx-server:local     | eaglercraft-1.12.2-server:local |

## Key Simplifications

1. **No BungeeCord** — EaglerXServer runs directly on Paper
2. **No supervisord** — Single `java -jar Paper.jar` process
3. **No startup sequencing** — No need to wait for backend then start proxy
4. **No dual JVM memory tuning** — Single JVM gets all the RAM
5. **Simpler config** — No BungeeCord config.yml, no spigot.yml bungeecord=true

## Migration Steps

- [x] Research 1.12.2 component versions and download URLs
- [x] Rewrite Dockerfile for Paper 1.12.2 standalone architecture
- [x] Update docker-compose.yml (new image name)
- [x] Update README.md (new architecture, instructions)
- [x] Update PLAN.md (this file)
- [ ] Build and test the new Docker image
- [ ] Verify web client loads in browser
- [ ] Verify game connection works end-to-end

## Lessons Learned (carried from 1.8.8)

1. **Plugin directory naming**: EaglerXServer's data directory is `EaglercraftXServer/`
   (full name), not `EaglerXServer/`. Config files placed in the wrong directory are ignored.
2. **Paper paperclip**: The paperclip JAR patches itself on first run and exits.
   Must run `--initSettings` during Docker build to avoid repeated restarts at runtime.
3. **User UID matching**: The container user must have UID 1000 to match the init
   container's `chown 1000:1000` on volume directories, otherwise permission denied errors.
4. **Web client repos**: Must use repos with PRE-BUILT client files (classes.js, assets.epk).
   Source-only repos contain only build tools, not compiled output.
5. **Dockerfile heredocs**: `cat > file << 'EOF'` syntax does not work in Dockerfile RUN
   commands (even with BuildKit). Use `printf '%s\n' ... > file` instead.
6. **WorldEdit fat JAR**: Only `worldedit-bukkit-6.1.2.jar` from Maven is the full fat JAR
   (1.6MB+). Versions 6.1 and 6.1.5 are adapter-only JARs (156KB) missing core classes.
   Always use 6.1.2 — it supports both 1.8.8 and 1.12.2.
7. **WorldGuard fat JAR**: `worldguard-legacy-6.2.jar` from Maven is missing bundled
   dependencies (squirrelid library). Version 6.1 doesn't exist on Maven.
   Use `worldguard-legacy-6.1.2.jar` (1.2MB fat JAR with squirrelid bundled).
8. **EaglerXServer config filenames**: The Bukkit/Paper plugin uses `listener.yml`
   (singular), not `listeners.yml`. Wrong filename is silently ignored.
9. **ViaVersion incompatible with EaglerXServer on Bukkit**: ViaVersion replaces Paper's
   ChannelInitializer with BukkitChannelInitializer, which breaks EaglerXServer's Netty
   injection (NoSuchMethodException on initChannel). Since the Eaglercraft 1.12.2 client
   natively speaks protocol 340, ViaVersion is unnecessary anyway.

## How to Build & Test

```bash
# Switch to this branch
git checkout v1.12.2

# Build new image
docker build -t eaglercraft-1.12.2-server:local .

# Start
docker compose up -d

# Test
docker compose logs -f eaglercraft     # Watch startup
# Open http://localhost:8081 in browser
```
