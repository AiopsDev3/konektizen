#!/bin/bash
# Minimal Essential Fixes for Fresh Jitsi Install
cd /mnt/c/Users/EliteBook/Desktop/konektizen/deployment/jitsi

echo "Applying minimal essential fixes..."

# Fix 1: Add WebSocket Upgrade headers to Nginx (if missing)
if ! docker compose exec web grep -q "proxy_set_header Upgrade" /config/nginx/meet.conf; then
    echo "Adding WebSocket headers..."
    docker compose exec web sed -i '/location = \/http-bind {/a \        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection "upgrade";' /config/nginx/meet.conf
    docker compose exec web /etc/init.d/nginx reload
fi

# Fix 2: Ensure config.js uses ws:// not wss:// for localhost:8000
echo "Checking WebSocket protocol..."
docker compose exec web sed -i "s|'wss://|'ws://|g" /config/config.js

echo "Fixes applied. Testing..."
curl -I http://localhost:8000 2>&1 | head -1
