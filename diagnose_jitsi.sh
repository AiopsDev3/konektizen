#!/bin/bash
# Comprehensive Jitsi Diagnostic Script
# This will test every layer of the Jitsi stack to find the exact failure point

echo "=========================================="
echo "JITSI CONNECTIVITY DIAGNOSTIC"
echo "=========================================="
echo ""

cd /mnt/c/Users/EliteBook/Desktop/konektizen/deployment/jitsi

# 1. Container Health
echo "1. Checking Docker Containers..."
docker compose ps | grep -E "web|prosody|jicofo|jvb"
echo ""

# 2. Prosody XMPP Server
echo "2. Testing Prosody XMPP (Internal)..."
docker compose exec prosody curl -s http://localhost:5280/http-bind | head -5
echo ""

# 3. Nginx -> Prosody Proxy
echo "3. Testing Nginx -> Prosody Proxy..."
docker compose exec web curl -s http://prosody:5280/http-bind | head -5
echo ""

# 4. External BOSH Access
echo "4. Testing External BOSH Access..."
curl -s http://localhost:8000/http-bind | head -5
echo ""

# 5. WebSocket Configuration
echo "5. Checking WebSocket Config..."
docker compose exec web grep "websocket" /config/config.js | head -3
echo ""

# 6. Nginx WebSocket Headers
echo "6. Checking Nginx WebSocket Headers..."
docker compose exec web grep -A 2 "xmpp-websocket" /config/nginx/meet.conf | grep -E "Upgrade|Connection"
echo ""

# 7. Host Header Configuration
echo "7. Checking Nginx Host Header..."
docker compose exec web grep "proxy_set_header Host" /config/nginx/meet.conf | head -3
echo ""

# 8. Public URL Configuration
echo "8. Checking PUBLIC_URL..."
docker compose exec web grep "PUBLIC_URL" /config/config.js | head -1
echo ""

echo "=========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================="
