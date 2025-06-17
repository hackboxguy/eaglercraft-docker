# Multi-stage Dockerfile for Eaglercraft Server
# Compatible with legacy Docker builder - no BuildKit required
# Based on lessons learned from troubleshooting session

# Stage 1: Source acquisition and validation
FROM ubuntu:20.04 AS builder

# Install dependencies for building
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    wget \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /build

# Download Eaglercraft server files with fallback sources
RUN echo "Attempting to download Eaglercraft server files..." && \
    # Try multiple repositories in order of preference
    ( \
        echo "Trying lDEVinux repository..." && \
        git clone https://github.com/lDEVinux/eaglercraft.git eaglercraft-source && \
        cd eaglercraft-source && \
        [ -d "stable-download" ] \
    ) || ( \
        echo "Trying etcherfx repository..." && \
        rm -rf eaglercraft-source && \
        git clone https://github.com/etcherfx/Eaglercraft.git eaglercraft-source && \
        cd eaglercraft-source && \
        [ -d "stable-download" ] \
    ) || ( \
        echo "Trying LEVIXDDLMAO repository..." && \
        rm -rf eaglercraft-source && \
        git clone https://github.com/LEVIXDDLMAO/Eaglercraft.git eaglercraft-source && \
        cd eaglercraft-source && \
        [ -d "stable-download" ] \
    ) || ( \
        echo "All Git sources failed!" && \
        exit 1 \
    )

# Extract and validate server files
RUN cd eaglercraft-source/stable-download && \
    echo "Validating server files..." && \
    # Check for required files
    [ -f "java/bukkit_command/craftbukkit-1.5.2-R1.0.jar" ] || { echo "ERROR: Bukkit JAR not found!"; exit 1; } && \
    ( [ -f "java/bungee_command/bungee-dist.jar" ] || [ -f "java/bungee_command/BungeeCord.jar" ] ) || { echo "ERROR: BungeeCord JAR not found!"; exit 1; } && \
    [ -d "web" ] || { echo "ERROR: Web directory not found!"; exit 1; } && \
    echo "All required files found!" && \
    # Copy to clean directory structure
    mkdir -p /build/server && \
    cp -r * /build/server/

# Normalize BungeeCord JAR name (handle both bungee-dist.jar and BungeeCord.jar)
RUN cd /build/server/java/bungee_command && \
    if [ -f "bungee-dist.jar" ] && [ ! -f "BungeeCord.jar" ]; then \
        echo "Renaming bungee-dist.jar to BungeeCord.jar for consistency"; \
        mv bungee-dist.jar BungeeCord.jar; \
    fi

# Stage 2: Runtime container
FROM ubuntu:20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV EAGLER_HOME=/opt/eaglercraft
ENV EAGLER_USER=eaglercraft

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
    openjdk-8-jdk \
    python3 \
    supervisor \
    curl \
    procps \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Create eaglercraft user and directories
RUN useradd -r -m -d $EAGLER_HOME -s /bin/bash $EAGLER_USER && \
    mkdir -p $EAGLER_HOME/bukkit && \
    mkdir -p $EAGLER_HOME/bungee && \
    mkdir -p $EAGLER_HOME/web && \
    mkdir -p $EAGLER_HOME/logs && \
    mkdir -p $EAGLER_HOME/worlds && \
    mkdir -p $EAGLER_HOME/scripts && \
    mkdir -p /var/log/supervisor && \
    chown -R $EAGLER_USER:$EAGLER_USER $EAGLER_HOME

# Copy server files from builder stage
COPY --from=builder --chown=$EAGLER_USER:$EAGLER_USER /build/server/java/bukkit_command $EAGLER_HOME/bukkit/
COPY --from=builder --chown=$EAGLER_USER:$EAGLER_USER /build/server/java/bungee_command $EAGLER_HOME/bungee/
COPY --from=builder --chown=$EAGLER_USER:$EAGLER_USER /build/server/web $EAGLER_HOME/web/

# Fix Bukkit server configuration for proper networking and port separation
RUN sed -i 's/server-port=25569/server-port=25566/' $EAGLER_HOME/bukkit/server.properties && \
    sed -i 's/server-ip=127.0.0.1/server-ip=0.0.0.0/' $EAGLER_HOME/bukkit/server.properties && \
    echo "eula=true" > $EAGLER_HOME/bukkit/eula.txt && \
    chown $EAGLER_USER:$EAGLER_USER $EAGLER_HOME/bukkit/eula.txt

# Fix BungeeCord configuration to connect to Bukkit on correct port
RUN sed -i 's/localhost:25569/localhost:25566/' $EAGLER_HOME/bungee/config.yml && \
    chown $EAGLER_USER:$EAGLER_USER $EAGLER_HOME/bungee/config.yml

# Create supervisord configuration file
RUN echo "[supervisord]" > /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "nodaemon=true" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "user=root" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "logfile=/var/log/supervisor/supervisord.log" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "pidfile=/var/run/supervisord.pid" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "[program:bukkit]" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "command=java -Xmx1024M -jar craftbukkit-1.5.2-R1.0.jar nogui" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "directory=/opt/eaglercraft/bukkit" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "user=eaglercraft" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "autostart=true" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "autorestart=true" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "startsecs=10" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "startretries=3" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile=/opt/eaglercraft/logs/bukkit.log" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stderr_logfile=/opt/eaglercraft/logs/bukkit.log" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile_maxbytes=50MB" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile_backups=3" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "[program:bungee]" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "command=java -Xmx512M -jar BungeeCord.jar" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "directory=/opt/eaglercraft/bungee" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "user=eaglercraft" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "autostart=false" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "autorestart=true" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "startsecs=5" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "startretries=3" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile=/opt/eaglercraft/logs/bungee.log" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stderr_logfile=/opt/eaglercraft/logs/bungee.log" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile_maxbytes=50MB" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile_backups=3" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "[program:webserver]" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "command=python3 -m http.server 8080" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "directory=/opt/eaglercraft/web" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "user=eaglercraft" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "autostart=false" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "autorestart=true" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "startsecs=5" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "startretries=3" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile=/opt/eaglercraft/logs/web.log" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stderr_logfile=/opt/eaglercraft/logs/web.log" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile_maxbytes=10MB" >> /etc/supervisor/conf.d/eaglercraft.conf && \
    echo "stdout_logfile_backups=2" >> /etc/supervisor/conf.d/eaglercraft.conf

# Create startup script
RUN echo '#!/bin/bash' > $EAGLER_HOME/scripts/start-services.sh && \
    echo 'set -e' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "🎮 Starting Eaglercraft Server Container"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "========================================"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Get container IP' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'CONTAINER_IP=$(hostname -I | awk '"'"'{print $1}'"'"')' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "📡 Container IP: $CONTAINER_IP"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "🌐 Connect URL: http://$CONTAINER_IP:8080"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "🎯 Game Server: $CONTAINER_IP:25565"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo ""' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Start supervisord in background' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'supervisord -c /etc/supervisor/supervisord.conf &' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'SUPERVISOR_PID=$!' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Wait for bukkit to be ready' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "⏳ Starting Bukkit server..."' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'sleep 15' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Check if bukkit is running and port is open' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "🔍 Checking Bukkit server..."' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'timeout=60' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'count=0' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'while [ $count -lt $timeout ]; do' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    if netstat -tln 2>/dev/null | grep -q ":25566"; then' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '        echo "✅ Bukkit server is ready"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '        break' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    fi' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    sleep 1' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    count=$((count + 1))' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    if [ $((count % 10)) -eq 0 ]; then' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '        echo "   Still waiting for Bukkit... ($count/${timeout}s)"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    fi' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'done' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'if [ $count -ge $timeout ]; then' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo "❌ Bukkit server failed to start"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    exit 1' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'fi' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Start BungeeCord' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "🚀 Starting BungeeCord proxy..."' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'supervisorctl start bungee' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'sleep 8' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Start web server' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "🌐 Starting web server..."' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'supervisorctl start webserver' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'sleep 3' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Final status check' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo ""' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "🔍 Final status check..."' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'bukkit_status=$(supervisorctl status bukkit | grep -q "RUNNING" && echo "✅" || echo "❌")' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'bungee_status=$(supervisorctl status bungee | grep -q "RUNNING" && echo "✅" || echo "❌")' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'web_status=$(supervisorctl status webserver | grep -q "RUNNING" && echo "✅" || echo "❌")' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   $bukkit_status Bukkit server"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   $bungee_status BungeeCord proxy"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   $web_status Web server"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'port_25565=$(netstat -tln 2>/dev/null | grep ":25565" > /dev/null && echo "✅" || echo "❌")' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'port_8080=$(netstat -tln 2>/dev/null | grep ":8080" > /dev/null && echo "✅" || echo "❌")' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'port_25566=$(netstat -tln 2>/dev/null | grep ":25566" > /dev/null && echo "✅" || echo "❌")' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   $port_25565 Game port (25565 - BungeeCord)"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   $port_8080 Web port (8080)"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   $port_25566 Bukkit port (25566)"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'if [[ "$bukkit_status" == "✅" && "$bungee_status" == "✅" && "$web_status" == "✅" ]]; then' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo ""' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo "🎉 All services started successfully!"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo "📋 Players can connect to: http://$CONTAINER_IP:8080"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo "🎮 Then join server: $CONTAINER_IP:25565"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'else' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo ""' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo "⚠️  Some services failed to start. Check logs:"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '    echo "   docker logs <container-name>"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'fi' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo ""' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "📝 Available logs:"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   docker exec <container> tail -f /opt/eaglercraft/logs/bukkit.log"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   docker exec <container> tail -f /opt/eaglercraft/logs/bungee.log"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'echo "   docker exec <container> tail -f /opt/eaglercraft/logs/web.log"' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo '# Keep supervisor running' >> $EAGLER_HOME/scripts/start-services.sh && \
    echo 'wait $SUPERVISOR_PID' >> $EAGLER_HOME/scripts/start-services.sh

# Health check script
RUN echo '#!/bin/bash' > $EAGLER_HOME/scripts/health-check.sh && \
    echo '# Health check for container readiness' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '# Check if all required ports are listening' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo 'if netstat -tln 2>/dev/null | grep -q ":25565" && \' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '   netstat -tln 2>/dev/null | grep -q ":8080" && \' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '   netstat -tln 2>/dev/null | grep -q ":25566"; then' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '    echo "✅ All services healthy"' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '    exit 0' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo 'else' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '    echo "❌ Services not ready"' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo '    exit 1' >> $EAGLER_HOME/scripts/health-check.sh && \
    echo 'fi' >> $EAGLER_HOME/scripts/health-check.sh

# Make scripts executable
RUN chmod +x $EAGLER_HOME/scripts/*.sh

# Set up volumes for persistent data
VOLUME ["$EAGLER_HOME/worlds", "$EAGLER_HOME/logs"]

# Expose ports
EXPOSE 8080 25565

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD $EAGLER_HOME/scripts/health-check.sh

# Set working directory
WORKDIR $EAGLER_HOME

# Run the startup script
CMD ["./scripts/start-services.sh"]
