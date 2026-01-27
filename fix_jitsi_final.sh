#!/bin/bash
cd /mnt/c/Users/EliteBook/Desktop/konektizen/deployment/jitsi

echo "Applying comprehensive Jitsi fixes..."

# 1. Fix config.js - Force WS (not WSS) and localhost
docker compose exec web sed -i "s|wss://|ws://|g" /config/config.js
docker compose exec web sed -i "s|192.168.1.5|localhost|g" /config/config.js

# 2. Fix Nginx - Add WebSocket headers
docker compose exec web sed -i '/proxy_set_header Host meet.jitsi;/a \        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection "upgrade";' /config/nginx/meet.conf

# 3. Reload Nginx
docker compose exec web /etc/init.d/nginx reload

echo "Fixes applied. Jitsi should now work with localhost + adb reverse."
