# Multi-stage Dockerfile for EaglercraftX 1.8.8 Server
# Compatible with legacy Docker builder - no BuildKit required
# Architecture: BungeeCord (EaglerXServer + EaglerWeb) -> PandaSpigot 1.8.8

# ============================================================
# Stage 1: Download web client files and validate
# ============================================================
FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    wget \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Download pre-built EaglercraftX 1.8 web client files with fallback sources
# These repos contain compiled client files (classes.js, assets.epk, etc.)
RUN echo "=== Downloading EaglercraftX 1.8 web client ===" && \
    mkdir -p /build/web && \
    ( \
        echo "Trying source 1 (catfoolyou/EaglerX-Client)..." && \
        git clone --depth 1 https://github.com/catfoolyou/EaglerX-Client.git eaglercraft-source && \
        cp eaglercraft-source/classes.js eaglercraft-source/assets.epk /build/web/ && \
        [ -f eaglercraft-source/index.html ] && cp eaglercraft-source/index.html /build/web/ || true && \
        [ -f eaglercraft-source/favicon.png ] && cp eaglercraft-source/favicon.png /build/web/ || true && \
        [ -d eaglercraft-source/lang ] && cp -r eaglercraft-source/lang /build/web/ || true && \
        echo "Clone successful" \
    ) || ( \
        echo "Trying source 2 (KithrakWasTaken/EaglercraftX-Client)..." && \
        rm -rf eaglercraft-source && \
        git clone --depth 1 https://github.com/KithrakWasTaken/EaglercraftX-Client.git eaglercraft-source && \
        cp eaglercraft-source/classes.js eaglercraft-source/assets.epk /build/web/ && \
        [ -f eaglercraft-source/index.html ] && cp eaglercraft-source/index.html /build/web/ || true && \
        [ -f eaglercraft-source/favicon.png ] && cp eaglercraft-source/favicon.png /build/web/ || true && \
        [ -d eaglercraft-source/lang ] && cp -r eaglercraft-source/lang /build/web/ || true && \
        echo "Clone successful" \
    ) || ( \
        echo "Trying source 3 (absoluteG492/EaglercraftX-Client)..." && \
        rm -rf eaglercraft-source && \
        git clone --depth 1 https://github.com/absoluteG492/EaglercraftX-Client.git eaglercraft-source && \
        cp eaglercraft-source/classes.js eaglercraft-source/assets.epk /build/web/ && \
        [ -f eaglercraft-source/index.html ] && cp eaglercraft-source/index.html /build/web/ || true && \
        [ -f eaglercraft-source/favicon.png ] && cp eaglercraft-source/favicon.png /build/web/ || true && \
        [ -d eaglercraft-source/lang ] && cp -r eaglercraft-source/lang /build/web/ || true && \
        echo "Clone successful" \
    ) || ( \
        echo "All git sources failed!" && \
        exit 1 \
    ) && \
    rm -rf eaglercraft-source && \
    echo "=== Web client files ===" && \
    ls -la /build/web/ && \
    echo "=== Validating required files ===" && \
    [ -f "/build/web/classes.js" ] || { echo "ERROR: classes.js missing!"; exit 1; } && \
    [ -f "/build/web/assets.epk" ] || { echo "ERROR: assets.epk missing!"; exit 1; } && \
    echo "Validation passed: classes.js and assets.epk found"

# Create default index.html if not present in the source repo
RUN if [ ! -f "/build/web/index.html" ]; then \
        echo "Creating default index.html..." && \
        printf '%s\n' \
            '<!DOCTYPE html>' \
            '<html>' \
            '<head>' \
            '<meta charset="UTF-8">' \
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">' \
            '<title>EaglercraftX 1.8.8</title>' \
            '<style>' \
            'html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #1a1a2e; }' \
            '</style>' \
            '</head>' \
            '<body>' \
            '<script type="text/javascript">' \
            '"use strict";' \
            'window.eaglercraftXOpts = {' \
            '    container: "game_frame",' \
            '    assetsURI: "assets.epk",' \
            '    localesURI: "lang",' \
            '    worldsDB: "worlds",' \
            '    servers: [' \
            '        { addr: window.location.hostname + ":8081", name: "Local Server", hideAddr: true }' \
            '    ],' \
            '    checkShaderGLErrors: false,' \
            '    enableDownloadOfflineButton: false,' \
            '    downloadOfflineButtonLink: null,' \
            '    html5CursorSupport: false,' \
            '    allowServerRedirects: false,' \
            '    enableSignatureBadge: false,' \
            '    checkRelaysForUpdates: false,' \
            '    allowVoiceClient: false' \
            '};' \
            '</script>' \
            '<div style="width:100%;height:100%;" id="game_frame"></div>' \
            '<script type="text/javascript" src="classes.js"></script>' \
            '</body>' \
            '</html>' \
            > /build/web/index.html; \
    fi && \
    echo "=== Web client preparation complete ==="

# ============================================================
# Stage 2: Runtime container
# ============================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV EAGLER_HOME=/opt/eaglercraft
ENV EAGLER_USER=eaglercraft

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
    openjdk-17-jre-headless \
    supervisor \
    curl \
    procps \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Create eaglercraft user and directory structure
RUN useradd -r -m -d $EAGLER_HOME -s /bin/bash $EAGLER_USER && \
    mkdir -p $EAGLER_HOME/spigot && \
    mkdir -p $EAGLER_HOME/bungee/plugins/EaglerWeb/web && \
    mkdir -p $EAGLER_HOME/bungee/plugins/EaglerXServer && \
    mkdir -p $EAGLER_HOME/worlds && \
    mkdir -p $EAGLER_HOME/logs && \
    mkdir -p $EAGLER_HOME/scripts && \
    mkdir -p /var/log/supervisor && \
    chown -R $EAGLER_USER:$EAGLER_USER $EAGLER_HOME

# Download PandaSpigot 1.8.8
RUN echo "=== Downloading PandaSpigot 1.8.8 ===" && \
    curl -fSL -o $EAGLER_HOME/spigot/PandaSpigot.jar \
    "https://downloads.hpfxd.com/v2/projects/pandaspigot/versions/1.8.8/builds/latest/downloads/paperclip" && \
    echo "PandaSpigot downloaded: $(ls -lh $EAGLER_HOME/spigot/PandaSpigot.jar | awk '{print $5}')"

# Download BungeeCord latest
RUN echo "=== Downloading BungeeCord ===" && \
    curl -fSL -o $EAGLER_HOME/bungee/BungeeCord.jar \
    "https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar" && \
    echo "BungeeCord downloaded: $(ls -lh $EAGLER_HOME/bungee/BungeeCord.jar | awk '{print $5}')"

# Download EaglerXServer v1.0.8 and EaglerWeb plugins
RUN echo "=== Downloading EaglerXServer plugins ===" && \
    curl -fSL -o $EAGLER_HOME/bungee/plugins/EaglerXServer.jar \
    "https://github.com/lax1dude/eaglerxserver/releases/download/v1.0.8/EaglerXServer.jar" && \
    curl -fSL -o $EAGLER_HOME/bungee/plugins/EaglerWeb.jar \
    "https://github.com/lax1dude/eaglerxserver/releases/download/v1.0.8/EaglerWeb.jar" && \
    echo "EaglerXServer downloaded: $(ls -lh $EAGLER_HOME/bungee/plugins/EaglerXServer.jar | awk '{print $5}')" && \
    echo "EaglerWeb downloaded: $(ls -lh $EAGLER_HOME/bungee/plugins/EaglerWeb.jar | awk '{print $5}')"

# Copy web client files from builder stage
COPY --from=builder --chown=$EAGLER_USER:$EAGLER_USER /build/web $EAGLER_HOME/bungee/plugins/EaglerWeb/web/

# Configure PandaSpigot server.properties
RUN printf '%s\n' \
    'server-port=25565' \
    'server-ip=0.0.0.0' \
    'online-mode=false' \
    'spawn-protection=0' \
    'max-players=20' \
    'level-name=world' \
    'motd=EaglercraftX 1.8.8 Server' \
    'gamemode=0' \
    'difficulty=1' \
    'allow-nether=true' \
    'generate-structures=true' \
    'view-distance=10' \
    > $EAGLER_HOME/spigot/server.properties

# Accept EULA
RUN echo "eula=true" > $EAGLER_HOME/spigot/eula.txt

# Configure spigot.yml to accept BungeeCord connections
RUN printf '%s\n' \
    'settings:' \
    '  bungeecord: true' \
    '  timeout-time: 60' \
    '  restart-on-crash: false' \
    '  late-bind: false' \
    '  sample-count: 12' \
    '  player-shuffle: 0' \
    '  filter-creative-items: true' \
    '  log-villager-deaths: true' \
    '  log-named-deaths: true' \
    '  save-user-cache-on-stop-only: false' \
    '  moved-wrongly-threshold: 0.0625' \
    '  moved-too-quickly-multiplier: 10.0' \
    '  attribute:' \
    '    maxHealth:' \
    '      max: 2048.0' \
    '    movementSpeed:' \
    '      max: 2048.0' \
    '    attackDamage:' \
    '      max: 2048.0' \
    > $EAGLER_HOME/spigot/spigot.yml

# Configure BungeeCord config.yml
RUN printf '%s\n' \
    'player_limit: -1' \
    'ip_forward: true' \
    'permissions:' \
    '  default:' \
    '  - bungeecord.command.server' \
    '  - bungeecord.command.list' \
    '  admin:' \
    '  - bungeecord.command.alert' \
    '  - bungeecord.command.end' \
    '  - bungeecord.command.ip' \
    '  - bungeecord.command.reload' \
    'timeout: 30000' \
    'log_commands: false' \
    'online_mode: false' \
    'disabled_commands:' \
    '- disabledcommandhere' \
    'servers:' \
    '  lobby:' \
    "    motd: 'EaglercraftX 1.8.8 Server'" \
    '    address: localhost:25565' \
    '    restricted: false' \
    'listeners:' \
    '- query_port: 8081' \
    "  motd: 'EaglercraftX 1.8.8 Server'" \
    '  tab_list: GLOBAL_PING' \
    '  query_enabled: false' \
    '  proxy_protocol: false' \
    '  forced_hosts: {}' \
    '  ping_passthrough: false' \
    '  priorities:' \
    '  - lobby' \
    '  bind_local_address: true' \
    '  host: 0.0.0.0:8081' \
    '  max_players: 20' \
    '  tab_size: 60' \
    '  force_default_server: true' \
    'groups: {}' \
    'connection_throttle: 4000' \
    'connection_throttle_limit: 3' \
    'stats: ""' \
    'forge_support: false' \
    'inject_commands: false' \
    > $EAGLER_HOME/bungee/config.yml

# Configure EaglerXServer listeners.yml
RUN printf '%s\n' \
    'listener_list:' \
    '  - listener_name: "default"' \
    '    inject_address: "0.0.0.0:8081"' \
    '    max_players: 20' \
    '    server_icon: "server-icon.png"' \
    '    server_motd:' \
    '      - "EaglercraftX 1.8.8 Server"' \
    '    allow_motd: true' \
    '    allow_query: true' \
    '    forward_ip: false' \
    '    enable_tls: false' \
    '    require_tls: false' \
    > $EAGLER_HOME/bungee/plugins/EaglerXServer/listeners.yml

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
    > $EAGLER_HOME/bungee/plugins/EaglerXServer/settings.yml

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
    > $EAGLER_HOME/bungee/plugins/EaglerWeb/settings.json

# Create world directory symlinks so PandaSpigot worlds persist in the volume
RUN ln -sf $EAGLER_HOME/worlds/world $EAGLER_HOME/spigot/world && \
    ln -sf $EAGLER_HOME/worlds/world_nether $EAGLER_HOME/spigot/world_nether && \
    ln -sf $EAGLER_HOME/worlds/world_the_end $EAGLER_HOME/spigot/world_the_end

# Set ownership
RUN chown -R $EAGLER_USER:$EAGLER_USER $EAGLER_HOME

# Create supervisord configuration
RUN printf '%s\n' \
    '[supervisord]' \
    'nodaemon=true' \
    'user=root' \
    'logfile=/var/log/supervisor/supervisord.log' \
    'pidfile=/var/run/supervisord.pid' \
    '' \
    '[program:spigot]' \
    'command=java -Xmx1024M -Xms512M -jar PandaSpigot.jar nogui' \
    'directory=/opt/eaglercraft/spigot' \
    'user=eaglercraft' \
    'autostart=true' \
    'autorestart=true' \
    'startsecs=10' \
    'startretries=3' \
    'stdout_logfile=/opt/eaglercraft/logs/spigot.log' \
    'stderr_logfile=/opt/eaglercraft/logs/spigot.log' \
    'stdout_logfile_maxbytes=50MB' \
    'stdout_logfile_backups=3' \
    '' \
    '[program:bungee]' \
    'command=java -Xmx512M -Xms256M -jar BungeeCord.jar' \
    'directory=/opt/eaglercraft/bungee' \
    'user=eaglercraft' \
    'autostart=false' \
    'autorestart=true' \
    'startsecs=5' \
    'startretries=3' \
    'stdout_logfile=/opt/eaglercraft/logs/bungee.log' \
    'stderr_logfile=/opt/eaglercraft/logs/bungee.log' \
    'stdout_logfile_maxbytes=50MB' \
    'stdout_logfile_backups=3' \
    > /etc/supervisor/conf.d/eaglercraft.conf

# Create startup script
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    '' \
    'echo "=========================================="' \
    'echo "  EaglercraftX 1.8.8 Server Container"' \
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
    '' \
    'supervisord -c /etc/supervisor/supervisord.conf &' \
    'SUPERVISOR_PID=$!' \
    '' \
    'echo "Starting PandaSpigot server..."' \
    'sleep 15' \
    '' \
    'echo "Checking PandaSpigot server..."' \
    'timeout=90' \
    'count=0' \
    'while [ $count -lt $timeout ]; do' \
    '    if netstat -tln 2>/dev/null | grep -q ":25565"; then' \
    '        echo "[OK] PandaSpigot server is ready on port 25565"' \
    '        break' \
    '    fi' \
    '    sleep 1' \
    '    count=$((count + 1))' \
    '    if [ $((count % 15)) -eq 0 ]; then' \
    '        echo "  Still waiting for PandaSpigot... ($count/${timeout}s)"' \
    '    fi' \
    'done' \
    '' \
    'if [ $count -ge $timeout ]; then' \
    '    echo "[FAIL] PandaSpigot server failed to start within ${timeout}s"' \
    '    echo "Check logs: /opt/eaglercraft/logs/spigot.log"' \
    '    exit 1' \
    'fi' \
    '' \
    'echo "Starting BungeeCord proxy with EaglerXServer..."' \
    'supervisorctl start bungee' \
    'sleep 10' \
    '' \
    'echo ""' \
    'echo "=== Service Status ==="' \
    'spigot_status=$(supervisorctl status spigot | grep -q "RUNNING" && echo "[OK]" || echo "[FAIL]")' \
    'bungee_status=$(supervisorctl status bungee | grep -q "RUNNING" && echo "[OK]" || echo "[FAIL]")' \
    '' \
    'echo "  $spigot_status PandaSpigot 1.8.8 (port 25565 internal)"' \
    'echo "  $bungee_status BungeeCord + EaglerXServer (port 8081)"' \
    '' \
    'port_8081=$(netstat -tln 2>/dev/null | grep ":8081" > /dev/null && echo "[OK]" || echo "[FAIL]")' \
    'port_25565=$(netstat -tln 2>/dev/null | grep ":25565" > /dev/null && echo "[OK]" || echo "[FAIL]")' \
    '' \
    'echo ""' \
    'echo "=== Port Status ==="' \
    'echo "  $port_8081 Port 8081 (Web Client + Game WebSocket)"' \
    'echo "  $port_25565 Port 25565 (PandaSpigot internal)"' \
    '' \
    'if [ "$spigot_status" = "[OK]" ] && [ "$bungee_status" = "[OK]" ]; then' \
    '    echo ""' \
    '    echo "=========================================="' \
    '    echo "  All services started successfully!"' \
    '    echo "  Open in browser: http://$CONTAINER_IP:8081"' \
    '    echo "=========================================="' \
    'else' \
    '    echo ""' \
    '    echo "[WARN] Some services failed to start. Check logs:"' \
    '    echo "  docker logs <container-name>"' \
    '    echo "  docker exec <container> cat /opt/eaglercraft/logs/spigot.log"' \
    '    echo "  docker exec <container> cat /opt/eaglercraft/logs/bungee.log"' \
    'fi' \
    '' \
    'echo ""' \
    'echo "Log files:"' \
    'echo "  docker exec <container> tail -f /opt/eaglercraft/logs/spigot.log"' \
    'echo "  docker exec <container> tail -f /opt/eaglercraft/logs/bungee.log"' \
    '' \
    'wait $SUPERVISOR_PID' \
    > $EAGLER_HOME/scripts/start-services.sh

# Create health check script
RUN printf '%s\n' \
    '#!/bin/bash' \
    'if netstat -tln 2>/dev/null | grep -q ":8081" && \' \
    '   netstat -tln 2>/dev/null | grep -q ":25565"; then' \
    '    exit 0' \
    'else' \
    '    exit 1' \
    'fi' \
    > $EAGLER_HOME/scripts/health-check.sh

# Make scripts executable
RUN chmod +x $EAGLER_HOME/scripts/*.sh

# Volumes for persistent data
VOLUME ["$EAGLER_HOME/worlds", "$EAGLER_HOME/logs"]

# Single port: BungeeCord serves both web client (HTTP) and game (WebSocket)
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD $EAGLER_HOME/scripts/health-check.sh

WORKDIR $EAGLER_HOME

CMD ["./scripts/start-services.sh"]
