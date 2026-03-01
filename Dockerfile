# Dockerfile for Eaglercraft 1.12.2 Server
# Compatible with legacy Docker builder - no BuildKit required
# Architecture: Paper 1.12.2 with EaglerXServer + EaglerWeb (single process, no proxy)

# ============================================================
# Stage 1: Download web client files and validate
# ============================================================
FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Download official Eaglercraft 1.12.2 web client from eaglercraft.dev (by PeytonPlayz585/lax1dude)
# Note: XxFluffyAsherxX/Eaglercraft-1.12.2 repo has mismatched files (classes.js expects
# plugin_version.json in EPK but it's missing). The official eaglercraft.dev build works correctly.
RUN echo "=== Downloading Eaglercraft 1.12.2 web client ===" && \
    mkdir -p /build/web && \
    curl -fSL -o /build/web/classes.js "https://eaglercraft.dev/clients/Release%201.12.2%20JS/classes.js" && \
    curl -fSL -o /build/web/assets.epk "https://eaglercraft.dev/clients/Release%201.12.2%20JS/assets.epk" && \
    curl -fSL -o /build/web/favicon.png "https://eaglercraft.dev/clients/Release%201.12.2%20JS/favicon.png" && \
    echo "=== Web client files ===" && \
    ls -la /build/web/ && \
    echo "=== Validating required files ===" && \
    [ -f "/build/web/classes.js" ] || { echo "ERROR: classes.js missing!"; exit 1; } && \
    [ -f "/build/web/assets.epk" ] || { echo "ERROR: assets.epk missing!"; exit 1; } && \
    echo "Validation passed: classes.js and assets.epk found"

# Create index.html matching official eaglercraft.dev structure:
# - classes.js in <head> (defines TeaVM runtime + main())
# - game_frame is the <body> element itself (not a child div)
# - eaglercraftXOpts set in load handler, then main() called to start game
RUN printf '%s\n' \
    '<!DOCTYPE html>' \
    '<html lang="und" style="width:100%;height:100%;background-color:black;">' \
    '<head>' \
    '<meta charset="UTF-8">' \
    '<meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0">' \
    '<title>Eaglercraft 1.12.2</title>' \
    '<link type="image/png" rel="shortcut icon" href="favicon.png">' \
    '<script type="text/javascript" src="classes.js"></script>' \
    '<script type="text/javascript">' \
    '"use strict";' \
    'window.addEventListener("load", function() {' \
    '    window.eaglercraftXOpts = {' \
    '        demoMode: false,' \
    '        container: "game_frame",' \
    '        assetsURI: "assets.epk",' \
    '        worldsDB: "worlds",' \
    '        logInvalidCerts: true,' \
    '        crashOnUncaughtExceptions: true,' \
    '        enableMinceraft: false,' \
    '        servers: [' \
    '            { addr: "ws://" + window.location.hostname + ":8081/", name: "Local Server", hideAddr: true }' \
    '        ],' \
    '        checkShaderGLErrors: false,' \
    '        enableDownloadOfflineButton: false,' \
    '        downloadOfflineButtonLink: null,' \
    '        html5CursorSupport: false,' \
    '        allowServerRedirects: false,' \
    '        enableSignatureBadge: false,' \
    '        checkRelaysForUpdates: false,' \
    '        allowVoiceClient: false' \
    '    };' \
    '    main();' \
    '});' \
    '</script>' \
    '</head>' \
    '<body style="margin:0;width:100%;height:100%;overflow:hidden;background-color:black;" id="game_frame">' \
    '</body>' \
    '</html>' \
    > /build/web/index.html && \
    echo "=== Web client preparation complete ==="

# ============================================================
# Stage 2: Runtime container
# ============================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV EAGLER_HOME=/opt/eaglercraft
ENV EAGLER_USER=eaglercraft

# Install runtime dependencies (no supervisor needed — single JVM process)
RUN apt-get update && \
    apt-get install -y \
    openjdk-17-jre-headless \
    curl \
    procps \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Create eaglercraft user with UID 1000 (must match init container's chown 1000:1000)
RUN useradd -u 1000 -m -d $EAGLER_HOME -s /bin/bash $EAGLER_USER && \
    mkdir -p $EAGLER_HOME/server/plugins/EaglerWeb/web && \
    mkdir -p $EAGLER_HOME/server/plugins/EaglercraftXServer && \
    mkdir -p $EAGLER_HOME/worlds && \
    mkdir -p $EAGLER_HOME/logs && \
    mkdir -p $EAGLER_HOME/scripts && \
    chown -R $EAGLER_USER:$EAGLER_USER $EAGLER_HOME

# Download Paper 1.12.2 and run paperclip patching during build
RUN echo "=== Downloading Paper 1.12.2 ===" && \
    curl -fSL -o $EAGLER_HOME/server/Paper.jar \
    "https://api.papermc.io/v2/projects/paper/versions/1.12.2/builds/1620/downloads/paper-1.12.2-1620.jar" && \
    echo "Paper downloaded: $(ls -lh $EAGLER_HOME/server/Paper.jar | awk '{print $5}')" && \
    echo "=== Running paperclip patching ===" && \
    cd $EAGLER_HOME/server && \
    echo "eula=true" > eula.txt && \
    java -jar Paper.jar --initSettings 2>&1 || true && \
    rm -rf world world_nether world_the_end crash-reports logs && \
    rm -f session.lock && \
    echo "=== Paperclip patching complete ===" && \
    ls -la $EAGLER_HOME/server/

# Download EaglerXServer v1.0.8 and EaglerWeb plugins (run on Paper directly, no proxy)
RUN echo "=== Downloading EaglerXServer plugins ===" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/EaglercraftXServer.jar \
    "https://github.com/lax1dude/eaglerxserver/releases/download/v1.0.8/EaglerXServer.jar" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/EaglerWeb.jar \
    "https://github.com/lax1dude/eaglerxserver/releases/download/v1.0.8/EaglerWeb.jar" && \
    echo "EaglerXServer downloaded: $(ls -lh $EAGLER_HOME/server/plugins/EaglercraftXServer.jar | awk '{print $5}')" && \
    echo "EaglerWeb downloaded: $(ls -lh $EAGLER_HOME/server/plugins/EaglerWeb.jar | awk '{print $5}')"

# Download plugins: analytics, permissions, essentials, world protection
# Note: ViaVersion/ViaBackwards/ViaRewind removed — they conflict with EaglerXServer's
# Netty pipeline injection on Bukkit (BukkitChannelInitializer.initChannel NoSuchMethodException)
# and are unnecessary since Eaglercraft 1.12.2 client natively speaks protocol 340 (MC 1.12.2)
RUN echo "=== Downloading Paper plugins ===" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/Plan.jar \
    "https://github.com/plan-player-analytics/Plan/releases/download/5.6.2965/Plan-5.6-build-2965.jar" && \
    echo "Plan downloaded: $(ls -lh $EAGLER_HOME/server/plugins/Plan.jar | awk '{print $5}')" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/Vault.jar \
    "https://github.com/MilkBowl/Vault/releases/download/1.7.3/Vault.jar" && \
    echo "Vault downloaded: $(ls -lh $EAGLER_HOME/server/plugins/Vault.jar | awk '{print $5}')" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/LuckPerms.jar \
    "https://download.luckperms.net/1624/bukkit/loader/LuckPerms-Bukkit-5.5.36.jar" && \
    echo "LuckPerms downloaded: $(ls -lh $EAGLER_HOME/server/plugins/LuckPerms.jar | awk '{print $5}')" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/EssentialsX.jar \
    "https://github.com/EssentialsX/Essentials/releases/download/2.19.7/EssentialsX-2.19.7.jar" && \
    echo "EssentialsX downloaded: $(ls -lh $EAGLER_HOME/server/plugins/EssentialsX.jar | awk '{print $5}')" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/EssentialsXChat.jar \
    "https://github.com/EssentialsX/Essentials/releases/download/2.19.7/EssentialsXChat-2.19.7.jar" && \
    echo "EssentialsXChat downloaded: $(ls -lh $EAGLER_HOME/server/plugins/EssentialsXChat.jar | awk '{print $5}')" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/EssentialsXSpawn.jar \
    "https://github.com/EssentialsX/Essentials/releases/download/2.19.7/EssentialsXSpawn-2.19.7.jar" && \
    echo "EssentialsXSpawn downloaded: $(ls -lh $EAGLER_HOME/server/plugins/EssentialsXSpawn.jar | awk '{print $5}')" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/WorldEdit.jar \
    "https://maven.enginehub.org/repo/com/sk89q/worldedit/worldedit-bukkit/6.1.2/worldedit-bukkit-6.1.2.jar" && \
    echo "WorldEdit downloaded: $(ls -lh $EAGLER_HOME/server/plugins/WorldEdit.jar | awk '{print $5}')" && \
    curl -fSL -o $EAGLER_HOME/server/plugins/WorldGuard.jar \
    "https://maven.enginehub.org/repo/com/sk89q/worldguard/worldguard-legacy/6.1.2/worldguard-legacy-6.1.2.jar" && \
    echo "WorldGuard downloaded: $(ls -lh $EAGLER_HOME/server/plugins/WorldGuard.jar | awk '{print $5}')"

# Copy web client files from builder stage
COPY --from=builder --chown=$EAGLER_USER:$EAGLER_USER /build/web $EAGLER_HOME/server/plugins/EaglerWeb/web/

# Configure Paper server.properties (Paper listens directly on 8081, no proxy)
RUN printf '%s\n' \
    'server-port=8081' \
    'server-ip=0.0.0.0' \
    'online-mode=false' \
    'spawn-protection=0' \
    'max-players=20' \
    'level-name=world' \
    'motd=Eaglercraft 1.12.2 Server' \
    'gamemode=0' \
    'difficulty=1' \
    'allow-nether=true' \
    'generate-structures=true' \
    'view-distance=10' \
    > $EAGLER_HOME/server/server.properties

# Accept EULA
RUN echo "eula=true" > $EAGLER_HOME/server/eula.txt

# Configure EaglerXServer listener.yml (singular — plugin uses listener.yml not listeners.yml)
RUN printf '%s\n' \
    'listener_list:' \
    '  - listener_name: "default"' \
    '    inject_address: "0.0.0.0:8081"' \
    '    max_players: 20' \
    '    server_icon: null' \
    '    server_motd:' \
    '      - "Eaglercraft 1.12.2 Server"' \
    '    allow_motd: true' \
    '    allow_query: true' \
    '    forward_ip: false' \
    '    enable_tls: false' \
    '    require_tls: false' \
    > $EAGLER_HOME/server/plugins/EaglercraftXServer/listener.yml

# Configure EaglerXServer settings.yml
RUN printf '%s\n' \
    'enable_eaglercraft_protocol_v4: true' \
    'enable_eaglercraft_protocol_v3: true' \
    'enable_eaglercraft_protocol_v2: true' \
    'enable_backend_rpc_protocol_v1: false' \
    'allow_eaglerplayer_skin: true' \
    'allow_eaglerplayer_cape: true' \
    'allow_fnaw_skins: true' \
    'enable_is_eagler_player_property: true' \
    'cache_skin_packets: true' \
    'skin_cache_db_uri: ""' \
    'touch_controls_mode: "auto"' \
    'eagler_players_vanilla_skin: "lax1dude"' \
    'enable_voice_chat: false' \
    'debug_log_new_channels: true' \
    > $EAGLER_HOME/server/plugins/EaglercraftXServer/settings.yml

# Configure EaglerWeb settings.json
RUN printf '%s\n' \
    '{' \
    '    "memory_cache_expires_after": 300,' \
    '    "memory_cache_max_files": 128,' \
    '    "file_io_thread_count": 4,' \
    '    "enable_cors_support": false,' \
    '    "listeners": {' \
    '        "*": {' \
    '            "document_root": "web",' \
    '            "page_index": [' \
    '                "index.html",' \
    '                "index.htm"' \
    '            ],' \
    '            "page_404": null,' \
    '            "page_429": null,' \
    '            "page_500": null,' \
    '            "autoindex": {' \
    '                "enable": false,' \
    '                "date_format": "dd-MMM-YYYY hh:mm aa"' \
    '            }' \
    '        }' \
    '    }' \
    '}' \
    > $EAGLER_HOME/server/plugins/EaglerWeb/settings.json

# Create world directory symlinks so Paper worlds persist in the volume
RUN ln -sf $EAGLER_HOME/worlds/world $EAGLER_HOME/server/world && \
    ln -sf $EAGLER_HOME/worlds/world_nether $EAGLER_HOME/server/world_nether && \
    ln -sf $EAGLER_HOME/worlds/world_the_end $EAGLER_HOME/server/world_the_end

# Set ownership
RUN chown -R $EAGLER_USER:$EAGLER_USER $EAGLER_HOME

# Create startup script (single JVM process — no supervisord needed)
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    '' \
    'echo "=========================================="' \
    'echo "  Eaglercraft 1.12.2 Server Container"' \
    'echo "=========================================="' \
    'echo ""' \
    '' \
    'CONTAINER_IP=$(hostname -I | awk '"'"'{print $1}'"'"')' \
    'echo "Container IP: $CONTAINER_IP"' \
    'echo "Connect URL:  http://$CONTAINER_IP:8081"' \
    'echo ""' \
    '' \
    'mkdir -p /opt/eaglercraft/worlds/world' \
    'mkdir -p /opt/eaglercraft/worlds/world_nether' \
    'mkdir -p /opt/eaglercraft/worlds/world_the_end' \
    'chown -R eaglercraft:eaglercraft /opt/eaglercraft/worlds' \
    'chown -R eaglercraft:eaglercraft /opt/eaglercraft/logs' \
    'rm -f /opt/eaglercraft/worlds/world/session.lock' \
    'rm -f /opt/eaglercraft/worlds/world_nether/session.lock' \
    'rm -f /opt/eaglercraft/worlds/world_the_end/session.lock' \
    '' \
    'echo "Starting Paper 1.12.2 server..."' \
    'cd /opt/eaglercraft/server' \
    'exec su -s /bin/bash eaglercraft -c "java -Djava.net.preferIPv4Stack=true -Xmx1536M -Xms512M -jar Paper.jar nogui 2>&1 | tee /opt/eaglercraft/logs/server.log"' \
    > $EAGLER_HOME/scripts/start-services.sh

# Create health check script (single port — Paper handles everything)
RUN printf '%s\n' \
    '#!/bin/bash' \
    'if netstat -tln 2>/dev/null | grep -q ":8081"; then' \
    '    exit 0' \
    'else' \
    '    exit 1' \
    'fi' \
    > $EAGLER_HOME/scripts/health-check.sh

# Make scripts executable
RUN chmod +x $EAGLER_HOME/scripts/*.sh

# Volumes for persistent data
VOLUME ["$EAGLER_HOME/worlds", "$EAGLER_HOME/logs"]

# Paper serves web client (HTTP) + game (WebSocket) on single port via EaglerXServer
# Plan Player Analytics dashboard
EXPOSE 8081 8804

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD $EAGLER_HOME/scripts/health-check.sh

WORKDIR $EAGLER_HOME

CMD ["./scripts/start-services.sh"]
